local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")
local aesdefs = require("gembindl.utility.defs.aesdefs")

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

-- Change to user defined mouse pattern
aes:graf_mouse(aesdefs.grmo_user_def, 8, 1, 0, 1,
  mouse_mask, mouse_data)

local status = aes:graf_mouse(aesdefs.grmo_m_off)
assert(status > 0)

-- Cursor home
vdi:v_curhome(svwk_h)

-- Clear screen
vdi:v_clrwk(svwk_h)

status = aes:graf_mouse(aesdefs.grmo_m_on)
assert(status > 0)

-- get work area of desktop window
local deskx, desky, deskw, deskh
status, deskx, desky, deskw, deskh =
  aes:wind_get(0, aesdefs.wige_workxywh)

-- movebox
status = aes:graf_movebox(
  deskw//4, deskh//4, 3*deskw//4, desky + 3*deskh//4, deskx, desky)
assert(status > 0)

-- growbox
status = aes:graf_growbox(
  deskx, desky, deskw//4, deskh//4, deskx, desky, deskw, deskh)
assert(status > 0)

-- shrinkbox
status = aes:graf_shrinkbox(
  deskx, desky, deskw//4, deskh//4, deskx, desky, deskw, deskh)
assert(status > 0)

-- mkstate
local _, x, y, bs, ss
-- Check for left mouse button press
gemdos.Cconws("Press left button\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until (bs & aesdefs.grmk_left_button) ~= 0
gemdos.Cconws("x: " .. x .. " y: " .. y ..
  " bs: " .. bs .. " ss: " .. ss .. "\r\n")

-- Check for right mouse button press
gemdos.Cconws("Press right button\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until (bs & aesdefs.grmk_right_button) ~= 0
gemdos.Cconws("x: " .. x .. " y: " .. y ..
  " bs: " .. bs .. " ss: " .. ss .. "\r\n")

-- check for both mouse buttons pressed
gemdos.Cconws("Press both buttons\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until bs & (aesdefs.grmk_right_button | aesdefs.grmk_left_button) ==
  (aesdefs.grmk_right_button | aesdefs.grmk_left_button)
gemdos.Cconws("x: " .. x .. " y: " .. y ..
  " bs: " .. bs .. " ss: " .. ss .. "\r\n")

-- Check for right shift on keyboard
gemdos.Cconws("Press right shift\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until ss & aesdefs.grmk_right_shift ~= 0
gemdos.Cconws("x: " .. x .. " y: " .. y ..
  " bs: " .. bs .. " ss: " .. ss .. "\r\n")

-- Check for left shift on keyboard
gemdos.Cconws("Press left shift\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until ss & aesdefs.grmk_left_shift ~= 0
gemdos.Cconws("x: " .. x .. " y: " .. y ..
  " bs: " .. bs .. " ss: " .. ss .. "\r\n")

-- Check for control on keyboard
gemdos.Cconws("Press control\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until ss & aesdefs.grmk_control ~= 0
gemdos.Cconws("x: " .. x .. " y: " .. y ..
  " bs: " .. bs .. " ss: " .. ss .. "\r\n")

-- Check for alt on keyboard
gemdos.Cconws("Press alt\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until ss & aesdefs.grmk_alt ~= 0
gemdos.Cconws("x: " .. x .. " y: " .. y ..
  " bs: " .. bs .. " ss: " .. ss .. "\r\n")

-- Try rubberbox.
gemdos.Cconws("Press left button and drag the rubber box\r\n")
local clicked
clicked, x, y, bs, ss =
  aes:evnt_button(1, aesdefs.evbu_left_button, aesdefs.evbu_left_button)

gemdos.Cconws("Initial x " .. x .. " Initial y " .. y .. "\r\n")
local w, h
status, w, h = aes:graf_rubberbox(x, y, 1, 1)
assert(status > 0)
gemdos.Cconws("Got rubbered w " .. w .. " h " .. h .. "\r\n")

-- Try dragbox
gemdos.Cconws("Press left button and drag the box\r\n")
repeat
  _, x, y, bs, ss = aes:graf_mkstate()
until (bs & aesdefs.grmk_left_button) ~= 0
gemdos.Cconws("Initial x " .. x .. " Initial y " .. y .. "\r\n")

status, x, y = aes:graf_dragbox(32, 32, x, y,
    deskx, desky, deskw, deskh)
assert(status > 0)
gemdos.Cconws("Got dragged x " .. x .. " y " .. y .. "\r\n")

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
