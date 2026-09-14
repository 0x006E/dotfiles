-- ntsv/nixos-updates:updates (bar widget)
--
-- Thin renderer: the fetcher service owns polling and publishes a snapshot
-- on noctalia.state ("snapshot"). Click toggles the side panel; the
-- Mod+Shift+U keybind ("check" IPC) is forwarded to the service over the
-- command channel.

local H = require("./lib/helpers.luau")

local PANEL_ID = "ntsv/nixos-updates:main"

local sendCommand = H.sendCommand

local function emptySnapshot()
  return {
    busy = false,
    net = "starting",
    netDetail = "",
    inputs = {},
    skippedInputs = 0,
    head = nil,
    dirty = false,
    lockErr = nil,
    dotfiles = {},
    ci = nil,
    prs = {},
    upstreamCi = nil,
    lastOk = nil,
    pull = { state = "idle", msg = "" },
  }
end

local function render(snap)
  if type(snap) ~= "table" then
    snap = emptySnapshot()
  end
  if type(snap.inputs) ~= "table" then
    snap.inputs = {}
  end
  if type(snap.prs) ~= "table" then
    snap.prs = {}
  end
  if type(snap.dotfiles) ~= "table" then
    snap.dotfiles = {}
  end
  local glyph, text = H.face(snap)
  barWidget.setGlyph(glyph)
  barWidget.setText(text)

  local rows = {}
  local function row(k, v)
    rows[#rows + 1] = { key = tostring(k), value = tostring(v) }
  end

  if snap.busy and #snap.inputs == 0 then
    row("status", "checking…")
  end
  if snap.lockErr then
    row("flake.lock", snap.lockErr)
  end
  for _, i in ipairs(snap.inputs) do
    local v
    if i.err then
      v = "error: " .. i.err
    elseif not i.remoteSha then
      v = "checking…"
    elseif not i.behind then
      v = "up to date @" .. H.short(i.localRev)
    else
      v = H.short(i.localRev) .. " → @" .. H.short(i.remoteSha) .. " (" .. H.dayOf(i.remoteDate) .. ")"
    end
    row(i.name .. " (" .. (i.branch or "?") .. ")", v)
  end
  if (snap.skippedInputs or 0) > 0 then
    row("untracked inputs", tostring(snap.skippedInputs) .. " (cap)")
  end
  if snap.upstreamCi then
    row("upstream CI", snap.upstreamCi)
  end
  local d = snap.dotfiles
  if d.remoteHead then
    if d.behind then
      row("dotfiles", H.short(d.localHead) .. " → @" .. H.short(d.remoteHead))
    else
      row("dotfiles", "up to date @" .. H.short(d.remoteHead))
    end
  elseif snap.head then
    row("local tree", (snap.dirty and "dirty • @" or "clean @") .. H.short(snap.head))
  else
    row("local tree", "…")
  end
  if snap.head and d.remoteHead then
    row("local tree", (snap.dirty and "dirty • @" or "clean @") .. H.short(snap.head))
  end
  if snap.ci then
    row("dotfiles CI", tostring(snap.ci.conclusion or snap.ci.status) .. " @" .. H.short(snap.ci.sha))
  else
    row("dotfiles CI", "…")
  end
  if #snap.prs == 0 then
    row("open PRs", "none")
  else
    local bits = {}
    for idx, p in ipairs(snap.prs) do
      if idx > 3 then
        break
      end
      bits[#bits + 1] = "#" .. tostring(p.number) .. " [" .. tostring(p.ci or "?") .. "]"
    end
    if #snap.prs > #bits then
      bits[#bits + 1] = "+" .. tostring(#snap.prs - #bits) .. " more"
    end
    row("open PRs (" .. tostring(#snap.prs) .. ")", table.concat(bits, " | "))
  end
  if snap.pull and snap.pull.state ~= "idle" then
    row("pull", tostring(snap.pull.state) .. ": " .. tostring(snap.pull.msg or ""))
  end
  if snap.net ~= "ok" then
    local detail = snap.net
    if snap.netDetail ~= "" then
      detail = detail .. " (" .. snap.netDetail .. ")"
    end
    row("network", detail)
  end
  if snap.lastOk then
    row("last check", noctalia.formatTime("{:%H:%M}", snap.lastOk))
  else
    row("last check", "never")
  end
  row("hint", "click = details panel")
  barWidget.setTooltip(rows)
end

noctalia.state.watch("snapshot", render)
render(noctalia.state.get("snapshot"))

-- Cheap convergence tick in case a watch callback is ever missed.
function update()
  noctalia.setUpdateInterval(60000)
  render(noctalia.state.get("snapshot"))
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onIpc(event, _payload)
  if event == "check" then
    sendCommand("check")
  elseif event == "open" then
    noctalia.togglePanel(PANEL_ID)
  end
end
