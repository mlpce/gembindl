local RCache = require("gembindl.utility.rcache")
RCache.set_keep(true)

local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")
local Rsrc = require("gembindl.utility.resource.rsrc")
local FormEvnt = require("gembindl.utility.resource.formevnt")
local Structs = require("gembindl.utility.resource.structs")
local aesdefs = RCache.require("gembindl.utility.defs.aesdefs")

-- Set up definition constants
-- graf_mouse constants
local <const> k_grmo_m_off = aesdefs.grmo_m_off
local <const> k_grmo_m_on = aesdefs.grmo_m_on
-- rsrc_gaddr constants
local <const> k_rsga_tree = aesdefs.rsga_tree
local <const> k_rsga_frstr = aesdefs.rsga_frstr
local <const> k_rsga_frimg = aesdefs.rsga_frimg
-- objc_type constants
local <const> k_obty_boxtext = aesdefs.obty_boxtext
local <const> k_obty_button = aesdefs.obty_button
local <const> k_obty_icon = aesdefs.obty_icon
local <const> k_obty_image = aesdefs.obty_image
-- objc_flags constants
local <const> k_obfl_selectable = aesdefs.obfl_selectable
local <const> k_obfl_default = aesdefs.obfl_default
local <const> k_obfl_exit = aesdefs.obfl_exit
local <const> k_obfl_touchexit = aesdefs.obfl_touchexit
-- objc_draw constants
local <const> k_obdr_root = aesdefs.obdr_root
local <const> k_obdr_max_depth = aesdefs.obdr_max_depth
-- objc_change constants
local <const> k_obch_normal = aesdefs.obch_normal
local <const> k_obch_no_redraw = aesdefs.obch_no_redraw
local <const> k_obch_selected = aesdefs.obch_selected
local <const> k_obch_redraw = aesdefs.obch_redraw
-- evnt_button constants
local <const> k_evbu_left_button = aesdefs.evbu_left_button
-- evnt_multi constants
local <const> k_evmu_button = aesdefs.evmu_button
local <const> k_evmu_keybd = aesdefs.evmu_keybd
aesdefs = nil

-- Create parameter block and aes/vdi tables
local pb = gempb.create_pb()
local aes = AES:new(pb)
local vdi = VDI:new(pb)
local rsrc = Rsrc:new(pb)
local structs = Structs:new(rsrc) 
local <const> s16 = gemdos.const.Imode.s16
local <const> s32 = gemdos.const.Imode.s32

-- Check that gdos is present
assert(gempb.utility.vq_gdos() ~= 0)

-- Load cdefs for resource
local ec, cdefs =
  RCache.require("gembindl.utility.disk.text").load_cdefs("AES\\UNITTEST.H")
assert(ec >= 0)
assert(cdefs.fm1 == 0)

local cached, reqs_hit, reqs_miss = RCache.stats()
RCache.set_keep(false)

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

local status = aes:graf_mouse(k_grmo_m_off)
assert(status > 0)

-- Cursor home
vdi:v_curhome(svwk_h)

-- Clear screen
vdi:v_clrwk(svwk_h)

status = aes:graf_mouse(k_grmo_m_on)
assert(status > 0)

-- Log the ap_id
gemdos.Cconws("ap_id: " .. ap_id .. " aes_ver: " .. aes_ver .. "\r\n")
gemdos.Cconws("cached: " .. cached .. " reqs_hit " .. reqs_hit ..
  " reqs_miss " .. reqs_miss .. "\r\n")

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

-- Get address of fm1 tree
local fm1_addr

status, fm1_addr = aes:rsrc_gaddr(k_rsga_tree, cdefs.fm1)
assert(status > 0)

-- Check address using tree_addr matches 
local fm1_tree_addr = rsrc:tree_addr(cdefs.fm1)
assert(fm1_tree_addr == fm1_addr)

-- Get offset of fm1_title from start of resource
local fm1_title_offset = rsrc:tree_obj_offset(cdefs.fm1, cdefs.fm1_title)
-- Type of the title must be boxtext
local fm1_title_type = rsrc:obj_peek_type(fm1_title_offset)
assert(fm1_title_type == k_obty_boxtext)

-- Get offset of fm1_exit from start of resource
local fm1_exit_offset = rsrc:tree_obj_offset(cdefs.fm1, cdefs.fm1_exit)
-- Type of the title must be boxtext
local fm1_exit_type = rsrc:obj_peek_type(fm1_exit_offset)
assert(fm1_exit_type == k_obty_button)

-- Flags of fm1_exit
local fm1_exit_flags = rsrc:obj_peek_flags(fm1_exit_offset)

assert(fm1_exit_flags ==
  k_obfl_selectable | k_obfl_default | k_obfl_exit)
-- Change the flags
rsrc:obj_poke_flags(fm1_exit_offset, fm1_exit_flags ~ k_obfl_exit)
-- Check the changed flags
fm1_exit_flags = rsrc:obj_peek_flags(fm1_exit_offset)
assert(fm1_exit_flags == k_obfl_selectable | k_obfl_default)
-- Restore the flags
rsrc:obj_poke_flags(fm1_exit_offset, fm1_exit_flags | k_obfl_exit)

-- Peek the object values
local ob_next, ob_head, ob_tail, ob_type,
  ob_flags, ob_state, ob_spec,
  ob_x, ob_y, ob_width, ob_height = structs:obj_peek(fm1_exit_offset)

assert(rsrc:obj_peek_type(fm1_exit_offset) == ob_type and
  rsrc:obj_peek_flags(fm1_exit_offset) == ob_flags and
  rsrc:obj_peek_state(fm1_exit_offset) == ob_state and
  rsrc:obj_peek_spec(fm1_exit_offset) == ob_spec)

-- Read the object values into a table
local t = structs:obj_readt(fm1_exit_offset)
assert(t.ob_next == ob_next and
  t.ob_head == ob_head and
  t.ob_tail == ob_tail and
  t.ob_type == ob_type and
  t.ob_flags == ob_flags and
  t.ob_state == ob_state and
  t.ob_spec == ob_spec and
  t.ob_x == ob_x and
  t.ob_y == ob_y and
  t.ob_width == ob_width and
  t.ob_height == ob_height)

-- Centre the form on the screen
local x, y, width, height
status, x, y, width, height = aes:form_center(fm1_addr)
assert(status > 0)

-- Draw the form
status = aes:objc_draw(fm1_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

-- Interact, user must choose exit
gemdos.Cconws("Invoke exit\r\n")
local button_idx = aes:form_do(fm1_addr, 0)
assert(button_idx == cdefs.fm1_exit)

-- Exit button must now be selected
assert(rsrc:obj_peek_state(fm1_exit_offset) ==
  k_obch_selected)

-- Unselect the exit button, without redrawing
status = aes:objc_change(fm1_addr, button_idx,
  0, x, y, width, height, k_obch_normal,
  k_obch_no_redraw)
assert(status > 0)

-- Exit button must now be normal state
assert(rsrc:obj_peek_state(fm1_exit_offset) ==
  k_obch_normal)

-- State back to selected
rsrc:obj_poke_state(fm1_exit_offset, k_obch_no_redraw)
assert(rsrc:obj_peek_state(fm1_exit_offset) ==
  k_obch_no_redraw)
rsrc:obj_poke_state(fm1_exit_offset, k_obch_normal)

-- Draw the form once more. The exit button will appear unselected.
status = aes:objc_draw(fm1_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

gemdos.Cconws("Invoke exit\r\n")
button_idx = aes:form_do(fm1_addr, 0)
assert(button_idx == cdefs.fm1_exit)

-- Unselect the exit button, without redrawing
status = aes:objc_change(fm1_addr, button_idx, 0, x, y, width, height,
  k_obch_normal, k_obch_no_redraw)
assert(status > 0)

-- Draw the form again
status = aes:objc_draw(fm1_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

-- Test objc_find, by detecting when the mouse is over the exit button
gemdos.Cconws("Move mouse over exit\r\n")
local found_obj
repeat
  local _, mx, my
  _, mx, my = aes:graf_mkstate()
  found_obj = aes:objc_find(fm1_addr,
    k_obdr_root, k_obdr_max_depth, mx, my)
until found_obj == button_idx
assert(found_obj == cdefs.fm1_exit)

-- Draw the form again
status = aes:objc_draw(fm1_addr,
  k_obdr_root, k_obdr_max_depth, x, y, width, height)
assert(status > 0)

-- Find the coordinates of exit button
local ox, oy
status, ox, oy = aes:objc_offset(fm1_addr, cdefs.fm1_exit)
assert(status > 0)

-- Now check the coordinates with objc_find
found_obj = aes:objc_find(fm1_addr, 0, k_obdr_max_depth, ox, oy)
assert(found_obj == cdefs.fm1_exit)

-- Test form_button, by detecting click on radio button and using form_button
-- to process.
gemdos.Cconws("Click Radio Button\r\n")
local num_clicks, mx, my, click_obj
repeat
  num_clicks, mx, my = aes:evnt_button(1,
    k_evbu_left_button, k_evbu_left_button)
  click_obj = aes:objc_find(fm1_addr, 0, k_obdr_max_depth, mx, my)
until click_obj >= cdefs.fm1_radio_a and click_obj <= cdefs.fm1_radio_d

-- Process left button click with form_button
local continue, new_edit = aes:form_button(fm1_addr, click_obj, num_clicks)
-- continue will be 1, as it wasn't an exit click.
assert(continue == 1, new_edit == 0)

-- The radio button will have been selected. Unselect it and redraw it.
status = aes:objc_change(fm1_addr, click_obj,
  0, x, y, width, height, k_obch_normal,
  k_obch_redraw)
assert(status > 0)

-- Get address of fm2 tree
local fm2_addr
status, fm2_addr = aes:rsrc_gaddr(k_rsga_tree, cdefs.fm2)
assert(status > 0)

-- Check address using tree_addr matches 
local fm2_tree_addr = rsrc:tree_addr(cdefs.fm2)
assert(fm2_tree_addr == fm2_addr)

-- Get offset of fm2_date from start of resource
local fm2_date_offset = rsrc:tree_obj_offset(cdefs.fm2, cdefs.fm2_date)
local tedinfo_offset = rsrc:obj_tedinfo_offset(fm2_date_offset)

-- Peek the tedinfo values
local <const> te_ptext, te_ptmplt, te_pvalid,
  te_font, te_fontid, te_just,
  te_color, te_fontsize, te_thickness,
  te_txtlen, te_tmplen =
  structs:tedinfo_peek(tedinfo_offset)

-- Read the tedinfo values into a table
t = structs:tedinfo_readt(tedinfo_offset)
assert(t.te_ptext == te_ptext and
  t.te_ptmplt == te_ptmplt and
  t.te_pvalid == te_pvalid and
  t.te_font == te_font and
  t.te_fontid == te_fontid and
  t.te_just == te_just and
  t.te_color == te_color and
  t.te_fontsize == te_fontsize and
  t.te_thickness == te_thickness and
  t.te_txtlen == te_txtlen and
  t.te_tmplen == te_tmplen)

local txt, txtlen = rsrc:tedinfo_read_text(tedinfo_offset)
assert(txt == "280226" and txtlen == 7)

-- Write in todays date
local year, month, day = gemdos.Tgetdate()
local todays_date = string.format("%02d%02d%02d", day, month, year % 100)
rsrc:tedinfo_write_text(tedinfo_offset, todays_date)

local tmplt, tmplen = rsrc:tedinfo_read_tmplt(tedinfo_offset)
assert(tmplt == "__/__/__" and tmplen == 9)

local valid = rsrc:tedinfo_read_valid(tedinfo_offset)
assert(valid == "999999")

-- Get offset of fm2_time from start of resource
local fm2_time_offset = rsrc:tree_obj_offset(cdefs.fm2, cdefs.fm2_time)
tedinfo_offset = rsrc:obj_tedinfo_offset(fm2_time_offset)

txt, txtlen = rsrc:tedinfo_read_text(tedinfo_offset)
assert(txt == "1845" and txtlen == 5)

-- Write in todays time
local hour, minute = gemdos.Tgettime()
local todays_date = string.format("%02d%02d", hour, minute)
rsrc:tedinfo_write_text(tedinfo_offset, todays_date)

-- Centre the form on the screen
status, x, y, width, height = aes:form_center(fm2_addr)
assert(status > 0)

-- Draw the form
status = aes:objc_draw(fm2_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

-- Interact, placing cursor on date field. User must choose exit
gemdos.Cconws("Invoke exit\r\n")

-- Create a form evnt processor
local form_evnt = FormEvnt:new(aes, rsrc)

-- Initialise form event processing
form_evnt:init(cdefs.fm2, cdefs.fm2_date)

-- Process form events
repeat
  local events, mousex, mousey, button, shiftkey, keycode, clicked =
      aes:evnt_multi(k_evmu_button | k_evmu_keybd,
      1, k_evbu_left_button, k_evbu_left_button,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  local continuing =
    form_evnt:proc_evnt(events, mousex, mousey, keycode, clicked)
until not continuing

-- Terminate form event processing
form_evnt:term()

-- Unselect the exit button, without redrawing
status = aes:objc_change(fm2_addr, button_idx,
  0, x, y, width, height, k_obch_normal,
  k_obch_no_redraw)
assert(status > 0)

-- Get the first free string
status, frstr_paddr = aes:rsrc_gaddr(k_rsga_frstr, cdefs.fs1)
assert(status > 0)
local free_string_addr = gemdos.utility.wrapm(frstr_paddr, 4):peek(s32, 0)
assert(free_string_addr == rsrc:frstr_addr(cdefs.fs1))

local free_string_offset = rsrc:frstr_offset(cdefs.fs1)
local free_string = rsrc:reads(free_string_offset, nil, 0)
gemdos.Cconws("free_string " .. free_string .. "\r\n")

-- Get the second free string
status, frstr_paddr = aes:rsrc_gaddr(k_rsga_frstr, cdefs.fs2)
assert(status > 0)
free_string_addr = gemdos.utility.wrapm(frstr_paddr, 4):peek(s32, 0)
assert(free_string_addr == rsrc:frstr_addr(cdefs.fs2))

free_string_offset = rsrc:frstr_offset(cdefs.fs2)
free_string = rsrc:reads(free_string_offset, nil, 0)
gemdos.Cconws("free_string " .. free_string .. "\r\n")

-- Get the first free image
local frimg_paddr
status, frimg_paddr = aes:rsrc_gaddr(k_rsga_frimg, cdefs.fi1)
assert(status > 0)
local free_image_addr = gemdos.utility.wrapm(frimg_paddr, 4):peek(s32, 0)
assert(free_image_addr == rsrc:frimg_addr(cdefs.fi1))

-- Free image one offset
local fi1_offset = rsrc:frimg_offset(cdefs.fi1)
gemdos.Cconws("fi1_offset " .. fi1_offset .. "\r\n")

-- Free image two offset
local fi2_offset = rsrc:frimg_offset(cdefs.fi2)
gemdos.Cconws("fi2_offset " .. fi2_offset .. "\r\n")

local bi_pdata <const>,
  bi_wb <const>, bi_hl <const>,
  bi_x <const>, bi_y <const>,
  bi_color <const> = structs:bitblk_peek(fi1_offset)
assert(bi_pdata >= rsrc_addr and bi_pdata < rsrc_addr + rsrc_size and
  bi_wb == 4 and bi_hl == 28 and
  bi_x == 0 and bi_y == 0 and bi_color == 1)

t = structs:bitblk_readt(fi1_offset)
assert(t.bi_pdata == bi_pdata and
  t.bi_wb == bi_wb and
  t.bi_hl == bi_hl and
  t.bi_x == bi_x and
  t.bi_y == bi_y and
  t.bi_color == bi_color)

-- Get address of fm3 tree
local fm3_addr
status, fm3_addr = aes:rsrc_gaddr(k_rsga_tree, cdefs.fm3)
assert(status > 0)

-- Check address using tree_addr matches 
local fm3_tree_addr = rsrc:tree_addr(cdefs.fm3)
assert(fm3_tree_addr == fm3_addr)
gemdos.Cconws("fm3_tree_addr " .. fm3_tree_addr .. "\r\n")

-- Centre the form on the screen
status, x, y, width, height = aes:form_center(fm3_addr)
assert(status > 0)

-- Draw the form
status = aes:objc_draw(fm3_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

local fm3_a_button_offset = rsrc:tree_obj_offset(cdefs.fm3, cdefs.fm3_a_button)
local fm3_a_button_flags = rsrc:obj_peek_flags(fm3_a_button_offset)
gemdos.Cconws("fm3_a_button_flags: " .. fm3_a_button_flags .. "\r\n")

assert(fm3_a_button_flags == k_obfl_touchexit)
rsrc:obj_poke_flags(fm3_a_button_offset, k_obfl_touchexit)

-- Interact, user must press A BUTTON. User must choose exit
gemdos.Cconws("Press A BUTTON then exit\r\n")
button_idx = aes:form_do(fm3_addr, 0)
assert(button_idx == cdefs.fm3_a_button)

-- Get offset of fm3_im1 from start of resource
local fm3_im1_offset = rsrc:tree_obj_offset(cdefs.fm3, cdefs.fm3_im1)
-- Type of fm3_im1 must be image
local fm3_im1_type = rsrc:obj_peek_type(fm3_im1_offset)
assert(fm3_im1_type == k_obty_image)

-- Get offset of fm3_im2 from start of resource
local fm3_im2_offset = rsrc:tree_obj_offset(cdefs.fm3, cdefs.fm3_im2)
-- Type of fm3_im2 must be image
local fm3_im2_type = rsrc:obj_peek_type(fm3_im2_offset)
assert(fm3_im2_type == k_obty_image)

-- Get offset of fm3_im3 from start of resource
local fm3_im3_offset = rsrc:tree_obj_offset(cdefs.fm3, cdefs.fm3_im3)
-- Type of fm3_im3 must be image
local fm3_im3_type = rsrc:obj_peek_type(fm3_im3_offset)
assert(fm3_im3_type == k_obty_image)

-- Obtain the original specs
local fm3_im1_spec = rsrc:obj_peek_spec(fm3_im1_offset)
local fm3_im2_spec = rsrc:obj_peek_spec(fm3_im2_offset)
local fm3_im3_spec = rsrc:obj_peek_spec(fm3_im3_offset)

-- Change the specs
rsrc:obj_poke_spec(fm3_im1_offset, fi1_offset + rsrc:address())
rsrc:obj_poke_spec(fm3_im2_offset, fi2_offset + rsrc:address())
rsrc:obj_poke_spec(fm3_im3_offset, fi1_offset + rsrc:address())

-- Draw the form
status = aes:objc_draw(fm3_addr, 0, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

-- Do the form
aes:form_do(fm3_addr, 0)

-- Restore the original specs
rsrc:obj_poke_spec(fm3_im1_offset, fm3_im1_spec)
rsrc:obj_poke_spec(fm3_im2_offset, fm3_im2_spec)
rsrc:obj_poke_spec(fm3_im3_offset, fm3_im3_spec)

-- Get address of fm4 tree
local fm4_addr
status, fm4_addr = aes:rsrc_gaddr(k_rsga_tree, cdefs.fm4)
assert(status > 0)

-- Check address using tree_addr matches 
local fm4_tree_addr = rsrc:tree_addr(cdefs.fm4)
assert(fm4_tree_addr == fm4_addr)

-- Centre the form on the screen
status, x, y, width, height = aes:form_center(fm4_addr)
assert(status > 0)

-- Draw the form
status = aes:objc_draw(fm4_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

gemdos.Cconws("Select icon then exit\r\n")
button_idx = aes:form_do(fm4_addr, 0)
assert(button_idx == cdefs.fm4_exit)

-- Get offset of fm4_icon from start of resource
local fm4_icon_offset = rsrc:tree_obj_offset(cdefs.fm4, cdefs.fm4_icon)
-- Type of fm4_icon must be image
local fm4_icon_type = rsrc:obj_peek_type(fm4_icon_offset)
assert(fm4_icon_type == k_obty_icon)

-- Icon must be selected
assert(rsrc:obj_peek_state(fm4_icon_offset) ==
  k_obch_selected)
-- Set icon back to normal
rsrc:obj_poke_state(fm4_icon_offset, k_obch_normal)

local fm4_icon_spec = rsrc:obj_peek_spec(fm4_icon_offset)

-- Peek the icon block
local <const> ib_pmask, ib_pdata, ib_ptext,
  ib_char, ib_xchar, ib_ychar,
  ib_xicon, ib_yicon,
  ib_wicon, ib_hicon,
  ib_xtext, ib_ytext,
  ib_wtext, ib_htext
  = structs:iconblk_peek(fm4_icon_spec - rsrc:address())

-- Read the icon block into a table
t = structs:iconblk_readt(fm4_icon_spec - rsrc:address())
assert(t.ib_pmask == ib_pmask and
    t.ib_pdata == ib_pdata and
    t.ib_ptext == ib_ptext and
    t.ib_char == ib_char and
    t.ib_xchar == ib_xchar and
    t.ib_ychar == ib_ychar and
    t.ib_xicon == ib_xicon and
    t.ib_yicon == ib_yicon and
    t.ib_wicon == ib_wicon and
    t.ib_hicon == ib_hicon and
    t.ib_xtext == ib_xtext and
    t.ib_ytext == ib_ytext and
    t.ib_wtext == ib_wtext and
    t.ib_htext == ib_htext)

-- Get address of fm5 tree
local fm5_addr
status, fm5_addr = aes:rsrc_gaddr(k_rsga_tree, cdefs.fm5)
assert(status > 0)

-- Check address using tree_addr matches 
local fm5_tree_addr = rsrc:tree_addr(cdefs.fm5)
assert(fm5_tree_addr == fm5_addr)

-- Centre the form on the screen
status, x, y, width, height = aes:form_center(fm5_addr)
assert(status > 0)

local top_offset = rsrc:tree_obj_offset(cdefs.fm5, 0)
local x, y, w, h = rsrc:obj_peek_pos(top_offset)
x = 32
y = 32
rsrc:obj_poke_pos(top_offset, x, y, w, h)

-- Draw the form
status = aes:objc_draw(fm5_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

gemdos.Cconws("Select exit\r\n")
button_idx = aes:form_do(fm5_addr, 0)
assert(button_idx == cdefs.fm5_exit)

local obj_orig_t = {}
for obj, offset in rsrc:objects(cdefs.fm5, cdefs.fm5_string_a) do
--   gemdos.Cconws("obj: " .. obj .. " off: " .. offset .. "\r\n")
  obj_orig_t[ #obj_orig_t + 1 ] = obj
end

-- Delete string b
status = aes:objc_delete(fm5_addr, cdefs.fm5_string_b)
assert(status > 0)

local obj_after_del_t = {}
for obj, offset in rsrc:objects(cdefs.fm5, cdefs.fm5_string_a) do
--  gemdos.Cconws("obj: " .. obj .. " off: " .. offset .. "\r\n")
  obj_after_del_t[ #obj_after_del_t + 1 ] = obj
end
assert(#obj_after_del_t == #obj_orig_t - 1)
assert(obj_after_del_t[1] == obj_orig_t[1])
assert(obj_after_del_t[2] == obj_orig_t[3])

-- Now add string b back
status = aes:objc_add(fm5_addr, cdefs.fm5_box, cdefs.fm5_string_b)
local x, y, w, h = rsrc:obj_peek_pos(rsrc:tree_obj_offset(
    cdefs.fm5, cdefs.fm5_box))
--gemdos.Cconws("box x: " .. x .. " y: " .. y .. " w: " .. w .. " h: " .. h .. "\r\n")

local obj_after_add_t = {}
for obj, offset in rsrc:objects(cdefs.fm5, cdefs.fm5_string_a) do
  local t = structs:obj_readt(offset)
--  gemdos.Cconws("obj: " .. obj .. " next: " .. t.ob_next ..
--    " head: " .. t.ob_head .. " tail: " .. t.ob_tail .. "\r\n")
  obj_after_add_t[ #obj_after_add_t + 1 ] = obj
end
assert(#obj_after_add_t == #obj_orig_t)
assert(obj_after_add_t[1] == obj_orig_t[1])
assert(obj_after_add_t[2] == obj_orig_t[3])
assert(obj_after_add_t[3] == obj_orig_t[2])

-- Reorder to place fm5_string_b back into original position
status = aes:objc_order(fm5_addr, cdefs.fm5_string_b, 2)
local obj_after_reorder_t = {}
for obj, offset in rsrc:objects(cdefs.fm5, cdefs.fm5_string_a) do
--  local t = rsrc:obj_readt(offset)
--  gemdos.Cconws("obj: " .. obj .. " next: " .. t.ob_next ..
--    " head: " .. t.ob_head .. " tail: " .. t.ob_tail .. "\r\n")
--  local x, y, w, h = rsrc:obj_peek_pos(offset)
--  gemdos.Cconws("x: " .. x .. " y: " .. y .. " w: " .. w .. " h: " .. h .. "\r\n")

  obj_after_reorder_t[ #obj_after_reorder_t + 1 ] = obj
end
assert(#obj_after_reorder_t == #obj_orig_t)
assert(obj_after_reorder_t[1] == obj_orig_t[1])
assert(obj_after_reorder_t[2] == obj_orig_t[2])
assert(obj_after_reorder_t[3] == obj_orig_t[3])

-- Get address of fm6 tree
local fm6_addr
status, fm6_addr = aes:rsrc_gaddr(k_rsga_tree, cdefs.fm6)
assert(status > 0)

-- Check address using tree_addr matches 
local fm6_tree_addr = rsrc:tree_addr(cdefs.fm6)
assert(fm6_tree_addr == fm6_addr)

-- Centre the form on the screen
status, x, y, width, height = aes:form_center(fm6_addr)
assert(status > 0)

-- Draw the form
status = aes:objc_draw(fm6_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

-- Create a form evnt processor
local form_evnt = FormEvnt:new(aes, rsrc)

-- Initialise form event processing
form_evnt:init(cdefs.fm6, 0)

-- Process form events
repeat
  local clicked_obj, edited_obj
  repeat
    local events, mousex, mousey, button, shiftkey, keycode, clicked =
        aes:evnt_multi(k_evmu_button | k_evmu_keybd,
        1, k_evbu_left_button, k_evbu_left_button,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    form_evnt.continue = 1 -- sliders are touch exit so have to recontinue
    local continuing
    continuing, clicked_obj, edited_obj =
      form_evnt:proc_evnt(events, mousex, mousey, keycode, clicked)
  until not continuing
  if clicked_obj == cdefs.fm6_h_slider then
    local h_pos =
      aes:graf_slidebox(fm6_addr, cdefs.fm6_h_bar, cdefs.fm6_h_slider, 0)
    assert(h_pos >=0 and h_pos <= 1000)
  elseif clicked_obj == cdefs.fm6_v_slider then
    local v_pos =
      aes:graf_slidebox(fm6_addr, cdefs.fm6_v_bar, cdefs.fm6_v_slider, 1)
    assert(v_pos >=0 and v_pos <= 1000)
  end
until clicked_obj == cdefs.fm6_exit

-- Terminate form event processing
form_evnt:term()

-- Get address of fm7 tree
local fm7_addr
status, fm7_addr = aes:rsrc_gaddr(k_rsga_tree, cdefs.fm7)
assert(status > 0)

-- Check address using tree_addr matches 
local fm7_tree_addr = rsrc:tree_addr(cdefs.fm7)
assert(fm7_tree_addr == fm7_addr)

-- Centre the form on the screen
status, x, y, width, height = aes:form_center(fm7_addr)
assert(status > 0)

-- Draw the form
status = aes:objc_draw(fm7_addr, k_obdr_root, k_obdr_max_depth,
  x, y, width, height)
assert(status > 0)

-- Create a form evnt processor
local form_evnt = FormEvnt:new(aes, rsrc)

-- Initialise form event processing
form_evnt:init(cdefs.fm7, 0)

-- Process form events
repeat
  local clicked_obj, edited_obj
  repeat
    local events, mousex, mousey, button, shiftkey, keycode, clicked =
        aes:evnt_multi(k_evmu_button | k_evmu_keybd,
        1, k_evbu_left_button, k_evbu_left_button,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    form_evnt.continue = 1 -- box has touch exit so must recontinue
    local continuing
    continuing, clicked_obj, edited_obj =
      form_evnt:proc_evnt(events, mousex, mousey, keycode, clicked)
  until not continuing
  if clicked_obj == cdefs.fm7_box then
    local inside =
      aes:graf_watchbox(fm7_addr, cdefs.fm7_box,
        k_obch_selected,
        k_obch_normal)
     gemdos.Cconws("inside " .. inside .. "\r\n")
  end
until clicked_obj == cdefs.fm7_exit

-- Terminate form event processing
form_evnt:term()

-- Unwrap the resource
rsrc:unwrap()

-- Free the resource
status = aes:rsrc_free()
assert(status > 0)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
