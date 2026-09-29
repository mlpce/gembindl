local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")
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

-- v_bar
vdi:v_bar(svwk_h, 10, 20, x_max - 10, 35)

-- v_arc
vdi:v_arc(svwk_h, 10, 55, 10, 450, 2700)

-- v_pieslice
vdi:v_pieslice(svwk_h, 60, 55, 10, 450, 2700)

-- v_circle
vdi:v_circle(svwk_h, 110, 55, 10)

-- v_ellipse
vdi:v_ellipse(svwk_h, 160, 55, 5, 10)

-- v_ellarc
vdi:v_ellarc(svwk_h, 210, 55, 5, 10, 450, 2700)

-- v_ellpie
vdi:v_ellpie(svwk_h, 260, 55, 5, 10, 450, 2700)

-- v_rbox
vdi:v_rbox(svwk_h, 10, 75, x_max - 10, 90)

-- v_rfbox
vdi:v_rfbox(svwk_h, 10, 125, x_max - 10, 140)

-- v_justified. See text.lua for more.
vdi:v_justified(svwk_h, 0, 165, "This is justified between words", x_max,
  vdidefs.just_justify, vdidefs.just_nojustify)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
