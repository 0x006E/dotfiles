-- Shared pure helpers for the ntsv/nixos-updates entries.
-- Required by service.luau, widget.luau and panel.luau. Each entry runs this
-- module in its own VM (no shared mutable state here); cross-entry state
-- flows through noctalia.state, persistence through pluginDataDir.

local M = {}

function M.cfg(key, fallback)
  local v = noctalia.getConfig(key)
  if v == nil then
    return fallback
  end
  return v
end

function M.pollMs()
  local m = tonumber(M.cfg("poll_minutes", 30)) or 30
  if m < 5 then
    m = 5
  end
  if m > 720 then
    m = 720
  end
  return math.floor(m * 60 * 1000)
end

function M.flakePath()
  local p = M.cfg("flake_path", "~/nix")
  if type(p) ~= "string" or p == "" then
    p = "~/nix"
  end
  return p
end

function M.dotfilesRepo()
  local r = M.cfg("dotfiles_repo", "0x006E/dotfiles")
  if type(r) ~= "string" or r == "" then
    r = "0x006E/dotfiles"
  end
  return r
end

function M.maxInputs()
  local n = tonumber(M.cfg("max_inputs", 12)) or 12
  if n < 1 then
    n = 1
  end
  if n > 25 then
    n = 25
  end
  return math.floor(n)
end

function M.short(sha)
  if type(sha) ~= "string" then
    return "?"
  end
  return string.sub(sha, 1, 7)
end

function M.dayOf(iso)
  if type(iso) ~= "string" then
    return "?"
  end
  return string.sub(iso, 1, 10)
end

-- noctalia.http is documented both as cb(response-table) and
-- cb(ok, status, body); accept either shape.
function M.get(url, headers, cb)
  noctalia.http({ url = url, method = "GET", headers = headers }, function(a, b, c)
    if type(a) == "table" then
      cb(a.ok, a.status, a.body)
    else
      cb(a, b, c)
    end
  end)
end

function M.decodeObj(body)
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
function M.shDir()
  local p = M.flakePath()
  if string.sub(p, 1, 2) == "~/" then
    return '"$HOME"' .. sq(string.sub(p, 2))
  end
  return sq(p)
end

-- Noctalia's launcher scrubs dev tools (git) from PATH; restore the
-- usual user/system locations for any shell command we run.
function M.envPrefix()
  return "export PATH=\"$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH\""
    .. "; export GIT_TERMINAL_PROMPT=0"
end

function M.behindCount(inputs)
  local n = 0
  for _, i in ipairs(inputs) do
    if i.behind then
      n = n + 1
    end
  end
  return n
end

function M.cookingCount(prs)
  local n = 0
  for _, p in ipairs(prs) do
    if p.ci == "pending" or p.ci == "running" then
      n = n + 1
    end
  end
  return n
end

function M.failedPr(prs)
  for _, p in ipairs(prs) do
    if p.ci == "failing" then
      return p
    end
  end
  return nil
end

local cmdCounter = 0

-- Fire-and-forget command to the fetcher service over the state channel.
-- The nonce guarantees watchers fire even for repeated commands.
function M.sendCommand(name)
  cmdCounter = cmdCounter + 1
  noctalia.state.set("command", { name = name, nonce = os.time() * 1000 + cmdCounter })
end

-- Bar-widget face for a snapshot. Keeps text tiny: the bar is vertical.
function M.face(snap)
  local behind = M.behindCount(snap.inputs)
  local badPr = M.failedPr(snap.prs)
  local glyph = "check"
  local text = ""
  if snap.net == "offline" then
    glyph = "wifi-off"
  elseif snap.net == "ratelimit" then
    glyph = "clock"
  elseif snap.busy then
    glyph = "loader-2"
  elseif snap.lockErr then
    glyph = "alert-triangle"
    text = "!"
  elseif badPr then
    glyph = "alert-triangle"
    text = "!" .. tostring(badPr.number)
  elseif behind > 0 and snap.ci and snap.ci.conclusion == "failure" then
    glyph = "alert-triangle"
    text = "+" .. tostring(behind)
  elseif behind > 0 then
    glyph = "package"
    text = "+" .. tostring(behind)
    if snap.dirty then
      text = text .. "•"
    end
  elseif snap.dotfiles.behind and snap.ci and snap.ci.conclusion == "success" then
    glyph = "arrow-down-circle"
    text = "↓"
  elseif snap.dirty then
    glyph = "pencil"
    text = "•"
  elseif snap.ci and snap.ci.conclusion == "failure" then
    glyph = "alert-triangle"
    text = "!"
  elseif #snap.prs > 0 then
    glyph = "git-pull-request"
    text = tostring(#snap.prs)
  end
  return glyph, text
end

-- One-line headline + sub-line for the panel header.
function M.headline(snap)
  local behind = M.behindCount(snap.inputs)
  local badPr = M.failedPr(snap.prs)
  if snap.net == "offline" then
    return "Offline", "check your connection"
  elseif snap.net == "ratelimit" then
    return "Rate limited", "GitHub quota — retry later"
  elseif snap.busy then
    return "Checking…", "contacting GitHub"
  elseif snap.lockErr then
    return "Cannot read flake", snap.lockErr
  elseif badPr then
    return "PR #" .. tostring(badPr.number) .. " CI failed", "needs your attention"
  elseif behind > 0 then
    local s = behind == 1 and "update available" or "updates available"
    return tostring(behind) .. " flake " .. s, "see inputs below"
  elseif snap.dotfiles.behind then
    if snap.ci and snap.ci.conclusion == "success" then
      return "Dotfiles update ready", "CI green — safe to pull"
    elseif snap.ci and snap.ci.conclusion == "failure" then
      return "Remote ahead, CI failing", "hold off on pulling"
    else
      return "Dotfiles update cooking", "CI still running"
    end
  elseif snap.dirty then
    return "Local changes", "tree is dirty"
  elseif #snap.prs > 0 then
    return tostring(#snap.prs) .. " open PRs", "nothing actionable"
  else
    return "Up to date", "everything matches upstream"
  end
end

return M
