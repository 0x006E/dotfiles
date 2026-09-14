-- ntsv/nixos-updates:updates
--
-- Bar widget + notifications for NixOS package updates:
--   * nixpkgs flake inputs (nixpkgs / -small / -stable) vs upstream branch HEAD
--   * upstream CI (commit check-runs) for the newest behind HEAD
--   * dotfiles repo CI (latest main runs) and open PRs
--   * local tree state (HEAD + dirty) from ~/nix
--
-- GitHub REST API, no auth (public repos, 60 req/h quota).
-- Polls every `poll_minutes` (default 30); left-click or
-- `noctalia msg plugin ntsv/nixos-updates:updates all check` forces a check.
-- Guards: shell offline_mode, no route/DNS (offline), 403 rate-limit
-- (1h backoff), per-call HTTP errors, JSON parse failures, stuck-check reset.
-- Notifications fire on transitions only (persisted in pluginDataDir).

local API = "https://api.github.com"
local HEADERS = { "Accept: application/vnd.github+json", "User-Agent: noctalia-nixos-updates" }
local TRACKED = { "nixpkgs", "nixpkgs-small", "nixpkgs-stable" }
local RATE_BACKOFF = 3600 -- seconds to wait after hitting the GitHub quota
local BUSY_TIMEOUT = 180 -- seconds after which a stuck check is reset

-- ------------------------------------------------------------------ config

local function cfg(key, fallback)
  local v = noctalia.getConfig(key)
  if v == nil then
    return fallback
  end
  return v
end

local function pollMs()
  local m = tonumber(cfg("poll_minutes", 30)) or 30
  if m < 5 then
    m = 5
  end
  if m > 720 then
    m = 720
  end
  return math.floor(m * 60 * 1000)
end

local function flakePath()
  local p = cfg("flake_path", "~/nix")
  if type(p) ~= "string" or p == "" then
    p = "~/nix"
  end
  return p
end

local function dotfilesRepo()
  local r = cfg("dotfiles_repo", "0x006E/dotfiles")
  if type(r) ~= "string" or r == "" then
    r = "0x006E/dotfiles"
  end
  return r
end

-- ------------------------------------------------------------------- state

local S = {
  busy = false,
  busySince = 0,
  forced = false,
  lastRun = 0,
  backoffUntil = 0,
  net = "starting", -- ok | offline | ratelimit | error | starting
  netDetail = "",
  inputs = {}, -- {name, branch, localRev, remoteSha, remoteDate, behind, err}
  head = nil,
  dirty = false,
  lockErr = nil,
  ci = nil, -- {status, conclusion, sha, name}
  prs = {}, -- {number, title, ref}
  upstreamCi = nil,
  lastOk = nil,
}

-- Persisted "already notified" state so we only ping on transitions.
local N = { inputs = {}, ciFail = nil, prs = {} }

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
      ciFail = data.ciFail,
      prs = type(data.prs) == "table" and data.prs or {},
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

-- ----------------------------------------------------------------- helpers

local function short(sha)
  if type(sha) ~= "string" then
    return "?"
  end
  return string.sub(sha, 1, 7)
end

local function dayOf(iso)
  if type(iso) ~= "string" then
    return "?"
  end
  return string.sub(iso, 1, 10)
end

-- noctalia.http is documented both as cb(response-table) and
-- cb(ok, status, body); accept either shape.
local function get(url, cb)
  noctalia.http({ url = url, method = "GET", headers = HEADERS }, function(a, b, c)
    if type(a) == "table" then
      cb(a.ok, a.status, a.body)
    else
      cb(a, b, c)
    end
  end)
end

local function decodeObj(body)
  if type(body) ~= "string" or body == "" then
    return nil
  end
  local ok, v = pcall(noctalia.json.decode, body)
  if ok then
    return v
  end
  return nil
end

local function sq(s)
  return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

-- Shell-safe flake dir: a leading ~/ cannot expand inside quotes,
-- so route it through "$HOME".
local function shDir()
  local p = flakePath()
  if string.sub(p, 1, 2) == "~/" then
    return '"$HOME"' .. sq(string.sub(p, 2))
  end
  return sq(p)
end

local function behindCount()
  local n = 0
  for _, i in ipairs(S.inputs) do
    if i.behind then
      n = n + 1
    end
  end
  return n
end

-- ------------------------------------------------------------------ render

local function render()
  local behind = behindCount()
  local glyph = "check"
  local text = ""

  if S.net == "offline" then
    glyph = "wifi-off"
  elseif S.net == "ratelimit" then
    glyph = "clock"
  elseif S.busy then
    glyph = "loader-2"
  elseif S.lockErr then
    glyph = "alert-triangle"
    text = "!"
  elseif behind > 0 and S.ci and S.ci.conclusion == "failure" then
    glyph = "alert-triangle"
    text = "+" .. tostring(behind)
  elseif behind > 0 then
    glyph = "package"
    text = "+" .. tostring(behind)
    if S.dirty then
      text = text .. "•"
    end
  elseif S.dirty then
    glyph = "pencil"
    text = "•"
  elseif S.ci and S.ci.conclusion == "failure" then
    glyph = "alert-triangle"
    text = "!"
  elseif #S.prs > 0 then
    glyph = "git-pull-request"
    text = tostring(#S.prs)
  end

  barWidget.setGlyph(glyph)
  barWidget.setText(text)

  local rows = {}
  local function row(k, v)
    rows[#rows + 1] = { key = tostring(k), value = tostring(v) }
  end

  if #S.inputs == 0 then
    row("nixpkgs", S.lockErr or "reading flake.lock…")
  end
  for _, i in ipairs(S.inputs) do
    local v
    if i.err then
      v = "error: " .. i.err
    elseif not i.remoteSha then
      v = "checking…"
    elseif not i.behind then
      v = "up to date @" .. short(i.localRev)
    else
      v = short(i.localRev) .. " → @" .. short(i.remoteSha) .. " (" .. dayOf(i.remoteDate) .. ")"
    end
    row(i.name .. " (" .. i.branch .. ")", v)
  end
  if S.upstreamCi then
    row("upstream CI", S.upstreamCi)
  end
  if S.head then
    row("local tree", (S.dirty and "dirty • @" or "clean @") .. short(S.head))
  elseif S.lockErr then
    row("local tree", S.lockErr)
  else
    row("local tree", "…")
  end
  if S.ci then
    row("dotfiles CI", tostring(S.ci.conclusion or S.ci.status) .. " @" .. short(S.ci.sha))
  else
    row("dotfiles CI", "…")
  end
  if #S.prs == 0 then
    row("open PRs", "none")
  else
    local bits = {}
    for idx, p in ipairs(S.prs) do
      if idx > 3 then
        break
      end
      bits[#bits + 1] = "#" .. tostring(p.number) .. " " .. p.title
    end
    local more = #S.prs - #bits
    if more > 0 then
      bits[#bits + 1] = "+" .. tostring(more) .. " more"
    end
    row("open PRs (" .. tostring(#S.prs) .. ")", table.concat(bits, " | "))
  end
  if S.net ~= "ok" then
    local detail = S.net
    if S.netDetail ~= "" then
      detail = detail .. " (" .. S.netDetail .. ")"
    end
    row("network", detail)
  end
  if S.lastOk then
    row("last check", noctalia.formatTime("{:%H:%M}", S.lastOk))
  else
    row("last check", "never")
  end
  row("hint", "click = check now")

  barWidget.setTooltip(rows)
end

-- ---------------------------------------------------------------- fetching

-- Forward declaration: the fetch chain aborts into finalize().
local finalize

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
    -- DNS / no route: no internet.
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

-- Local state: flake.lock revs/branches (sync read) + git HEAD/dirty (async).
local function refreshLocal(done)
  S.inputs = {}
  S.lockErr = nil
  local raw = noctalia.readFile(flakePath() .. "/flake.lock")
  if not raw then
    S.lockErr = "cannot read flake.lock"
  else
    local lock = decodeObj(raw)
    if type(lock) ~= "table" or type(lock.nodes) ~= "table" then
      S.lockErr = "cannot parse flake.lock"
    else
      -- Resolve via root.inputs so lock-file node renumbering never matters.
      local root = lock.nodes.root
      local idx = root and root.inputs
      for _, name in ipairs(TRACKED) do
        local inp = { name = name, branch = "?", behind = false }
        local nodeName = type(idx) == "table" and idx[name] or nil
        local node = type(nodeName) == "string" and lock.nodes[nodeName] or nil
        local locked = node and node.locked
        local orig = node and node.original
        if type(locked) == "table" and type(locked.rev) == "string" then
          inp.localRev = locked.rev
          local ref = type(orig) == "table" and orig.ref or locked.ref
          if type(ref) == "string" then
            inp.branch = ref
          end
        else
          inp.err = "not in flake.lock"
        end
        S.inputs[#S.inputs + 1] = inp
      end
    end
  end

  local cmd = "D="
    .. shDir()
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
    done()
  end)
end

local function fetchInputs(idx, done)
  local inp = S.inputs[idx]
  if not inp then
    done()
    return
  end
  if not inp.localRev then
    fetchInputs(idx + 1, done)
    return
  end
  get(API .. "/repos/NixOS/nixpkgs/commits/" .. inp.branch, function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local c = decodeObj(body)
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

local function fetchCi(done)
  get(API .. "/repos/" .. dotfilesRepo() .. "/actions/runs?branch=main&per_page=5", function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local d = decodeObj(body)
      local runs = d and d.workflow_runs
      if type(runs) == "table" then
        local pick = nil
        for _, r in ipairs(runs) do
          if r.head_sha == S.head then
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

local function fetchPrs(done)
  get(API .. "/repos/" .. dotfilesRepo() .. "/pulls?state=open&per_page=20", function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local d = decodeObj(body)
      S.prs = {}
      if type(d) == "table" then
        for _, p in ipairs(d) do
          if type(p.number) == "number" then
            S.prs[#S.prs + 1] = {
              number = p.number,
              title = tostring(p.title or ""),
              ref = (p.head and p.head.ref) or "",
            }
          end
        end
      end
    end
    done()
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
  get(API .. "/repos/NixOS/nixpkgs/commits/" .. target.remoteSha .. "/check-runs?per_page=100", function(ok, status, body)
    if fatal(ok, status, body) then
      finalize()
      return
    end
    if tonumber(status) == 200 then
      local d = decodeObj(body)
      local runs = d and d.check_runs
      if type(runs) == "table" and #runs > 0 then
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
          S.upstreamCi = "failing (" .. tostring(bad) .. "/" .. tostring(#runs) .. ")"
        elseif pending > 0 then
          S.upstreamCi = "pending (" .. tostring(pending) .. ")"
        else
          S.upstreamCi = "passing"
        end
      else
        S.upstreamCi = "no checks"
      end
    end
    done()
  end)
end

finalize = function()
  local now = os.time()
  S.busy = false
  S.lastRun = now
  if S.net == "ok" then
    S.lastOk = now
    for _, i in ipairs(S.inputs) do
      if i.localRev and i.remoteSha then
        if i.behind then
          if N.inputs[i.branch] ~= i.remoteSha then
            N.inputs[i.branch] = i.remoteSha
            noctalia.notify(
              "NixOS updates available",
              i.name .. " (" .. i.branch .. "): @" .. short(i.localRev) .. " → @" .. short(i.remoteSha)
            )
          end
        elseif N.inputs[i.branch] then
          N.inputs[i.branch] = nil
          noctalia.notify("NixOS up to date", i.name .. " (@" .. short(i.localRev) .. ")")
        end
      end
    end
    if S.ci and S.ci.sha then
      if S.ci.conclusion == "failure" and N.ciFail ~= S.ci.sha then
        N.ciFail = S.ci.sha
        noctalia.notifyError("dotfiles CI failing", "main @" .. short(S.ci.sha))
      elseif S.ci.conclusion == "success" and N.ciFail then
        N.ciFail = nil
        noctalia.notify("dotfiles CI green", "main @" .. short(S.ci.sha))
      end
    end
    local seen = {}
    for _, p in ipairs(S.prs) do
      local key = tostring(p.number)
      seen[key] = true
      if not N.prs[key] then
        N.prs[key] = true
        noctalia.notify("PR open: #" .. key, p.title)
      end
    end
    for num, _ in pairs(N.prs) do
      if not seen[num] then
        N.prs[num] = nil
      end
    end
    persist()
  end
  render()
end

-- --------------------------------------------------------------- lifecycle

function update()
  noctalia.setUpdateInterval(pollMs())
  local now = os.time()
  if S.busy then
    if now - S.busySince > BUSY_TIMEOUT then
      S.busy = false
      noctalia.log("nixos-updates: stuck check reset")
    else
      render()
      return
    end
  end
  if not S.forced then
    if now < S.backoffUntil then
      render()
      return
    end
    if S.lastRun > 0 and (now - S.lastRun) * 1000 < pollMs() then
      render()
      return
    end
  end
  S.forced = false
  if noctalia.getSetting("shell.offline_mode") == true then
    S.net = "offline"
    S.netDetail = "shell offline_mode"
    render()
    return
  end
  S.busy = true
  S.busySince = now
  render()
  refreshLocal(function()
    fetchInputs(1, function()
      fetchCi(function()
        fetchPrs(function()
          fetchUpstreamCi(function()
            finalize()
          end)
        end)
      end)
    end)
  end)
end

function onClick()
  S.forced = true
  S.backoffUntil = 0
  update()
end

function onIpc(event, _payload)
  if event == "check" then
    onClick()
  elseif event == "open" then
    noctalia.runAsync("xdg-open 'https://github.com/" .. dotfilesRepo() .. "/pulls'")
  end
end
