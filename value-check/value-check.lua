-- Value Check: a live grayscale preview of the active sprite to check its
-- values (lightness) while you paint. It never modifies the sprite.

local V      -- color math (values.lua), loaded in init()
local prefs  -- plugin.preferences, kept between sessions

local MODES = { "Perceptual (L*)", "Luma (Rec. 601)" }
local LEVELS = { "Off", "2", "3", "4", "5", "6", "8" }
local SPRITE_EVENTS = { "change", "layervisibility", "layeropacity", "layerblendmode" }

local MAX_SIDE = 640  -- bigger sprites are downscaled before processing
local CELL = 8        -- checkerboard cell size
local SURROUND = Color{ r=72, g=72, b=72 }
local CHECKER_A = app.pixelColor.rgba(120, 120, 120)
local CHECKER_B = app.pixelColor.rgba(150, 150, 150)

local dlg, timer, siteListener
local state = { listeners = {} }

local function indexOf(list, item)
  for i, v in ipairs(list) do
    if v == item then return i end
  end
end

-- Comparing against a closed sprite can raise an error
local function sameSprite(a, b)
  local ok, eq = pcall(function() return a == b end)
  return ok and eq
end

local function percent(v)
  return math.floor(v * 100 + 0.5)
end

local function schedule()
  if timer and not timer.isRunning then timer:start() end
end

local function unwatchSprite()
  local spr = state.sprite
  if spr then
    for _, id in ipairs(state.listeners) do
      pcall(function() spr.events:off(id) end)
    end
  end
  state.sprite, state.listeners = nil, {}
end

local function watchSprite(spr)
  unwatchSprite()
  state.sprite = spr
  if not spr then return end
  for _, name in ipairs(SPRITE_EVENTS) do
    local ok, id = pcall(function() return spr.events:on(name, schedule) end)
    if ok then table.insert(state.listeners, id) end
  end
end

local function rebuild()
  local spr = app.sprite
  if not sameSprite(spr, state.sprite) then watchSprite(spr) end
  state.frame = app.frame and app.frame.frameNumber
  state.flat, state.src, state.gray, state.lo, state.hi = nil, nil, nil, nil, nil
  if not spr then return end

  local flat = Image(spr.width, spr.height, ColorMode.RGB)
  flat:drawSprite(spr, state.frame or 1)
  local src = flat
  local side = math.max(flat.width, flat.height)
  if side > MAX_SIDE then
    src = Image(flat)
    src:resize(math.max(1, flat.width * MAX_SIDE // side),
               math.max(1, flat.height * MAX_SIDE // side))
  end
  state.flat, state.src = flat, src
  state.gray, state.lo, state.hi = V.grayscale(src, state.mode, state.levels)
end

-- The image drawn in the view: values or original colors, maybe mirrored
local function compose()
  local img = state.color and state.src or state.gray
  if img and state.flip then
    img = Image(img)
    img:flip(FlipType.HORIZONTAL)
  end
  state.shown = img
end

local function summary()
  if not state.flat then return "No sprite open" end
  if not state.lo then return "Fully transparent" end
  return string.format("Range %d - %d   (hover to inspect)",
                       percent(state.lo), percent(state.hi))
end

local function inspect(x, y)
  local c = state.flat:getPixel(x, y)
  local text = string.format("x%d y%d   ", x, y)
  if (c >> 24) == 0 then return text .. "transparent" end
  local v = V.value(state.mode, c & 0xff, (c >> 8) & 0xff, (c >> 16) & 0xff)
  text = text .. "value " .. percent(v)
  if state.levels >= 2 then
    text = text .. string.format("   band %d/%d", V.band(v, state.levels) + 1, state.levels)
  end
  return text
end

local function refresh()
  if not dlg then return end
  rebuild()
  compose()
  dlg:modify{ id="info", text=summary() }
  dlg:repaint()
end

local function drawChecker(gc, rc)
  local cols, rows = math.ceil(rc.width / CELL), math.ceil(rc.height / CELL)
  local img = state.checker
  if not img or img.width ~= cols or img.height ~= rows then
    img = Image(cols, rows)
    for it in img:pixels() do
      it((it.x + it.y) % 2 == 0 and CHECKER_A or CHECKER_B)
    end
    state.checker = img
  end
  gc:save()
  gc:beginPath()
  gc:rect(rc)
  gc:clip()
  gc:drawImage(img, img.bounds, Rectangle(rc.x, rc.y, cols * CELL, rows * CELL))
  gc:restore()
end

local function paint(ev)
  local gc = ev.context
  gc.color = SURROUND
  gc:fillRect(Rectangle(0, 0, gc.width, gc.height))
  state.view = nil
  local flat, shown = state.flat, state.shown
  if not shown then return end

  local scale = math.min(gc.width / flat.width, gc.height / flat.height)
  if scale >= 1 then scale = math.floor(scale) end  -- crisp pixels
  local w = math.max(1, math.floor(flat.width * scale))
  local h = math.max(1, math.floor(flat.height * scale))
  local view = Rectangle((gc.width - w) // 2, (gc.height - h) // 2, w, h)
  drawChecker(gc, view)
  gc:drawImage(shown, shown.bounds, view)
  state.view = view
end

local function hover(ev)
  local view, flat = state.view, state.flat
  if not (view and flat) then return end
  local x = math.floor((ev.x - view.x) * flat.width / view.width)
  local y = math.floor((ev.y - view.y) * flat.height / view.height)
  if state.flip then x = flat.width - 1 - x end
  local inside = x >= 0 and y >= 0 and x < flat.width and y < flat.height
  dlg:modify{ id="info", text=inside and inspect(x, y) or summary() }
end

local function close()
  if timer then timer:stop() end
  if siteListener then app.events:off(siteListener) end
  unwatchSprite()
  pcall(function()
    local b = dlg.bounds
    prefs.bounds = { x=b.x, y=b.y, width=b.width, height=b.height }
  end)
  dlg, timer, siteListener = nil, nil, nil
  state.flat, state.src, state.gray, state.shown = nil, nil, nil, nil
  state.checker, state.view = nil, nil
end

-- Bounds moved and shrunk as needed to fit in the main window
local function fitInWindow(b)
  local ok, rc = pcall(function()
    local w = math.min(b.width, app.window.width)
    local h = math.min(b.height, app.window.height)
    return Rectangle(math.max(0, math.min(b.x, app.window.width - w)),
                     math.max(0, math.min(b.y, app.window.height - h)), w, h)
  end)
  if ok then return rc end
end

local function savedBounds()
  if prefs.bounds then return fitInWindow(prefs.bounds) end
end

-- Hides or shows the Mode and Posterize rows. The window grows or shrinks
-- by the height of those rows, so the preview keeps its size.
local function setCompact(compact)
  state.compact = compact
  prefs.compact = compact
  local before = dlg.sizeHint.height
  dlg:modify{ id="mode", visible=not compact }
  dlg:modify{ id="levels", visible=not compact }
  local b = dlg.bounds
  b.height = b.height + dlg.sizeHint.height - before
  dlg.bounds = fitInWindow(b) or b
end

-- A button that toggles state[key] and shows it as pressed while on
local function toggle(id, text, key)
  dlg:button{
    id=id, text=text, selected=state[key],
    onclick=function()
      state[key] = not state[key]
      dlg:modify{ id=id, selected=state[key] }
      compose()
      dlg:repaint()
    end }
end

local function open()
  state.mode = prefs.mode or V.PERCEPTUAL
  state.levels = prefs.levels or 0
  state.color, state.flip = false, false
  state.compact = prefs.compact or false

  -- autofit=0: changing the info text must not snap the window back to its
  -- default size after the user resizes it
  dlg = Dialog{ title="Value Check", onclose=close, autofit=0 }
  dlg:canvas{ id="view", width=240, height=240, onpaint=paint, onmousemove=hover }
  dlg:newrow()
  toggle("color", "Color", "color")
  toggle("flip", "Flip H", "flip")
  dlg:button{
    id="options", text="...", hexpand=false,
    onclick=function() setCompact(not state.compact) end }
  dlg:newrow()
  dlg:combobox{
    id="mode", label="Mode", visible=not state.compact,
    option=MODES[state.mode], options=MODES,
    onchange=function()
      state.mode = indexOf(MODES, dlg.data.mode) or V.PERCEPTUAL
      prefs.mode = state.mode
      refresh()
    end }
  dlg:newrow()
  dlg:combobox{
    id="levels", label="Posterize", visible=not state.compact,
    option=state.levels >= 2 and tostring(state.levels) or "Off", options=LEVELS,
    onchange=function()
      state.levels = tonumber(dlg.data.levels) or 0
      prefs.levels = state.levels
      refresh()
    end }
  dlg:newrow()
  dlg:label{ id="info", text="" }

  timer = Timer{ interval=0.05, ontick=function() timer:stop(); refresh() end }
  siteListener = app.events:on('sitechange', function()
    local frame = app.frame and app.frame.frameNumber
    if not sameSprite(app.sprite, state.sprite) or frame ~= state.frame then
      schedule()
    end
  end)

  refresh()
  dlg:show{ wait=false, bounds=savedBounds() }
end

function init(plugin)
  prefs = plugin.preferences
  V = dofile(app.fs.joinPath(plugin.path, "values.lua"))

  plugin:newCommand{
    id="ValueCheck",
    title="Value Check",
    group="view_canvas_helpers",
    onclick=function()
      if dlg then dlg:close() else open() end
    end,
    onchecked=function() return dlg ~= nil end,
  }

  -- Open on startup, once the main window is ready
  if app.isUIAvailable then
    local startup
    startup = Timer{ interval=0.1, ontick=function()
      startup:stop()
      if not dlg then open() end
    end }
    startup:start()
  end
end

function exit(plugin)
  if dlg then dlg:close() end
end
