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
local ap_id, aes_ver = aes:appl_init()

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

-- Log the ap_id
gemdos.Cconws("ap_id: " .. ap_id .. " aes_ver: " .. aes_ver .. "\r\n")

status = aes:graf_mouse(aesdefs.grmo_m_on)
assert(status > 0)

local exitbutn, path, file
status, exitbutn, path, file = aes:fsel_input("C:\\*.*", "UNTITLED.DOC")
gemdos.Cconws("status " .. status .. " exitbutn " .. exitbutn ..
  " path " .. path .. " file " .. file .. "\r\n")

if aes_ver >= 320 then
  status, exitbutn, path, file =
    aes:fsel_exinput("C:\\*.*", "UNTITLED.DOC", "Test fsel_exinput")
  gemdos.Cconws("status " .. status .. " exitbutn " .. exitbutn ..
    " path " .. path .. " file " .. file .. "\r\n")
end

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
