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

-- Open virtual workstation
local vwk_h, workout = vdi:v_opnvwk((aes:graf_handle()))
-- Get screen dimensions
local x_max, y_max = workout[1], workout[2]

-- Inquire tablet status
local tab_status = vdi:vq_tabstatus(vwk_h)
assert(tab_status == 1)
gemdos.Cconws("vq_tabstatus: " .. tab_status .. "\r\n")

-- Coordinates are ignored by ST
gemdos.Cconws("Flicker (v_rmcur/v_dspcur) ")
for k=1,1000 do
  vdi:v_rmcur(vwk_h)
  vdi:v_dspcur(vwk_h, 0, 0)
end
gemdos.Cconws("Done\r\n")

-- Turn the mouse cursor off and on using v_hide_c / v_show_c
gemdos.Cconws("Flicker (v_hide_c/v_show_c) 1 ")
for k=1,1000 do
  vdi:v_hide_c(vwk_h)
  vdi:v_show_c(vwk_h, 1)
end
gemdos.Cconws("Done\r\n")

-- Turn the mouse cursor off and on using v_hide_c / v_show_c (force)
gemdos.Cconws("Flicker (v_hide_c/v_show_c) 2 ")
for k=1,250 do
  vdi:v_hide_c(vwk_h)
  vdi:v_hide_c(vwk_h)
  vdi:v_hide_c(vwk_h)
  vdi:v_show_c(vwk_h, 0)
end
gemdos.Cconws("Done\r\n")

-- Check for left mouse button press
gemdos.Cconws("Press left button\r\n")
local buttons, x, y
repeat
  buttons, x, y = vdi:vq_mouse(vwk_h)
until buttons == 1
gemdos.Cconws("x: " .. x .. " y: " .. y .. "\r\n")

-- Check for right mouse button press
gemdos.Cconws("Press right button\r\n")
repeat
  buttons, x, y = vdi:vq_mouse(vwk_h)
until buttons == 2
gemdos.Cconws("x: " .. x .. " y: " .. y .. "\r\n")

-- Test vsc_form to change the mouse form
local mouse_data = {
    0x0000,
    0x05A0,
    0x05A0,
    0x05A0,
    0x05A0,
    0x0DB0,
    0x0DB0,
    0x1DB8,
    0x399C,
    0x799E,
    0x718E,
    0x718E,
    0x6186,
    0x4182,
    0x0000,
    0x0000,
  }

local mouse_mask = {
    0x07E0,
    0x0FF0,
    0x0FF0,
    0x0FF0,
    0x0FF0,
    0x1FF8,
    0x1FF8,
    0x3FFC,
    0x7FFE,
    0xFFFF,
    0xFBDF,
    0xFBDF,
    0xF3CF,
    0xE3C7,
    0x4182,
    0x0000
  }

-- Hide the mouse cursor
vdi:v_hide_c(vwk_h)
--- Change the mouse form
vdi:vsc_form(vwk_h, 8, 1, 0, 1, mouse_mask, mouse_data)
-- Show the mouse cursor
vdi:v_show_c(vwk_h, 1)

-- Close virtual workstation
vdi:v_clsvwk(vwk_h)

-- appl_exit
aes:appl_exit()
