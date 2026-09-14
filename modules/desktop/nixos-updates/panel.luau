-- ntsv/nixos-updates:main ([[panel]])
--
-- Side panel with the full picture: flake inputs vs upstream, dotfiles
-- local vs remote, CI and PR states, plus Check now / Pull / PRs buttons.
-- Renders from the fetcher service snapshot (noctalia.state); commands go
-- back over the same channel. Opened by clicking the bar widget.

local H = require("./lib/helpers.luau")

local open = false

local function snap()
  local s = noctalia.state.get("snapshot")
  if type(s) ~= "table" then
    return nil
  end
  return s
end

local function sectionTitle(text)
  return ui.label({ text = text, fontSize = 12, fontWeight = "bold" })
end

local function statusGlyph(name)
  return ui.glyph({ name = name, size = 16 })
end

local function inputRow(i)
  local g = "check"
  local detail = "checking…"
  if i.err then
    g = "alert-triangle"
    detail = "error: " .. tostring(i.err)
  elseif i.remoteSha then
    if i.behind then
      g = "package-plus"
      detail = "@" .. H.short(i.localRev) .. " → @" .. H.short(i.remoteSha) .. " · " .. H.dayOf(i.remoteDate)
    else
      detail = "up to date @" .. H.short(i.localRev)
    end
  end
  return ui.row({ gap = 10, align = "center" }, {
    statusGlyph(g),
    ui.column({ gap = 2 }, {
      ui.label({ text = tostring(i.name) .. " (" .. tostring(i.branch or "?") .. ")", fontWeight = "bold" }),
      ui.label({ text = detail, fontSize = 12 }),
    }),
  })
end

local function prRow(p)
  local g = "git-pull-request"
  local ci = tostring(p.ci or "unknown")
  if ci == "failing" then
    g = "alert-triangle"
  elseif ci == "passing" then
    g = "check"
  elseif ci == "pending" or ci == "running" then
    g = "loader-2"
  end
  return ui.row({ gap = 10, align = "center" }, {
    statusGlyph(g),
    ui.column({ gap = 2 }, {
      ui.label({ text = "#" .. tostring(p.number) .. " " .. tostring(p.title), fontWeight = "bold", maxLines = 1 }),
      ui.label({ text = "CI: " .. ci .. " · " .. tostring(p.ref or ""), fontSize = 12 }),
    }),
  })
end

local function render()
  local s = snap()
  local body = {}

  if not s then
    body[#body + 1] = ui.label({ text = "Starting…", fontSize = 14 })
    body[#body + 1] = ui.label({ text = "waiting for the first poll", fontSize = 12 })
    panel.render(ui.column({ gap = 12, padding = 16 }, body))
    return
  end

  local headline, sub = H.headline(s)
  local faceGlyph, _ = H.face(s)

  -- Header
  body[#body + 1] = ui.row({ gap = 10, align = "center" }, {
    statusGlyph(faceGlyph),
    ui.column({ gap = 2 }, {
      ui.label({ text = headline, fontSize = 16, fontWeight = "bold", color = "primary" }),
      ui.label({ text = sub, fontSize = 12 }),
    }),
    ui.spacer({ flexGrow = 1 }),
    ui.button({ glyph = "close", glyphSize = 14, variant = "ghost", onClick = "onCloseClicked" }),
  })
  body[#body + 1] = ui.separator({})

  -- Flake inputs: behind first, clean ones summarized.
  body[#body + 1] = sectionTitle("Flake inputs")
  local clean = 0
  local shown = 0
  for _, i in ipairs(s.inputs) do
    if i.behind or i.err or not i.remoteSha then
      if shown < 8 then
        body[#body + 1] = inputRow(i)
        shown = shown + 1
      end
    else
      clean = clean + 1
    end
  end
  if H.behindCount(s.inputs) == 0 and not s.lockErr then
    body[#body + 1] = ui.row({ gap = 10, align = "center" }, {
      statusGlyph("check"),
      ui.label({ text = tostring(clean) .. " inputs up to date", fontSize = 12 }),
    })
  elseif clean > 0 then
    body[#body + 1] = ui.label({ text = "+ " .. tostring(clean) .. " up to date", fontSize = 12 })
  end
  if s.lockErr then
    body[#body + 1] = ui.label({ text = tostring(s.lockErr), fontSize = 12 })
  end
  if (s.skippedInputs or 0) > 0 then
    body[#body + 1] = ui.label({ text = tostring(s.skippedInputs) .. " inputs untracked (cap)", fontSize = 12 })
  end
  if s.upstreamCi then
    body[#body + 1] = ui.label({ text = "Upstream CI: " .. tostring(s.upstreamCi), fontSize = 12 })
  end
  body[#body + 1] = ui.separator({})

  -- Dotfiles
  body[#body + 1] = sectionTitle("Dotfiles")
  local d = s.dotfiles or {}
  if d.remoteHead then
    if d.behind then
      body[#body + 1] =
        ui.label({ text = "Behind: " .. H.short(d.localHead) .. " → @" .. H.short(d.remoteHead), fontSize = 12 })
    else
      body[#body + 1] = ui.label({ text = "Up to date @" .. H.short(d.remoteHead), fontSize = 12 })
    end
    if d.remoteMsg then
      body[#body + 1] = ui.label({ text = tostring(d.remoteMsg), fontSize = 12, maxLines = 2 })
    end
  end
  body[#body + 1] = ui.row({ gap = 10, align = "center" }, {
    statusGlyph(s.dirty and "pencil" or "check"),
    ui.label({
      text = s.head and ("Tree " .. (s.dirty and "dirty • @" or "clean @") .. H.short(s.head)) or "Tree: …",
      fontSize = 12,
    }),
  })
  if s.ci then
    body[#body + 1] = ui.label({
      text = "CI: " .. tostring(s.ci.conclusion or s.ci.status) .. " @" .. H.short(s.ci.sha),
      fontSize = 12,
    })
  end

  -- Pull status line
  if s.pull and s.pull.state == "running" then
    body[#body + 1] = ui.label({ text = "Pulling…", fontSize = 12 })
  elseif s.pull and s.pull.state ~= "idle" then
    body[#body + 1] = ui.label({ text = "Pull " .. tostring(s.pull.state) .. ": " .. tostring(s.pull.msg or ""), fontSize = 12 })
  end

  -- PRs
  if #s.prs > 0 then
    body[#body + 1] = ui.separator({})
    body[#body + 1] = sectionTitle("Open PRs (" .. tostring(#s.prs) .. ")")
    for idx, p in ipairs(s.prs) do
      if idx > 4 then
        body[#body + 1] = ui.label({ text = "+ " .. tostring(#s.prs - 4) .. " more", fontSize = 12 })
        break
      end
      body[#body + 1] = prRow(p)
    end
  end

  body[#body + 1] = ui.separator({})

  -- Buttons
  local canPull = d.behind and not s.dirty and (not s.pull or s.pull.state ~= "running")
  local pullTip = "Pull latest main (fast-forward only)"
  if s.dirty then
    pullTip = "Tree is dirty — commit or stash first"
  elseif not d.behind then
    pullTip = "Already up to date"
  elseif s.pull and s.pull.state == "running" then
    pullTip = "Pull in progress…"
  end
  body[#body + 1] = ui.row({ gap = 8, justify = "center" }, {
    ui.button({ text = "Check now", glyph = "refresh", variant = "secondary", onClick = "onCheck" }),
    ui.button({
      text = "Pull",
      glyph = "arrow-down",
      variant = canPull and "primary" or "default",
      enabled = canPull,
      tooltip = pullTip,
      onClick = "onPull",
    }),
    ui.button({ text = "PRs", glyph = "git-pull-request", variant = "ghost", onClick = "onOpenPRs" }),
  })

  -- Footer
  local foot = "click Check now to re-poll"
  if s.lastOk then
    foot = "checked " .. noctalia.formatTime("{:%H:%M}", s.lastOk)
  end
  if s.net ~= "ok" then
    foot = foot .. " · " .. tostring(s.net)
  end
  body[#body + 1] = ui.label({ text = foot, fontSize = 12 })

  panel.render(ui.column({ gap = 10, padding = 16 }, body))
end

local function safeRender()
  if not open then
    return
  end
  local ok, err = pcall(render)
  if not ok then
    noctalia.log("nixos-updates panel render failed: " .. tostring(err))
  end
end

noctalia.state.watch("snapshot", safeRender)

function onOpen(_context)
  open = true
  safeRender()
end

function onClose()
  open = false
end

function onCheck()
  H.sendCommand("check")
end

function onPull()
  H.sendCommand("pull")
end

function onOpenPRs()
  noctalia.runAsync("/run/current-system/sw/bin/xdg-open 'https://github.com/" .. H.dotfilesRepo() .. "/pulls'")
end

function onCloseClicked()
  open = false
  panel.close()
end
