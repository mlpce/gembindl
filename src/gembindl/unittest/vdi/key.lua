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

-- Check vq_key_s
gemdos.Cconws("Press right shift\r\n")
repeat until vdi:vq_key_s(svwk_h) & 1 == 1
gemdos.Cconws("Press left shift\r\n")
repeat until vdi:vq_key_s(svwk_h) & 2 == 2
gemdos.Cconws("Press control\r\n")
repeat until vdi:vq_key_s(svwk_h) & 4 == 4
gemdos.Cconws("Press alternate\r\n")
repeat until vdi:vq_key_s(svwk_h) & 8 == 8

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
