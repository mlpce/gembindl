local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")
local Rsrc = require("gembindl.utility.resource.rsrc")
local Text = require("gembindl.utility.disk.text")
local aesdefs = require("gembindl.utility.defs.aesdefs")

-- Create parameter block and aes/vdi tables
local pb = gempb.create_pb()
local aes = AES:new(pb)
local vdi = VDI:new(pb)
local rsrc = Rsrc:new(pb)

-- Check that gdos is present
assert(gempb.utility.vq_gdos() ~= 0)

-- Load cdefs for resource
local ec, cdefs = Text.load_cdefs("AES\\UNITTEST.H")
assert(ec >= 0)
assert(cdefs.mu1)

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

status = aes:rsrc_load("AES\\UNITTEST.RSC")
assert(status > 0)
gemdos.Cconws("rsrc_load: " .. status .. "\r\n")

-- Wrap the resource
rsrc:wrap()

-- Address of the resource
local rsrc_addr = rsrc:address()
-- Size of the resource
local rsrc_size = rsrc:size()

-- Header table
local rsrc_hdr = rsrc:header()
assert(rsrc_hdr.vrsn == 1)

-- Get address of mu1 tree
local mu1_addr
status, mu1_addr = aes:rsrc_gaddr(aesdefs.rsga_tree, cdefs.mu1)
assert(status > 0)

-- Check address using tree_addr matches 
local mu1_tree_addr = rsrc:tree_addr(cdefs.mu1)
assert(mu1_tree_addr == mu1_addr)

local status = aes:menu_bar(mu1_tree_addr, aesdefs.meba_show)
assert(status > 0)

-- Reverse video the title
status = aes:menu_tnormal(mu1_tree_addr, cdefs.mu1_file, aesdefs.metn_reverse)
assert(status > 0)

-- Check the item
status = aes:menu_icheck(mu1_tree_addr, cdefs.mu1_checked, aesdefs.meic_check)
assert(status > 0)

-- Check state mu1_checked
local mu1_checked_offset = rsrc:tree_obj_offset(cdefs.mu1, cdefs.mu1_checked)
local mu1_checked_state = rsrc:obj_peek_state(mu1_checked_offset)
assert(mu1_checked_state == aesdefs.obch_checked)

-- Disable the item
status =
  aes:menu_ienable(mu1_tree_addr, cdefs.mu1_disabled, aesdefs.meie_disable)
assert(status > 0)

-- Check state mu1_disabled
local mu1_disabled_offset =
  rsrc:tree_obj_offset(cdefs.mu1, cdefs.mu1_disabled)
local mu1_disabled_state = rsrc:obj_peek_state(mu1_disabled_offset)
assert(mu1_disabled_state == aesdefs.obch_disabled)

-- Get original string of mu1_text
local mu1_text_offset = rsrc:tree_obj_offset(cdefs.mu1, cdefs.mu1_text)
local mu1_text_spec = rsrc:obj_peek_spec(mu1_text_offset)
local mu1_text_string = rsrc:reads(mu1_text_spec - rsrc:address(), nil, 0)
assert(mu1_text_string == "  Text ")

-- Change string of mu1_text
status = aes:menu_text(mu1_tree_addr, cdefs.mu1_text, "  1234 ")
assert(status > 0)
mu1_text_string = rsrc:reads(mu1_text_spec - rsrc:address(), nil, 0)
assert(mu1_text_string == "  1234 ")

-- Normal video the title
status = aes:menu_tnormal(mu1_tree_addr, cdefs.mu1_file, aesdefs.metn_normal)
assert(status > 0)

repeat
  local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_mesag,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  local mesag_msg_id, mesag_ap_id, mesag_extra_bytes,
    mesag_1, mesag_2, mesag_3, mesag_4, mesag_5
  if happened & aesdefs.evmu_mesag ~= 0 then
    mesag_msg_id, mesag_ap_id, mesag_extra_bytes,
    mesag_1, mesag_2, mesag_3, mesag_4, mesag_5 = aes:mesag_v()
  end
until mesag_msg_id == aesdefs.evme_mn_selected
  and mesag_1 == cdefs.mu1_file and mesag_2 == cdefs.mu1_quit

-- Change string of mu1_text back
status = aes:menu_text(mu1_tree_addr, cdefs.mu1_text, "  Text ")
assert(status > 0)
mu1_text_string = rsrc:reads(mu1_text_spec - rsrc:address(), nil, 0)
assert(mu1_text_string == "  Text ")

-- Enable the item
status =
  aes:menu_ienable(mu1_tree_addr, cdefs.mu1_disabled, aesdefs.meie_enable)
assert(status > 0)

-- Uncheck the item
status =
  aes:menu_icheck(mu1_tree_addr, cdefs.mu1_checked, aesdefs.meic_uncheck)
assert(status > 0)

-- Normal video the title
status = aes:menu_tnormal(mu1_tree_addr, cdefs.mu1_file, aesdefs.metn_normal)
assert(status > 0)

-- Normal video the title
status = aes:menu_tnormal(mu1_tree_addr, cdefs.mu1_file, aesdefs.metn_normal)
assert(status > 0)

status = aes:menu_bar(mu1_tree_addr, aesdefs.meba_erase)
assert(status > 0)

-- Unwrap the resource
rsrc:unwrap()

-- Free the resource
status = aes:rsrc_free()
assert(status > 0)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
