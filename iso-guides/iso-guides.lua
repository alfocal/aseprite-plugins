-- Iso Guides: an isometric (2:1) grid to draw over. The grid lives in a
-- locked reference layer: Aseprite shows it in the editor but leaves it out
-- of exports and previews, so it never ends up in your art.

local G      -- grid pattern (grid.lua), loaded in init()
local prefs  -- plugin.preferences, kept between sessions

local KEY = "iso-guides"  -- layer properties key that marks our guide layer
local DEFAULTS = { tile="32x16", r=0, g=170, b=255, opacity=128, verticals=false }

local dlg, timer, redrawTimer, siteListener
local state = { listeners = {} }

-- Comparing against a closed sprite can raise an error
local function sameSprite(a, b)
  local ok, eq = pcall(function() return a == b end)
  return ok and eq
end

local function later(fn)
  local t
  t = Timer{ interval=0.01, ontick=function() t:stop(); fn() end }
  t:start()
end

local function schedule()
  if timer and not timer.isRunning then timer:start() end
end

local function findGuide(layers)
  for _, layer in ipairs(layers) do
    if layer.isGroup then
      local found = findGuide(layer.layers)
      if found then return found end
    elseif layer.isReference and layer.properties(KEY).tile then
      return layer
    end
  end
end

local function activeGuide()
  local spr = app.sprite
  return spr and findGuide(spr.layers)
end

-- Puts the top corner of a tile in the middle of the canvas
local function centerOf(spr)
  return (spr.width - 2) // 2, spr.height // 2
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
  local ok, id = pcall(function() return spr.events:on("change", schedule) end)
  if ok then table.insert(state.listeners, id) end
end

local function savePrefs()
  local d = dlg.data
  prefs.tile, prefs.verticals, prefs.opacity = d.tile, d.verticals, d.opacity
  prefs.r, prefs.g, prefs.b = d.color.red, d.color.green, d.color.blue
end

-- Shows the settings of the active sprite's guide (if it has one) and
-- enables the buttons that apply to it
local function sync()
  if not dlg then return end
  local spr = app.sprite
  local guide = spr and findGuide(spr.layers)
  local info = "No sprite open"
  if guide then
    local o = guide.properties(KEY)
    -- A pending redraw means the dialog holds edits the guide doesn't have
    -- yet. modify fires the widgets' onchange: don't redraw while loading.
    if not redrawTimer.isRunning then
      state.loading = true
      dlg:modify{ id="tile", option=o.tile }
      dlg:modify{ id="color", color=Color{ r=o.r, g=o.g, b=o.b } }
      dlg:modify{ id="verticals", selected=o.verticals }
      dlg:modify{ id="opacity", value=guide.opacity }
      state.loading = false
    end
    info = string.format("Origin x%d y%d", o.x, o.y)
  elseif spr then
    info = "No guide in this sprite"
  end
  dlg:modify{ id="info", text=info }
  dlg:modify{ id="draw", text=guide and "Redraw" or "Add guide", enabled=spr ~= nil }
  dlg:modify{ id="pick", enabled=spr ~= nil }
  dlg:modify{ id="center", enabled=spr ~= nil }
  dlg:modify{ id="show", enabled=guide ~= nil }
  dlg:modify{ id="remove", enabled=guide ~= nil }
end

-- Draws the guide of the active sprite with the dialog settings, adding the
-- layer if needed. x, y move the grid origin; nil keeps the current one.
local function place(x, y)
  local spr = app.sprite
  if not spr then return end
  redrawTimer:stop()  -- this applies any pending edits too
  local guide = findGuide(spr.layers)
  if not (x and y) then
    if guide then
      local o = guide.properties(KEY)
      x, y = o.x, o.y
    else
      x, y = centerOf(spr)
    end
  end
  local d = dlg.data
  local o = { tile=d.tile, r=d.color.red, g=d.color.green, b=d.color.blue,
              verticals=d.verticals, x=x, y=y }

  app.transaction("Iso Guide", function()
    if not guide then
      local active = app.layer
      app.command.NewLayer{ name="Iso Guide", reference=true }
      guide = app.layer
      -- Never draw on one of the user's layers (the error rolls back)
      assert(guide and guide.isReference and not guide.properties(KEY).tile,
             "Iso Guides: couldn't create the guide layer")
      guide.parent = spr  -- reference layers are added at the bottom
      guide.isEditable = false
      guide.opacity = d.opacity
      if active then app.layer = active end
    end
    local img = Image(spr.spec)
    G.draw(img, G.tileWidth(o.tile), o.x, o.y, o.verticals,
           Color{ r=o.r, g=o.g, b=o.b })
    for _, frame in ipairs(spr.frames) do
      spr:newCel(guide, frame, img, Point(0, 0))
    end
    guide.properties(KEY, o)
  end)
  -- Script changes only repaint parts of the editor; repaint all of it
  app.refresh()
  sync()
end

local function changed()
  if state.loading then return end
  savePrefs()
  -- Wait for a pause so dragging in the color picker is a single undo step
  state.changedSprite = app.sprite
  redrawTimer:stop()
  redrawTimer:start()
end

local function setOpacity()
  savePrefs()
  local guide = activeGuide()
  if guide then
    app.transaction("Iso Guide Opacity", function()
      guide.opacity = dlg.data.opacity
    end)
    app.refresh()
  end
end

local function pick()
  local spr, editor = app.sprite, app.editor
  if not (spr and editor) then return end
  local guide = findGuide(spr.layers)
  local o = guide and guide.properties(KEY)
  editor:askPoint{
    title="Iso Guides: click where a tile corner should go",
    point=o and Point(o.x, o.y),
    decorate={ rulers=true },
    onclick=function(ev)
      local x, y = ev.point.x, ev.point.y
      -- Edit the sprite once the editor is back to its normal state
      later(function()
        if dlg and sameSprite(app.sprite, spr) then place(x, y) end
      end)
    end }
end

-- Hiding a layer outside a transaction doesn't add an undo step
local function toggleVisible()
  local guide = activeGuide()
  if guide then
    guide.isVisible = not guide.isVisible
    app.refresh()
  end
end

local function remove()
  local spr, guide = app.sprite, activeGuide()
  if guide then
    app.transaction("Remove Iso Guide", function() spr:deleteLayer(guide) end)
    app.refresh()
  end
  sync()
end

local function close()
  if timer then timer:stop() end
  if redrawTimer then redrawTimer:stop() end
  if siteListener then app.events:off(siteListener) end
  unwatchSprite()
  dlg, timer, redrawTimer, siteListener = nil, nil, nil, nil
  state.changedSprite = nil
end

local function open()
  local p = {}
  for k, v in pairs(DEFAULTS) do
    if prefs[k] == nil then p[k] = v else p[k] = prefs[k] end
  end

  dlg = Dialog{ title="Iso Guides", onclose=close }
  dlg:combobox{ id="tile", label="Tile", option=p.tile, options=G.TILES, onchange=changed }
  dlg:color{ id="color", label="Color", color=Color{ r=p.r, g=p.g, b=p.b }, onchange=changed }
  dlg:slider{ id="opacity", label="Opacity", min=0, max=255, value=p.opacity,
              onrelease=setOpacity }
  dlg:check{ id="verticals", text="Vertical lines", selected=p.verticals, onclick=changed }
  dlg:button{ id="pick", label="Origin", text="Pick...", onclick=pick }
  dlg:button{ id="center", text="Center", onclick=function()
    if app.sprite then place(centerOf(app.sprite)) end
  end }
  dlg:newrow()
  dlg:label{ id="info", text="" }
  dlg:separator()
  dlg:button{ id="draw", text="Add guide", onclick=function() place() end }
  dlg:button{ id="show", text="Show/Hide", onclick=toggleVisible }
  dlg:button{ id="remove", text="Remove", onclick=remove }

  -- Picks up undo/redo and guides removed from the timeline
  timer = Timer{ interval=0.05, ontick=function() timer:stop(); sync() end }
  redrawTimer = Timer{ interval=0.25, ontick=function()
    redrawTimer:stop()
    if sameSprite(app.sprite, state.changedSprite) and activeGuide() then place() end
  end }
  siteListener = app.events:on('sitechange', function()
    if not sameSprite(app.sprite, state.sprite) then
      watchSprite(app.sprite)
      sync()
    end
  end)

  watchSprite(app.sprite)
  sync()
  dlg:show{ wait=false }
end

function init(plugin)
  prefs = plugin.preferences
  G = dofile(app.fs.joinPath(plugin.path, "grid.lua"))

  plugin:newCommand{
    id="IsoGuides",
    title="Iso Guides",
    group="view_canvas_helpers",
    onclick=function()
      if dlg then dlg:close() else open() end
    end,
    onchecked=function() return dlg ~= nil end,
  }

  plugin:newCommand{
    id="ToggleIsoGuide",
    title="Show/Hide Iso Guide",
    group="view_canvas_helpers",
    onclick=toggleVisible,
    onenabled=function() return activeGuide() ~= nil end,
  }
end

function exit(plugin)
  if dlg then dlg:close() end
end
