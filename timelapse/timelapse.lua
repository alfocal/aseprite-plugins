-- Timelapse: records how a drawing is made, a snapshot after every change,
-- into a <title>.timelapse file next to it, and exports the recording as an
-- animation. Recording is per sprite and resumes when the sprite is opened.

local S      -- snapshot files (snapshots.lua), loaded in init()
local prefs  -- plugin.preferences, kept between sessions

local CAPTURE_DELAY = 0.25  -- changes closer than this share a snapshot
local LENGTHS = { "All", "10 s", "20 s", "30 s", "60 s" }
local SPEEDS = { "5", "10", "15", "20", "25", "30" }
local EXPORT_SIDE = 512  -- the export scale aims for at least this size
local CLOSING = { CloseFile=true, CloseAllFiles=true, Exit=true }

local recorders = {}  -- one per sprite being recorded
local timer, siteListener, commandListener, lastSprite

-- Comparing against a closed sprite can raise an error
local function sameSprite(a, b)
  local ok, eq = pcall(function() return a == b end)
  return ok and eq
end

local function isOpen(spr)
  return (pcall(function() return spr.width end))
end

-- <title>.timelapse next to the sprite file, nil if it was never saved
local function pathFor(spr)
  local fn = spr.filename
  local dir = app.fs.filePath(fn)
  if dir == "" then return nil end
  return app.fs.joinPath(dir, app.fs.fileTitle(fn) .. ".timelapse")
end

local function hasTimelapse()
  local spr = app.sprite
  local path = spr and pathFor(spr)
  return path ~= nil and app.fs.isFile(path)
end

local function isPaused(path)
  for _, p in ipairs(prefs.paused or {}) do
    if p == path then return true end
  end
  return false
end

local function setPaused(path, paused)
  local list = {}
  for _, p in ipairs(prefs.paused or {}) do
    if p ~= path then table.insert(list, p) end
  end
  if paused then table.insert(list, path) end
  prefs.paused = list
end

local function recorderOf(spr)
  for _, rec in ipairs(recorders) do
    if sameSprite(rec.sprite, spr) then return rec end
  end
end

local function unwatch(rec)
  for _, id in ipairs(rec.listeners) do
    pcall(function() rec.sprite.events:off(id) end)
  end
  for i, r in ipairs(recorders) do
    if r == rec then
      table.remove(recorders, i)
      break
    end
  end
end

-- Closed sprites take their listeners with them
local function prune()
  for i = #recorders, 1, -1 do
    if not isOpen(recorders[i].sprite) then table.remove(recorders, i) end
  end
end

-- Pauses after an error, so it isn't retried every time the sprite is
-- activated. Record resumes it.
local function fail(rec, err)
  unwatch(rec)
  setPaused(rec.path, true)
  app.alert{ title="Timelapse", text={ "Recording paused:", tostring(err) } }
end

-- Saves a snapshot of the frame being edited (if it changed)
local function capture(rec)
  rec.dirty = false
  local ok, err = pcall(function()
    local spr = rec.sprite
    local img = Image(spr.width, spr.height, ColorMode.RGB)
    img:drawSprite(spr, math.min(rec.frame, #spr.frames))
    S.append(rec.path, img, rec.prev)
    rec.prev = img
  end)
  if not ok then
    if isOpen(rec.sprite) then fail(rec, err) else unwatch(rec) end
  end
end

local function flush()
  timer:stop()
  for _, rec in ipairs({ table.unpack(recorders) }) do
    if rec.dirty then capture(rec) end
  end
end

local function changed(rec)
  if sameSprite(app.sprite, rec.sprite) and app.frame then
    rec.frame = app.frame.frameNumber
  end
  rec.dirty = true
  if not timer.isRunning then timer:start() end
end

-- After "Save As" the new file gets a copy of the timelapse (the old file
-- keeps its own) and recording goes on there
local function renamed(rec)
  local path = pathFor(rec.sprite)
  if not path or path == rec.path then return end
  local ok, err = pcall(S.copy, rec.path, path)
  rec.path = path
  if not ok then fail(rec, err) end
end

local function watch(spr, path)
  local rec = { sprite=spr, path=path, listeners={},
                frame=app.frame and app.frame.frameNumber or 1 }
  for name, fn in pairs{ change=changed, filenamechange=renamed } do
    local ok, id = pcall(function()
      return spr.events:on(name, function() fn(rec) end)
    end)
    if ok then table.insert(rec.listeners, id) end
  end
  table.insert(recorders, rec)
  return rec
end

-- Picks up recording when a sprite with a timelapse becomes active
local function siteChanged()
  -- Here, not after the check below: closing a sprite changes the site
  -- before the sprite is gone
  prune()
  local spr = app.sprite
  if sameSprite(spr, lastSprite) then return end
  lastSprite = spr
  if not spr or recorderOf(spr) then return end
  local path = pathFor(spr)
  if not (path and app.fs.isFile(path)) or isPaused(path) then return end
  local ok, err = pcall(S.check, path)
  if ok then
    watch(spr, path)
  else
    setPaused(path, true)
    app.alert{ title="Timelapse", text={ "Couldn't resume the timelapse:", tostring(err) } }
  end
end

-- Aseprite asks before a script reads or writes files. Unless the user
-- tells it not to, it would ask again on every snapshot.
local function explainPermissions()
  if prefs.permissionsExplained then return end
  prefs.permissionsExplained = true
  app.alert{ title="Timelapse", text={
    "Aseprite is going to ask whether Timelapse can write and read",
    "its .timelapse files. Allow it and check",
    "\"Don't show this specific alert again for this script\",",
    "or it will ask again on every snapshot." } }
end

local function toggleRecording()
  local spr = app.sprite
  if not spr then return end
  local rec = recorderOf(spr)
  if rec then
    if rec.dirty then capture(rec) end
    unwatch(rec)
    setPaused(rec.path, true)
    return
  end

  local path = pathFor(spr)
  if not path then
    local choice = app.alert{ title="Timelapse",
      text={ "Save the sprite first: its timelapse is kept",
             "next to it, in a .timelapse file." },
      buttons={ "&Save...", "&Cancel" } }
    if choice ~= 1 then return end
    app.command.SaveFile()
    path = pathFor(spr)
    if not path then return end
  end

  explainPermissions()
  local isNew = not app.fs.isFile(path)
  local ok, err = pcall(function()
    if isNew then S.create(path) end
    S.check(path)
  end)
  if not ok then
    app.alert{ title="Timelapse", text={ "Couldn't record the timelapse:", tostring(err) } }
    return
  end
  setPaused(path, false)
  rec = watch(spr, path)
  -- A new timelapse starts with the canvas as it is now
  if isNew then capture(rec) end
end

local function fileSize(bytes)
  if bytes < 1024 * 1024 then
    return string.format("%d KB", math.ceil(bytes / 1024))
  end
  return string.format("%.1f MB", bytes / (1024 * 1024))
end

-- Frames to export, their speed and the total length, from the export
-- dialog data
local function plan(info, d)
  local fps = tonumber(d.fps)
  local seconds = d.length:match("%d+")  -- nil for "All"
  local frames = seconds and math.min(info.count, tonumber(seconds) * fps) or info.count
  return frames, fps, (frames - 1) / fps + math.max(1 / fps, d.hold)
end

-- n of the snapshots 1..count, evenly spaced, always the first and last
local function pick(count, n)
  local picks = {}
  if n >= count then
    for i = 1, count do picks[i] = true end
  else
    for k = 0, n - 1 do picks[1 + k * (count - 1) // (n - 1)] = true end
  end
  return picks
end

-- New sprite with one frame per picked snapshot
local function build(path, info, o)
  local picks = pick(info.count, o.frames)
  local out = Sprite(info.width, info.height, ColorMode.RGB)
  app.sprite = out  -- app.transaction works on the active sprite
  local ok, err = pcall(function()
    local layer, n = out.layers[1], 0
    app.transaction("Build Timelapse", function()
      -- New sprites from scripts get 256 black colors
      out:setPalette(o.palette)
      S.replay(path, function(canvas, i)
        if not picks[i] then return end
        n = n + 1
        local frame = n == 1 and out.frames[1] or out:newEmptyFrame()
        frame.duration = 1 / o.fps
        local img = Image(canvas)
        if o.background then
          img = Image(out.width, out.height, ColorMode.RGB)
          img:clear(o.background)
          img:drawImage(canvas, Point(0, 0))
        end
        out:newCel(layer, frame, img, Point(0, 0))
      end)
      local last = out.frames[#out.frames]
      last.duration = math.max(last.duration, o.hold)
    end)
  end)
  if not ok then
    out:close()
    error(err, 0)
  end
  return out
end

local function exportTimelapse()
  local spr = app.sprite
  local path = spr and pathFor(spr)
  if not (path and app.fs.isFile(path)) then return end
  flush()
  local ok, info = pcall(S.check, path)
  if not ok then
    app.alert{ title="Timelapse", text={ "Couldn't read the timelapse:", tostring(info) } }
    return
  end
  if info.count == 0 then
    app.alert{ title="Timelapse", text="The timelapse has no snapshots yet." }
    return
  end

  local bg = prefs.bg or { r=255, g=255, b=255 }
  local dlg = Dialog{ title="Export Timelapse" }
  local function update()
    local frames, _, seconds = plan(info, dlg.data)
    dlg:modify{ id="result", text=string.format("%d frames, %.1f s", frames, seconds) }
  end
  dlg:label{ label="Recorded",
             text=string.format("%d snapshots (%s)", info.count, fileSize(info.size)) }
  dlg:combobox{ id="length", label="Length", option=prefs.length or "30 s",
                options=LENGTHS, onchange=update }
  dlg:combobox{ id="fps", label="Speed (fps)", option=prefs.fps or "15",
                options=SPEEDS, onchange=update }
  dlg:slider{ id="hold", label="Hold end (s)", min=0, max=5, value=prefs.hold or 2,
              onchange=update }
  dlg:check{ id="fill", label="Background", text="Fill", selected=prefs.fill or false }
  dlg:color{ id="bg", color=Color{ r=bg.r, g=bg.g, b=bg.b } }
  dlg:label{ id="result", label="Result", text="" }
  dlg:separator()
  dlg:button{ id="export", text="&Export...", focus=true }
  dlg:button{ id="open", text="&Open as Sprite" }
  dlg:button{ id="cancel", text="&Cancel" }
  update()
  dlg:show()

  local d = dlg.data
  if not (d.export or d.open) then return end
  prefs.length, prefs.fps, prefs.hold, prefs.fill = d.length, d.fps, d.hold, d.fill
  prefs.bg = { r=d.bg.red, g=d.bg.green, b=d.bg.blue }

  local frames, fps = plan(info, d)
  local gb = frames * info.width * info.height * 4 / 1024 ^ 3
  if gb > 1 and app.alert{ title="Export Timelapse",
      text=string.format("%d frames need about %.1f GB of memory.", frames, gb),
      buttons={ "&Continue", "&Cancel" } } ~= 1 then
    return
  end

  local built, out = pcall(build, path, info,
                           { frames=frames, fps=fps, hold=d.hold, background=d.fill and d.bg,
                             palette=spr.palettes[1] })
  if not built then
    app.alert{ title="Timelapse", text={ "Couldn't build the timelapse:", tostring(out) } }
    return
  end
  local dir, title = app.fs.filePath(spr.filename), app.fs.fileTitle(spr.filename)
  if d.export then
    -- Aseprite's own export dialog: format, scale, etc.
    app.command.SaveFileCopyAs{
      ui=true,
      filename=app.fs.joinPath(dir, title .. "-timelapse.gif"),
      scale=math.max(1, EXPORT_SIDE // math.max(info.width, info.height)) }
    out:close()
    app.sprite = spr
  else
    out.filename = app.fs.joinPath(dir, title .. "-timelapse.aseprite")
  end
end

local function deleteTimelapse()
  local spr = app.sprite
  local path = spr and pathFor(spr)
  if not (path and app.fs.isFile(path)) then return end
  local choice = app.alert{ title="Delete Timelapse",
    text={ "Delete the timelapse of " .. app.fs.fileName(spr.filename) .. "?",
           "This can't be undone." },
    buttons={ "&Delete", "&Cancel" } }
  if choice ~= 1 then return end
  local rec = recorderOf(spr)
  if rec then unwatch(rec) end
  setPaused(path, false)
  local ok, err = pcall(S.remove, path)
  if not ok then
    app.alert{ title="Timelapse", text={ "Couldn't delete the timelapse:", tostring(err) } }
  end
end

function init(plugin)
  prefs = plugin.preferences
  S = dofile(app.fs.joinPath(plugin.path, "snapshots.lua"))

  timer = Timer{ interval=CAPTURE_DELAY, ontick=flush }
  siteListener = app.events:on('sitechange', siteChanged)
  -- Saves the last change before its sprite closes
  local ok, id = pcall(function()
    return app.events:on('beforecommand', function(ev)
      if CLOSING[ev.name] then flush() end
    end)
  end)
  if ok then commandListener = id end

  plugin:newMenuGroup{ id="timelapse_menu", title="Timelapse", group="file_export" }
  plugin:newCommand{
    id="TimelapseRecord",
    title="Record Timelapse",
    group="timelapse_menu",
    onclick=toggleRecording,
    onenabled=function() return app.sprite ~= nil end,
    onchecked=function() return app.sprite ~= nil and recorderOf(app.sprite) ~= nil end,
  }
  plugin:newCommand{
    id="TimelapseExport",
    title="Export Timelapse...",
    group="timelapse_menu",
    onclick=exportTimelapse,
    onenabled=hasTimelapse,
  }
  plugin:newMenuSeparator{ group="timelapse_menu" }
  plugin:newCommand{
    id="TimelapseDelete",
    title="Delete Timelapse...",
    group="timelapse_menu",
    onclick=deleteTimelapse,
    onenabled=hasTimelapse,
  }

  siteChanged()
end

function exit(plugin)
  if timer then pcall(flush) end
  for _, rec in ipairs({ table.unpack(recorders) }) do unwatch(rec) end
  if siteListener then app.events:off(siteListener) end
  if commandListener then app.events:off(commandListener) end
  timer, siteListener, commandListener, lastSprite = nil, nil, nil, nil
end
