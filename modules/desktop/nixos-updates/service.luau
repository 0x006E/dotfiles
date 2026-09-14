-- ntsv/nixos-updates:fetcher (headless [[service]])
--
-- Owns all polling and publishes a plain-data snapshot on the
-- noctalia.state channel ("snapshot") for the widget and panel.
-- Commands arrive the same way ("command" = {name, nonce}):
--   check  -> forced poll (widget click path, keybind, panel button, CLI)
--   pull   -> git pull --ff-only when the tree is clean (panel button, CLI)
--
-- GitHub REST, no auth. Guards: shell offline_mode, no route/DNS,
-- 403 rate-limit (1h backoff), per-call HTTP errors, JSON failures,
-- stuck-check reset. Notifications fire on transitions only
-- (persisted in pluginDataDir/state.json).

local H = require("./lib/helpers.luau")

local API = "https://api.github.com"
local HEADERS = { "Accept: application/vnd.github+json", "User-Agent: noctalia-nixos-updates" }
local RATE_BACKOFF = 3600 -- seconds to wait after hitting the GitHub quota
local BUSY_TIMEOUT = 180 -- seconds after which a stuck check is reset
-- Lock-file inputs always tracked first, in this order.
local PINNED = { "nixpkgs", "nixpkgs-small", "nixpkgs-stable" }

local S = {
  busy = false,
  busySince = 0,
  forced = false,
  lastRun = 0,
  backoffUntil = 0,
  net = "starting", -- ok | offline | ratelimit | error | starting
  netDetail = "",
  inputs = {}, -- {name, owner, repo, branch, localRev, remoteSha, remoteDate, behind, err}
  skippedInputs = 0,
  head = nil,
  dirty = false,
  lockErr = nil,
  dotfiles = { localHead = nil, remoteHead = nil, remoteMsg = nil, remoteDate = nil, behind = false },
  ci = nil, -- {status, conclusion, sha, name}
  prs = {}, -- {number, title, ref, sha, ci}
  upstreamCi = nil,
  lastOk = nil,
  pull = { state = "idle", msg = "" }, -- idle | running | ok | error
}

-- Persisted "already notified" state.
local N = { inputs = {}, readyHead = nil, ciFail = nil, prs = {}, prCi = {} }

local nonceCounter = 0

-- ------------------------------------------------------------------ persist

local function statePath()
  local dir = noctalia.pluginDataDir()
  if not dir then
    return nil
  end
  return dir .. "/state.json"
end

local function restore()
  local p = statePath()
  if not p then
    return
  end
  local raw = noctalia.readFile(p)
  if not raw then
    return
  end
  local ok, data = pcall(noctalia.json.decode, raw)
  if ok and type(data) == "table" then
    N = {
      inputs = type(data.inputs) == "table" and data.inputs or {},
      readyHead = data.readyHead,
      ciFail = data.ciFail,
      prs = type(data.prs) == "table" and data.prs or {},
      prCi = type(data.prCi) == "table" and data.prCi or {},
    }
  end
end

local function persist()
  local p = statePath()
  if not p then
    return
  end
  local ok, raw = pcall(noctalia.json.encode, N)
  if ok and raw then
    noctalia.writeFile(p, raw)
  end
end

restore()

local function publish()
  noctalia.state.set("snapshot", S)
end

-- ------------------------------------------------------------------- fetch

-- Forward declarations: the fetch chain aborts into finalize().
local finalize
local runCheck

-- True when the whole check must stop (offline / rate-limited).
-- Ordinary HTTP errors are soft: the caller records them and continues.
local function fatal(ok, status, body)
  if ok then
    S.net = "ok"
    S.netDetail = ""
    return false
  end
  status = tonumber(status) or 0
  local b = string.lower(type(body) == "string" and body or "")
  if status == 0 then
    S.net = "offline"
    S.netDetail = "unreachable"
    return true
  end
  if status == 403 and string.find(b, "rate limit", 1, true) then
    S.net = "ratelimit"
    S.netDetail = "github 60/h quota"
    S.backoffUntil = os.time() + RATE_BACKOFF
    return true
  end
  return false
end

local function get(url, cb)
  H.get(url, HEADERS, cb)
end

-- Fast local git state (HEAD + dirty). Callback receives nothing; S updated.
local function refreshGit(done)
  local cmd = H.envPrefix()
    .. "; D="
    .. H.shDir()
    .. '; H=$(git -C $D rev-parse HEAD 2>/dev/null || echo "?")'
    .. '; if [ -n "$(git -C $D status --porcelain 2>/dev/null | head -n 1)" ]; then F=dirty; else F=clean; fi'
    .. '; printf "%s %s" "$H" "$F"'
  noctalia.runAsync(cmd, function(res)
    if type(res) == "table" and type(res.stdout) == "string" then
      local h, f = string.match(res.stdout, "(%S+)%s+(%S+)")
      if h and h ~= "?" then
        S.head = h
      else
        S.head = nil
      end
      S.dirty = (f == "dirty")
    else
      S.head = nil
    end
    S.dotfiles.localHead = S.head
    done()
  end)
end

-- Local state: flake.lock github inputs (sync read) + git (async).
local function refreshLocal(done)
  S.inputs = {}
  S.skippedInputs = 0
  S.lockErr = nil
  local raw = noctalia.readFile(H.flakePath() .. "/flake.lock")
  if not raw then
    S.lockErr = "cannot read flake.lock"
  else
    local lock = H.decodeObj(raw)
    if type(lock) ~= "table" or type(lock.nodes) ~= "table" then
      S.lockErr = "cannot parse flake.lock"
    else
      -- Every github-type input with a branch/tag ref. Pinned nixpkgs
      -- inputs first (PINNED order), then the rest alphabetically,
      -- capped by max_inputs.
      local display = {}
      local root = lock.nodes.root
      local idx = root and root.inputs
      if type(idx) == "table" then
        for disp, nodeName in pairs(idx) do
          if type(nodeName) == "string" and not display[nodeName] then
            display[nodeName] = disp
          end
        end
      end
      local rest = {}
      for nodeName, disp in pairs(display) do
        local node = lock.nodes[nodeName]
        local locked = node and node.locked
        if
          type(locked) == "table"
          and locked.type == "github"
          and type(locked.rev) == "string"
          and type(locked.owner) == "string"
          and type(locked.repo) == "string"
        then
          local orig = node.original
          local ref = type(orig) == "table" and orig.ref or locked.ref
          if type(ref) == "string" and ref ~= "" then
            local pinPos = nil
            for i, pin in ipairs(PINNED) do
              if pin == disp then
                pinPos = i
              end
            end
            rest[#rest + 1] = {
              name = disp,
              owner = locked.owner,
              repo = locked.repo,
              branch = ref,
              localRev = locked.rev,
              behind = false,
              _pin = pinPos, -- nil when not pinned
            }
          end
        end
      end
      table.sort(rest, function(a, b)
        if (a._pin ~= nil) ~= (b._pin ~= nil) then
          return a._pin ~= nil
        end
        if a._pin and b._pin then
          return a._pin < b._pin
        end
        return a.name < b.name
      end)
      local cap = H.maxInputs()
      for i, inp in ipairs(rest) do
        inp._pin = nil
        if i <= cap then
          S.inputs[#S.inputs + 1] = inp
        end
      end
      S.skippedInputs = #rest - #S.inputs
    end
  end
  refreshGit(done)
end

local function fetchInputs(idx, done)
  local inp = S.inputs[idx]
  if not inp then
    done()
    return
  end
  get(API .. "/repos/" .. inp.owner .. "/" .. inp.repo .. "/commits/" .. inp.branch, function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local c = H.decodeObj(body)
      if c and type(c.sha) == "string" then
        inp.remoteSha = c.sha
        inp.remoteDate = c.commit and c.commit.committer and c.commit.committer.date
        inp.behind = (c.sha ~= inp.localRev)
      else
        inp.err = "bad response"
      end
    else
      inp.err = "http " .. tostring(status)
    end
    fetchInputs(idx + 1, done)
  end)
end

local function fetchDotfilesHead(done)
  get(API .. "/repos/" .. H.dotfilesRepo() .. "/commits/main", function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local c = H.decodeObj(body)
      if c and type(c.sha) == "string" then
        S.dotfiles.remoteHead = c.sha
        S.dotfiles.remoteDate = c.commit and c.commit.committer and c.commit.committer.date
        local msg = c.commit and c.commit.message
        if type(msg) == "string" then
          S.dotfiles.remoteMsg = string.match(msg, "^[^\\n]*") or msg
        end
        S.dotfiles.behind = S.head ~= nil and c.sha ~= S.head
      end
    end
    done()
  end)
end

local function fetchCi(done)
  get(API .. "/repos/" .. H.dotfilesRepo() .. "/actions/runs?branch=main&per_page=5", function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local d = H.decodeObj(body)
      local runs = d and d.workflow_runs
      if type(runs) == "table" then
        local pick = nil
        for _, r in ipairs(runs) do
          if r.head_sha == S.dotfiles.remoteHead then
            pick = r
            break
          end
        end
        if not pick then
          for _, r in ipairs(runs) do
            if r.status == "completed" then
              pick = r
              break
            end
          end
        end
        if pick then
          S.ci = { status = pick.status, conclusion = pick.conclusion, sha = pick.head_sha, name = pick.name }
        end
      end
    end
    done()
  end)
end

local function summarizeChecks(runs)
  local bad = 0
  local pending = 0
  for _, r in ipairs(runs) do
    if r.status ~= "completed" then
      pending = pending + 1
    elseif r.conclusion ~= "success" and r.conclusion ~= "skipped" and r.conclusion ~= "neutral" then
      bad = bad + 1
    end
  end
  if bad > 0 then
    return "failing"
  elseif pending > 0 then
    return "pending"
  else
    return "passing"
  end
end

local fetchPrCi -- forward: fetchPrs chains into it
local function fetchPrs(done)
  get(API .. "/repos/" .. H.dotfilesRepo() .. "/pulls?state=open&per_page=20", function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local d = H.decodeObj(body)
      S.prs = {}
      if type(d) == "table" then
        for _, p in ipairs(d) do
          if type(p.number) == "number" then
            S.prs[#S.prs + 1] = {
              number = p.number,
              title = tostring(p.title or ""),
              ref = (p.head and p.head.ref) or "",
              sha = (p.head and p.head.sha) or "",
              ci = "unknown",
            }
          end
        end
      end
    end
    fetchPrCi(1, done)
  end)
end

fetchPrCi = function(idx, done)
  local pr = S.prs[idx]
  if not pr then
    done()
    return
  end
  if pr.sha == "" then
    fetchPrCi(idx + 1, done)
    return
  end
  get(API .. "/repos/" .. H.dotfilesRepo() .. "/commits/" .. pr.sha .. "/check-runs?per_page=30", function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local d = H.decodeObj(body)
      local runs = d and d.check_runs
      if type(runs) == "table" and #runs > 0 then
        pr.ci = summarizeChecks(runs)
      else
        pr.ci = "no checks"
      end
    end
    fetchPrCi(idx + 1, done)
  end)
end

-- Upstream CI for the first behind input only (saves quota).
local function fetchUpstreamCi(done)
  local target = nil
  for _, i in ipairs(S.inputs) do
    if i.behind and i.remoteSha then
      target = i
      break
    end
  end
  if not target then
    S.upstreamCi = nil
    done()
    return
  end
  get(
    API .. "/repos/" .. target.owner .. "/" .. target.repo .. "/commits/" .. target.remoteSha .. "/check-runs?per_page=100",
    function(ok, status, body)
      if fatal(ok, status, body) then
        finalize()
        return
      end
      if tonumber(status) == 200 then
        local d = H.decodeObj(body)
        local runs = d and d.check_runs
        if type(runs) == "table" and #runs > 0 then
          local agg = summarizeChecks(runs)
          if agg == "failing" then
            S.upstreamCi = "failing"
          elseif agg == "pending" then
            S.upstreamCi = "pending"
          else
            S.upstreamCi = "passing"
          end
        else
          S.upstreamCi = "no checks"
        end
      end
      done()
    end
  )
end

-- ---------------------------------------------------------------- notify

finalize = function()
  local now = os.time()
  S.busy = false
  S.lastRun = now
  if S.net == "ok" then
    S.lastOk = now
    -- 1. flake inputs behind upstream
    for _, i in ipairs(S.inputs) do
      if i.localRev and i.remoteSha then
        local key = i.owner .. "/" .. i.repo .. "@" .. i.branch
        if i.behind then
          if N.inputs[key] ~= i.remoteSha then
            N.inputs[key] = i.remoteSha
            noctalia.notify(
              "NixOS updates available",
              i.name .. " (" .. i.branch .. "): @" .. H.short(i.localRev) .. " → @" .. H.short(i.remoteSha)
            )
          end
        elseif N.inputs[key] then
          N.inputs[key] = nil
          noctalia.notify("NixOS up to date", i.name .. " (@" .. H.short(i.localRev) .. ")")
        end
      end
    end
    -- 2+3. dotfiles: new remote HEAD + local behind + CI green = safe to pull.
    local d = S.dotfiles
    if d.remoteHead and d.behind then
      local ciOk = S.ci and S.ci.sha == d.remoteHead and S.ci.conclusion == "success"
      if ciOk and N.readyHead ~= d.remoteHead then
        N.readyHead = d.remoteHead
        noctalia.notify("Dotfiles update ready", "main @" .. H.short(d.remoteHead) .. " — CI green, safe to pull")
      end
    elseif d.remoteHead and not d.behind then
      N.readyHead = nil
    end
    -- Main CI failure still worth one ping.
    if S.ci and S.ci.sha then
      if S.ci.conclusion == "failure" and N.ciFail ~= S.ci.sha then
        N.ciFail = S.ci.sha
        noctalia.notifyError("dotfiles CI failing", "main @" .. H.short(S.ci.sha))
      elseif S.ci.conclusion == "success" and N.ciFail then
        N.ciFail = nil
        noctalia.notify("dotfiles CI green", "main @" .. H.short(S.ci.sha))
      end
    end
    -- 2. PRs: new opens ping; CI transitions ping; running stays quiet.
    local seen = {}
    for _, p in ipairs(S.prs) do
      local key = tostring(p.number)
      seen[key] = true
      if not N.prs[key] then
        N.prs[key] = true
        N.prCi[key] = p.ci
        if p.ci == "failing" then
          noctalia.notifyError("PR #" .. key .. " CI failed", p.title .. " — check it")
        else
          noctalia.notify("PR open: #" .. key, p.title)
        end
      else
        local prev = N.prCi[key]
        if p.ci == "failing" and prev ~= "failing" then
          N.prCi[key] = "failing"
          noctalia.notifyError("PR #" .. key .. " CI failed", p.title .. " — check it")
        elseif p.ci == "passing" and (prev == "failing" or prev == "pending") then
          N.prCi[key] = "passing"
          noctalia.notify("PR #" .. key .. " CI green", p.title)
        elseif p.ci ~= prev then
          N.prCi[key] = p.ci
        end
      end
    end
    for num, _ in pairs(N.prs) do
      if not seen[num] then
        N.prs[num] = nil
        N.prCi[num] = nil
      end
    end
    persist()
  end
  publish()
end

runCheck = function(forced)
  local now = os.time()
  if S.busy then
    if now - S.busySince > BUSY_TIMEOUT then
      S.busy = false
      noctalia.log("nixos-updates: stuck check reset")
    else
      return
    end
  end
  if not forced then
    if now < S.backoffUntil then
      return
    end
    if S.lastRun > 0 and (now - S.lastRun) * 1000 < H.pollMs() then
      return
    end
  end
  if noctalia.getSetting("shell.offline_mode") == true then
    S.net = "offline"
    S.netDetail = "shell offline_mode"
    publish()
    return
  end
  S.busy = true
  S.busySince = now
  S.pull = { state = "idle", msg = "" }
  publish()
  refreshLocal(function()
    fetchInputs(1, function()
      fetchDotfilesHead(function()
        fetchCi(function()
          fetchPrs(function()
            fetchUpstreamCi(function()
              finalize()
            end)
          end)
        end)
      end)
    end)
  end)
end

-- -------------------------------------------------------------------- pull

local function runPull()
  if S.pull.state == "running" then
    return
  end
  S.pull = { state = "running", msg = "pulling…" }
  publish()
  -- Re-verify cleanliness in the same breath, then fast-forward only.
  local cmd = H.envPrefix()
    .. "; D="
    .. H.shDir()
    .. '; if [ -n "$(git -C $D status --porcelain 2>/dev/null | head -n 1)" ]; then echo "DIRTY"; exit 0; fi'
    .. '; git -C $D pull --ff-only 2>&1; printf "\\nEXIT:%s" "$?"'
  noctalia.runAsync(cmd, function(res)
    local out = type(res) == "table" and type(res.stdout) == "string" and res.stdout or ""
    if string.match(out, "^DIRTY") then
      S.pull = { state = "error", msg = "tree is dirty — pull refused" }
      noctalia.notifyError("Pull refused", "commit or stash your changes first")
    else
      local code = string.match(out, "EXIT:(%d+)%s*$") or (res.timedOut and "timeout" or "?")
      if code == "0" then
        local first = string.match(out, "^[^\\n]*") or "done"
        S.pull = { state = "ok", msg = first }
        noctalia.notify("Pulled", first)
        publish()
        runCheck(true) -- lock revs changed; re-poll immediately
        return
      else
        local tail = string.sub(out, -160)
        S.pull = { state = "error", msg = "exit " .. code }
        noctalia.notifyError("Pull failed (exit " .. code .. ")", tail)
      end
    end
    publish()
  end)
end

-- ---------------------------------------------------------------- commands

local function onCommand(cmd)
  if type(cmd) ~= "table" or type(cmd.name) ~= "string" then
    return
  end
  if cmd.name == "check" then
    runCheck(true)
  elseif cmd.name == "pull" then
    runPull()
  end
end

noctalia.state.watch("command", onCommand)

-- ---------------------------------------------------------------- lifecycle

function update()
  noctalia.setUpdateInterval(H.pollMs())
  runCheck(false)
end

function onIpc(event, _payload)
  if event == "check" then
    runCheck(true)
  elseif event == "pull" then
    runPull()
  end
end

publish()
runCheck(false)
