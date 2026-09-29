local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")
local MFDB = require("gembindl.utility.mfdb")
local vdidefs = require("gembindl.utility.defs.vdidefs")

-- Create parameter block and aes/vdi tables
local pb = gempb.create_pb()
local aes = AES:new(pb)
local vdi = VDI:new(pb)

-- Check that gdos is present
assert(gempb.utility.vq_gdos() ~= 0)

-- appl_init
local ap_id = aes:appl_init()
-- Open virtual workstation for screen
local gh, wcel, hcel, wbox, hbox = aes:graf_handle()
gemdos.Cconws("hcel: " .. hcel .. "\r\n")

local svwk_h, workout = vdi:v_opnvwk(gh,
  { gempb.utility.scr_devid(), 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 })
assert(#workout == 57)

-- Set clip
local x_max, y_max = workout[1], workout[2]
vdi:vs_clip(svwk_h, 1, 0, 0, x_max, y_max)

-- Cursor home
vdi:v_curhome(svwk_h)

-- Clear screen
vdi:v_clrwk(svwk_h)

-- Extended inquire
local extended = vdi:vq_extnd(svwk_h, 1)
-- Number of planes
local planes = extended[5]

-- Dimensions of screen
local x_width, y_width = x_max + 1, y_max + 1
-- Number of bytes used by the screen
local buffer_bytes = x_width * y_width * planes >> 3

-- Create memory form definition blocks for screen and offscreen
local screen_mfdb <close> = MFDB:new()
local offscreen_mfdb <close> = MFDB:new()

-- Allocate memory for offscreen form
gemdos.Cconws("Create offscreen form ST format\r\n")
local ec, offscreen_mem <close> = gemdos.Malloc(buffer_bytes)
assert(ec == buffer_bytes)
-- Set the offscreen memory form definition block to the offscreen memory
offscreen_mfdb:set(offscreen_mem:address(), x_width, y_width, 0, planes)

-- Copy the screen to the offscreen form using vro_cpyfm
gemdos.Cconws("Copy screen to offscreen form\r\n")
local s_only = vdidefs.rocp_s_only
vdi:vro_cpyfm(svwk_h, s_only,
  {0, 0, x_max, y_max, 0, 0, x_max, y_max},
  screen_mfdb:address(), offscreen_mfdb:address())

-- transform offscreen form to vdi format form using vr_trnfm
local ec, tran_mem <close> = gemdos.Malloc(buffer_bytes)
assert(ec == buffer_bytes)
local transform_to_vdi_mfdb <close> = MFDB:new()
transform_to_vdi_mfdb:set(tran_mem:address(), x_width, y_width, 1, planes)
gemdos.Cconws("transform offscreen to vdi\r\n")
vdi:vr_trnfm(svwk_h, offscreen_mfdb:address(),
  transform_to_vdi_mfdb:address())

if planes > 1 then
  -- Change the VDI format form to have red background
  tran_mem:set(0, 0xff, buffer_bytes // planes)
end

-- transform vdi form to offscreen form using vr_trnfm
gemdos.Cconws("transform vdi to offscreen\r\n")
vdi:vr_trnfm(svwk_h, transform_to_vdi_mfdb:address(),
  offscreen_mfdb:address())

-- Free the memory for the transform form
tran_mem:free()

-- copy from offscreen to onscreen upside down
local pxy = {0, 0, x_max, 0, 0, 0, y_max, 0}
local offscreen_mfdb_addr = offscreen_mfdb:address()
local screen_mfdb_addr = screen_mfdb:address()
for y = 0, y_max do
  pxy[2]=y pxy[4]=y pxy[6]=x_max-y pxy[8]=y_max-y
  vdi:vro_cpyfm(svwk_h, s_only, pxy,
    offscreen_mfdb_addr, screen_mfdb_addr)
end

-- Free the memory for the offscreen form
offscreen_mem:free()

-- Create a single plane form, 16 pixels width and height
local ec, single_plane_mem <close> = gemdos.Malloc(2*16)
local single_plane_mfdb <close> = MFDB:new()
single_plane_mfdb:set(single_plane_mem:address(), 16, 16, 0, 1)
local offset = 0
-- Set it to a 16x16 chequerboard pattern
for line = 0, 7 do
  single_plane_mem:set(offset, 0xAA, 2)
  offset = offset + 2
  single_plane_mem:set(offset, 0x55, 2)
  offset = offset + 2
end

-- Copy the single plane form to screen using vrt_cpyfm
vdi:vrt_cpyfm(svwk_h, vdidefs.swmo_replace,
  {0, 0, 15, 15, 0, 0, 15, 15}, single_plane_mfdb:address(),
  screen_mfdb:address(), 1, 0)
single_plane_mem:free()

-- Get pixel at coordinates 0,0
local regA, penA = vdi:v_get_pixel(svwk_h, 0, 0)
gemdos.Cconws("regA " .. regA .. " penA " .. penA .. "\r\n")
assert(regA == 2 ^ planes - 1)
assert(penA == 1)

-- Get pixel at coordinates 1,0
local regB, penB = vdi:v_get_pixel(svwk_h, 1, 0)
gemdos.Cconws("regB " .. regB .. " penB " .. penB .. "\r\n")
assert(regB == 0)
assert(penB == 0)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
