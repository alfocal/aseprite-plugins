-- Isometric grid pattern for Iso Guides. Lines step 2 px across for every
-- 1 px down (the 2:1 pixel-art line), so tiles are W x W/2 diamonds whose
-- corners are 2 px wide flats.

local G = {}

-- Tile sizes offered in the dialog. Widths are multiples of 4 so that both
-- line families meet on whole pixels at every corner.
G.TILES = { "8x4", "16x8", "24x12", "32x16", "48x24", "64x32", "96x48", "128x64" }

function G.tileWidth(name)
  return tonumber(name:match("^(%d+)x"))
end

-- Draws the grid into img. (ox, oy) is the left pixel of the top corner of
-- one tile. Verticals go through every corner and are dotted so they read
-- lighter than the tile edges.
function G.draw(img, tileW, ox, oy, verticals, color)
  local th = tileW // 2
  local w, h = img.width, img.height
  for x = 0, w - 1 do
    local dx = x - ox
    local step = dx // 2
    for y = (oy + step) % th, h - 1, th do img:drawPixel(x, y, color) end
    for y = (oy - step) % th, h - 1, th do img:drawPixel(x, y, color) end
    if verticals and dx % th == 0 then
      for y = oy % 2, h - 1, 2 do img:drawPixel(x, y, color) end
    end
  end
end

return G
