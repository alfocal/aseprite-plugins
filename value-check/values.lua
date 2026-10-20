-- Color math for Value Check. Values are numbers in [0, 1]:
--   PERCEPTUAL: CIE L*, the perceived lightness (what artists call "value")
--   LUMA: Rec. 601 luma, what most "desaturate" filters do

local V = {}

V.PERCEPTUAL = 1
V.LUMA = 2

-- sRGB channel (0-255) -> linear light
local LINEAR = {}
for i = 0, 255 do
  local c = i / 255
  LINEAR[i] = c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end

local function toSrgb(y)
  return y <= 0.0031308 and y * 12.92 or 1.055 * y ^ (1 / 2.4) - 0.055
end

-- Relative luminance Y <-> L* (both in [0, 1])
local function lightness(y)
  return (y <= 216 / 24389 and y * 24389 / 27 or 116 * y ^ (1 / 3) - 16) / 100
end

local function luminance(l)
  l = l * 100
  return l <= 8 and l * 27 / 24389 or ((l + 16) / 116) ^ 3
end

function V.value(mode, r, g, b)
  if mode == V.PERCEPTUAL then
    return lightness(0.2126 * LINEAR[r] + 0.7152 * LINEAR[g] + 0.0722 * LINEAR[b])
  end
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

-- 0-based band of value v when posterized into `levels` bands
function V.band(v, levels)
  return math.min(levels - 1, math.floor(v * levels))
end

-- Gray level (0-255) that displays value v (posterized when levels >= 2)
function V.gray(mode, v, levels)
  if levels >= 2 then
    v = V.band(v, levels) / (levels - 1)
  end
  if mode == V.PERCEPTUAL then
    v = toSrgb(luminance(v))
  end
  return math.floor(v * 255 + 0.5)
end

-- Returns a grayscale copy of an RGB image plus the min/max values of its
-- visible pixels (nil when the image is fully transparent).
function V.grayscale(src, mode, levels)
  local img = Image(src)
  local cache, lo, hi = {}, nil, nil
  for it in img:pixels() do
    local c = it()
    local a = c >> 24
    if a == 0 then
      it(0)
    else
      local rgb = c & 0xffffff
      local g = cache[rgb]
      if not g then
        local v = V.value(mode, rgb & 0xff, (rgb >> 8) & 0xff, rgb >> 16)
        if not lo or v < lo then lo = v end
        if not hi or v > hi then hi = v end
        g = V.gray(mode, v, levels)
        g = (g << 16) | (g << 8) | g
        cache[rgb] = g
      end
      it((a << 24) | g)
    end
  end
  return img, lo, hi
end

return V
