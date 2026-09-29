local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")
local Path = require("gembindl.utility.disk.path")
local Rsrc = require("gembindl.utility.resource.rsrc")
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

status = aes:graf_mouse(aesdefs.grmo_m_on)
assert(status > 0)

-- Log the ap_id
gemdos.Cconws("ap_id: " .. ap_id .. " aes_ver: " .. aes_ver .. "\r\n")

local status, location = aes:shel_find("lua.prg")
-- gemdos.Cconws("status " .. status .. " location " .. location .. "\r\n" )
assert(status > 0 and Path.fname_from_path(location) == "lua.prg")
status, location = aes:shel_find("notexist.not")
assert(status == 0 and location == "")

local path = aes:shel_envrn("PATH=")
assert(path ~= nil)
gemdos.Cconws("PATH=" .. path .. "\r\n")

local status, command, tail = aes:shel_read()
assert(status > 0)
gemdos.Cconws("command " .. command .. " tail " .. tail .. "\r\n")

status = aes:shel_write_chain(
  aesdefs.shwr_tosapp,
  "LUA.PRG", "-eprint('hello\\x20from\\x20\\x20the\\x20tail')")
assert(status > 0)
gemdos.Cconws("shel_write_chain called, quit program to check\r\n")

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
