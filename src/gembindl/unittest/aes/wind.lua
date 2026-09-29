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

-- Create a window
local controls = aesdefs.wicr_name |
  aesdefs.wicr_closer | aesdefs.wicr_fuller | aesdefs.wicr_mover |
  aesdefs.wicr_info | aesdefs.wicr_sizer | aesdefs.wicr_uparrow |
  aesdefs.wicr_dnarrow | aesdefs.wicr_vslide | aesdefs.wicr_lfarrow |
  aesdefs.wicr_rtarrow | aesdefs.wicr_hslide
local wi_handle = aes:wind_create(controls, deskx, desky, deskw, deskh)
assert(wi_handle > 0)

local ec, mud = gemdos.Malloc(256)
assert(ec == 256)
local otitle = 0
local oinfo = 16
mud:writes(otitle, "Test window\0")
mud:writes(oinfo, "test info\0")
local atitle = mud:address() + otitle
local ainfo = mud:address() + oinfo
status = aes:wind_set(wi_handle, aesdefs.wise_name,
  atitle >> 16, atitle & 0xFFFF, 0, 0)
assert(status > 0)
status = aes:wind_set(wi_handle, aesdefs.wise_info,
  ainfo >> 16, ainfo & 0xFFFF, 0, 0)
assert(status > 0)
status = aes:wind_open(wi_handle, deskx, desky, deskw, deskh)
assert(status > 0)

local wi_find_handle = aes:wind_find(deskx, desky)
assert(wi_find_handle == wi_handle)

local workx, worky, workw, workh
status, workx, worky, workw, workh =
  aes:wind_calc(aesdefs.wica_work, controls, deskx, desky, deskw, deskh)

status = aes:graf_mouse(aesdefs.grmo_m_off)
assert(status > 0)

status = aes:wind_update(aesdefs.wiup_beg_update)
assert(status > 0)

-- v_rfbox
vdi:v_rfbox(svwk_h, workx, worky, workx + workw, worky + workh)

status = aes:wind_update(aesdefs.wiup_end_update)
assert(status > 0)

status = aes:graf_mouse(aesdefs.grmo_m_on)
assert(status > 0)

status = aes:wind_close(wi_handle)
assert(status > 0)

status = aes:wind_delete(wi_handle)
assert(status > 0)

mud:free()

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
