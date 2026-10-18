global assert, ipairs, require, table, gemdos

local <const> MFDB = require("gembindl.utility.mfdb")
local <const> k_u16 = gemdos.const.Imode.u16

gemdos.Cconws("Checking mfdb\r\n")

-- Create a memory form definition block
local <const> mfdb = MFDB:new()

-- MFDB memory must have a non-zero address
assert(mfdb:address() ~= 0)

-- MFDB must be initialised to zeros
local values = table.pack(mfdb:get())
assert(#values == 5)
for k,v in ipairs(values) do
  assert(v == 0)
end

-- Set up mfdb with values
local <const> mud_ec, form_mud = gemdos.utility.allocm(32000)
assert(mud_ec == 32000)
mfdb:set(form_mud:address(), 640, 400, 1, 1)

-- Read back the values
local addr, form_width, form_height, format, planes = mfdb:get()
assert(addr == form_mud:address())
assert(form_width == 640)
assert(form_height == 400)
assert(format == 1)
assert(planes == 1)

-- Wrap the mud to inspect the MFDB values
local <const> mfdb_wrap_mud = gemdos.utility.wrapm(mfdb:address(), 20)
-- Read the MFDB values into a table
local <const> vt1 = mfdb_wrap_mud:readt(k_u16, 0, 10)
-- Check the values
assert(vt1[1] == form_mud:address() >> 16)
assert(vt1[2] == form_mud:address() & 0xFFFF)
assert(vt1[3] == 640)
assert(vt1[4] == 400)
assert(vt1[5] == 40)
assert(vt1[6] == 1)
assert(vt1[7] == 1)
assert(vt1[8] == 0)
assert(vt1[9] == 0)
assert(vt1[10] == 0)

-- Set up the mfdb with different values
mfdb:set(form_mud:address(), 320, 200, 0, 4)

-- Read back the values
addr, form_width, form_height, format, planes = mfdb:get()
assert(addr == form_mud:address())
assert(form_width == 320)
assert(form_height == 200)
assert(format == 0)
assert(planes == 4)

-- Read the MFDB values into a table
local <const> vt2 = mfdb_wrap_mud:readt(k_u16, 0, 10)
-- Check the values
assert(vt2[1] == form_mud:address() >> 16)
assert(vt2[2] == form_mud:address() & 0xFFFF)
assert(vt2[3] == 320)
assert(vt2[4] == 200)
assert(vt2[5] == 20)
assert(vt2[6] == 0)
assert(vt2[7] == 4)
assert(vt2[8] == 0)
assert(vt2[9] == 0)
assert(vt2[10] == 0)

-- Unwrap the wrapping mud
mfdb_wrap_mud:free()

-- Check the MFDB is closable
do
  local <close> mfdb_close = mfdb
end

-- MFDB address must now be zero
assert(mfdb:address() == 0)

gemdos.Cconws("Checked mfdb\r\n")
