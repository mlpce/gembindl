global assert, pairs, setmetatable, gemdos, tosbindl

local <const> k_u16 = gemdos.const.Imode.u16

local <const> MFDB = {}

-- Mapping of error code to string
local ec_str <const> = {}
for k,v in pairs(gemdos.const.Error) do
  ec_str[v] = k
end

-- Create a new MFDB
function MFDB:new(o)
  o = o or {}
  local <const> buffer_size = 20
  local ec, mud = gemdos.utility.allocm(buffer_size)
  assert(ec == buffer_size, ec_str[ec])
  mud:set(0, 0)
  o.mfdb_mud_ = mud
  o.mfdb_addr_ = mud:address()

  self.__index = self
  self.__close = function (v) v.mfdb_mud_:free() end
  return setmetatable(o, self )
end

-- address. Gets address of memory form definition block
-- Returns:
--   1) integer: address of MFDB
function MFDB:address()
  return self.mfdb_addr_
end

-- Set the MFDB values
-- Inputs:
--   1) integer: memory address (zero for current screen)
--   2) optional integer: form width in pixels (default zero)
--   3) optional integer: form height in pixels (default zero)
--   4) optional integer: format 0=dev 1=vdi (default zero)
--   5) optional integer: planes (default zero)
function MFDB:set(addr, width, height, format, planes)
  width = width or 0
  height = height or 0
  format = format or 0
  planes = planes or 0
  assert(format == 0 or format == 1)

  local <const> mud = self.mfdb_mud_
  mud:poke(k_u16, 0, (addr >> 16) & 0xFFFF, addr & 0xFFFF,
    width, height, (width + 15) >> 4, format, planes, 0, 0, 0)
end

-- Get the MFDB values
-- Returns:
--   1) integer: memory address
--   2) integer: form width in pixels
--   3) integer: form height in pixels
--   4) integer: format 0=dev 1=vdi
--   5) integer: planes
function MFDB:get()
  local <const> mud = self.mfdb_mud_
  local <const> addr_hi, addr_lo, width, height,
    word_width, format, planes = mud:peek(k_u16, 0, 7)
  return (addr_hi & 0xFFFF) << 16 | (addr_lo & 0xFFFF),
    width, height, format, planes
end

return MFDB
