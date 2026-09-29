local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")

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

-- Open workstation for metafile
local mwk_h, workout = vdi:v_opnwk({ 31, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 })
local mx_max, my_max = workout[1], workout[2]
gemdos.Cconws("mx_max " .. mx_max .. " my_max " .. my_max .. "\r\n")

-- Change the name of the metafile
vdi:vm_filename(mwk_h, "UNITTEST.GEM")

-- Add bit image to the metafile
vdi:v_bit_image(mwk_h, "UNITTEST.IMG",
  1, 0, 0, 1, 1, { 0, my_max, mx_max, 0 })

-- Close metafile physical workstation
vdi:v_clswk(mwk_h)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
