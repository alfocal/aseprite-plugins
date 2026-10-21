-- Snapshot files for Timelapse. A .timelapse file is MAGIC followed by one
-- record per snapshot. A record only stores the rectangle that changed since
-- the previous snapshot:
--   canvas width, canvas height, x, y, width, height  (16-bit, little-endian)
--   width * height RGBA pixels (Image.bytes)
-- The first snapshot of each session, and the first one after the canvas
-- changes size, covers the whole canvas.
--
-- Every file access lives in this file: Aseprite asks for permission per
-- script, so the user is only asked about this one.

local S = {}

local MAGIC = "AseTimelapse 1\n"
local HEADER = "<I2I2I2I2I2I2"
local HEADER_SIZE = string.packsize(HEADER)
local BPP = 4  -- RGBA

local function open(path, mode)
  local f, err = io.open(path, mode)
  if not f then error(err, 0) end
  return f
end

-- Index of the first byte that differs in a and b between i and j
-- (inclusive), or nil if that range is the same in both
local function firstDiff(a, b, i, j)
  if a:sub(i, j) == b:sub(i, j) then return nil end
  while i < j do
    local m = (i + j) // 2
    if a:sub(i, m) == b:sub(i, m) then i = m + 1 else j = m end
  end
  return i
end

local function lastDiff(a, b, i, j)
  if a:sub(i, j) == b:sub(i, j) then return nil end
  while i < j do
    local m = (i + j + 1) // 2
    if a:sub(m, j) == b:sub(m, j) then j = m - 1 else i = m end
  end
  return i
end

-- Smallest rectangle holding every pixel that differs between two images of
-- the same size, or nil if they are equal
local function changedRect(a, b)
  local sa, sb = a.bytes, b.bytes
  local first = firstDiff(sa, sb, 1, #sa)
  if not first then return nil end
  local stride, w = a.rowStride, a.width
  local top = (first - 1) // stride
  local bottom = (lastDiff(sa, sb, first, #sa) - 1) // stride
  local left, right = w, -1
  for y = top, bottom do
    local i, j = y * stride + 1, (y + 1) * stride
    -- Only the parts of the row outside [left, right] can widen it
    local f = left > 0 and firstDiff(sa, sb, i, i + left * BPP - 1)
    if f then left = (f - i) // BPP end
    local l = right < w - 1 and lastDiff(sa, sb, i + (right + 1) * BPP, j)
    if l then right = (l - i) // BPP end
    if left == 0 and right == w - 1 then break end
  end
  return Rectangle(left, top, right - left + 1, bottom - top + 1)
end

function S.create(path)
  local f = open(path, "wb")
  f:write(MAGIC)
  f:close()
end

-- Returns { count, width, height, size }: the number of snapshots, the
-- largest canvas and the file size. A crash while writing can leave a
-- partial record at the end; it's cut off so new ones can be appended.
function S.check(path)
  local f = open(path, "rb")
  local size = f:seek("end")
  f:seek("set")
  if f:read(#MAGIC) ~= MAGIC then
    f:close()
    error(path .. " is not a timelapse file", 0)
  end
  local info = { count=0, width=0, height=0, size=size }
  local pos = #MAGIC
  while pos + HEADER_SIZE <= size do
    local cw, ch, _, _, w, h = string.unpack(HEADER, f:read(HEADER_SIZE))
    local nextPos = pos + HEADER_SIZE + w * h * BPP
    if nextPos > size then break end
    f:seek("set", nextPos)
    pos = nextPos
    info.count = info.count + 1
    info.width = math.max(info.width, cw)
    info.height = math.max(info.height, ch)
  end
  if pos < size then
    f:seek("set")
    local data = f:read(pos)
    f:close()
    f = open(path, "wb")
    f:write(data)
    info.size = pos
  end
  f:close()
  return info
end

-- Appends a snapshot. prev is the previous snapshot of this session (nil
-- for the first one). Returns false if nothing changed.
function S.append(path, img, prev)
  local rect, patch = img.bounds, img
  if prev and prev.width == img.width and prev.height == img.height then
    rect = changedRect(prev, img)
    if not rect then return false end
    patch = Image(img, rect)
  end
  local f = open(path, "ab")
  local ok, err = f:write(string.pack(HEADER, img.width, img.height, rect.x, rect.y,
                                      rect.width, rect.height), patch.bytes)
  f:close()
  if not ok then error(err, 0) end
  return true
end

-- Rebuilds the snapshots in order, calling fn(canvas, i) for each one. The
-- same canvas is reused for the next snapshot: copy it to keep it.
function S.replay(path, fn)
  local f = open(path, "rb")
  local data = f:read("a")
  f:close()
  if data:sub(1, #MAGIC) ~= MAGIC then
    error(path .. " is not a timelapse file", 0)
  end
  local pos, i, canvas = #MAGIC + 1, 0, nil
  while pos + HEADER_SIZE - 1 <= #data do
    local cw, ch, x, y, w, h, start = string.unpack(HEADER, data, pos)
    local stop = start + w * h * BPP
    if stop - 1 > #data then break end
    if not canvas or canvas.width ~= cw or canvas.height ~= ch then
      canvas = Image(cw, ch, ColorMode.RGB)
    end
    local patch = Image(w, h, ColorMode.RGB)
    patch.bytes = data:sub(start, stop - 1)
    canvas:drawImage(patch, Point(x, y), 255, BlendMode.SRC)
    i = i + 1
    fn(canvas, i)
    pos = stop
  end
end

function S.copy(from, to)
  local f = open(from, "rb")
  local data = f:read("a")
  f:close()
  f = open(to, "wb")
  local ok, err = f:write(data)
  f:close()
  if not ok then error(err, 0) end
end

function S.remove(path)
  local ok, err = os.remove(path)
  if not ok then error(err, 0) end
end

return S
