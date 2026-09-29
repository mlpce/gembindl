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

local enum_fonts_fn = function(work_handle, num_loaded)
  local fonts = {}
  for font_number=1, num_loaded + 1 do -- one is system font
    local font_id, font_name = vdi:vqt_name(work_handle, font_number)
    gemdos.Cconws(
      "font_id: " .. font_id .. " font_name: " .. font_name .. "\r\n")
    if font_id > 0 then
      fonts[#fonts + 1] = { font_id, font_name }
    end
  end
  return fonts
end

-- Load fonts through screen virtual work handle
local num_loaded = vdi:vst_load_fonts(svwk_h)

-- Enumerate the screen fonts
local fonts = enum_fonts_fn(svwk_h, num_loaded)

-- Choose the test font, first one is system font
local test_font=fonts[1]
gemdos.Cconws("Testing with: " .. test_font[2] .. "\r\n")
local setid = vdi:vst_font(svwk_h, test_font[1])
assert(setid == test_font[1])

-- Check vqt_fontinfo
local first_char, last_char, dist_tbl, max_cellw, effects_tbl =
  vdi:vqt_fontinfo(svwk_h)
assert(first_char == 0 and last_char == 255)
if hcel == 16 then
  -- ST high
  assert(dist_tbl[1] == 2)
  assert(dist_tbl[2] == 2)
  assert(dist_tbl[3] == 8)
  assert(dist_tbl[4] == 11)
  assert(dist_tbl[5] == 13)
else
  -- ST low, ST med
  assert(dist_tbl[1] == 1)
  assert(dist_tbl[2] == 1)
  assert(dist_tbl[3] == 4)
  assert(dist_tbl[4] == 6)
  assert(dist_tbl[5] == 6)
end
assert(max_cellw == 8)
assert(effects_tbl[1] == 0)
assert(effects_tbl[2] == 0)
assert(effects_tbl[3] == 0)

-- Set thickened text
local effects = vdi:vst_effects(svwk_h, vdidefs.stef_thickened)
assert(effects == vdidefs.stef_thickened)

-- Get font info again and check effects table
_, _, _, _, effects_tbl = vdi:vqt_fontinfo(svwk_h)
assert(effects_tbl[1] == 1)
assert(effects_tbl[2] == 0)
assert(effects_tbl[3] == 0)

-- Set skewed text
effects = vdi:vst_effects(svwk_h, vdidefs.stef_skewed)
assert(effects == vdidefs.stef_skewed)

-- Get font info again and check effects table
_, _, _, _, effects_tbl = vdi:vqt_fontinfo(svwk_h)
if hcel == 16 then
  -- ST high
  assert(effects_tbl[1] == 0)
  assert(effects_tbl[2] == 1)
  assert(effects_tbl[3] == 7)
else
  -- ST low, ST med
  assert(effects_tbl[1] == 0)
  assert(effects_tbl[2] == 1)
  assert(effects_tbl[3] == 3)
end

-- Wait for left mouse button press
gemdos.Cconws("Press left button\r\n")
repeat until vdi:vq_mouse(svwk_h) == 1

-- Cursor home
vdi:v_curhome(svwk_h)

-- Clear screen
vdi:v_clrwk(svwk_h)

-- Set effects back to normal
effects = vdi:vst_effects(svwk_h, vdidefs.stef_normal)
assert(effects == vdidefs.stef_normal)

-- Check vst_height
local wchar, hchar, wcell, hcell = vdi:vst_height(svwk_h,
  hcel == 16 and 13 or 6)
if hcel == 16 then
  assert(wchar == 7)
  assert(hchar == 13)
  assert(wcell == 8)
  assert(hcell == 16)
else
  assert(wchar == 7)
  assert(hchar == 6)
  assert(wcell == 8)
  assert(hcell == 8)
end

-- Check vqt_width
local cc, cellw, oleft, oright = vdi:vqt_width(svwk_h, string.byte('U'))
assert(cc == string.byte('U'))
assert(cellw == 8)
assert(oleft == 0)
assert(oright == 0)

-- Add effects into an array
local effs_tbl = {
  vdidefs.stef_normal,
  vdidefs.stef_thickened,
  vdidefs.stef_light,
  vdidefs.stef_skewed,
  vdidefs.stef_underlined,
  vdidefs.stef_outlined
}

-- Set each effect in turn
local y_pos = hcell * 10
for k,v in ipairs(effs_tbl) do
  -- Set the effect
  effects = vdi:vst_effects(svwk_h, v)
  assert(effects == v)

  -- Draw it
  local text = "UNITTEST UNITTEST UNITTEST"
  vdi:v_gtext(svwk_h, 1, y_pos, text)

  -- Check vqt_extent
  local x1, y1, x2, y2, x3, y3, x4, y4 = vdi:vqt_extent(svwk_h, text)
  assert(x1 == 0 and y1 == 0 and y2 == 0 and x4 == 0)

  if hcel == 16 then
    if v == vdidefs.stef_skewed then
      assert(x2 == 216 and x3 == 216)
      assert(y3 == hcel and y4 == hcel)
    elseif v == vdidefs.stef_outlined then
      assert(x2 == 260 and x3 == 260)
      assert(y3 == hcel + 2 and y4 == hcel + 2)
    else
      assert(x2 == 208 and x3 == 208)
      assert(y3 == hcel and y4 == hcel)
    end
  else
    if v == vdidefs.stef_skewed then
      assert(x2 == 212 and x3 == 212)
      assert(y3 == hcel and y4 == hcel)
    elseif v == vdidefs.stef_outlined then
      assert(x2 == 260 and x3 == 260)
      assert(y3 == hcel + 2 and y4 == hcel + 2)
    else
      assert(x2 == 208 and x3 == 208)
      assert(y3 == hcel and y4 == hcel)
    end
  end
  y_pos = y_pos + hcell + 1
end

-- Cursor home
vdi:v_curhome(svwk_h)

-- Clear screen
vdi:v_clrwk(svwk_h)

-- Set effects back to normal
effects = vdi:vst_effects(svwk_h, vdidefs.stef_normal)
assert(effects == vdidefs.stef_normal)

-- Check v_justified with left aligment
vdi:vst_alignment(svwk_h, vdidefs.stal_left,
  vdidefs.stal_top)

vdi:v_justified(svwk_h, 0, hcell, "This is not justified", x_max,
  vdidefs.just_nojustify, vdidefs.just_nojustify)
-- Justify between characters
vdi:v_justified(svwk_h, 0, hcell*2, "This is justified between chars", x_max,
  vdidefs.just_nojustify, vdidefs.just_justify)
-- Justify between words
vdi:v_justified(svwk_h, 0, hcell*3, "This is justified between words", x_max,
  vdidefs.just_justify, vdidefs.just_nojustify)

-- Check v_justified with center alignment
vdi:vst_alignment(svwk_h, vdidefs.stal_center,
  vdidefs.stal_top)

vdi:v_justified(svwk_h, x_max//2, hcell*4, "This is not justified",
  x_max, vdidefs.just_nojustify, vdidefs.just_nojustify)
-- Justify between characters
vdi:v_justified(svwk_h, x_max//2, hcell*5, "This is justified between chars",
  x_max, vdidefs.just_nojustify, vdidefs.just_justify)
-- Justify between words
vdi:v_justified(svwk_h, x_max//2, hcell*6, "This is justified between words",
  x_max, vdidefs.just_justify, vdidefs.just_nojustify)

-- Check v_justified with right alignment
vdi:vst_alignment(svwk_h, vdidefs.stal_right,
  vdidefs.stal_top)

vdi:v_justified(svwk_h, x_max, hcell*7, "This is not justified",
  x_max, vdidefs.just_nojustify, vdidefs.just_nojustify)
-- Justify between characters
vdi:v_justified(svwk_h, x_max, hcell*8, "This is justified between chars",
  x_max, vdidefs.just_nojustify, vdidefs.just_justify)
-- Justify between words
vdi:v_justified(svwk_h, x_max, hcell*9, "This is justified between words",
  x_max, vdidefs.just_justify, vdidefs.just_nojustify)

-- Add vertical alignments into an array
local align_tbl = {
  vdidefs.stal_base,
  vdidefs.stal_half,
  vdidefs.stal_ascent,
  vdidefs.stal_bottom,
  vdidefs.stal_descent,
  vdidefs.stal_top
}

-- Render an underscore with each vertical alignment
y_pos = hcell*11
local x_pos = 0
for k,v in ipairs(align_tbl) do
  vdi:vst_alignment(svwk_h, vdidefs.stal_left, v)
  vdi:v_gtext(svwk_h, x_pos, y_pos, "_")
  x_pos = x_pos + wchar
end

-- Render a string at each ninety degree orientation
for rotation = 0, 2700, 900 do
  vdi:vst_rotation(svwk_h, rotation)
  vdi:vst_alignment(svwk_h, vdidefs.stal_center,
    vdidefs.stal_bottom)
  vdi:v_gtext(svwk_h, x_max//2, y_max//2, "ROTATION")
end

-- Set rotation back to zero
vdi:vst_rotation(svwk_h, 0)

-- text color 1
vdi:vst_color(svwk_h, 1)
y_pos = hcell*12
vdi:vst_alignment(svwk_h, vdidefs.stal_left,
  vdidefs.stal_top)
vdi:v_gtext(svwk_h, 0, hcell*12, "UNITTEST")
-- text color 0 is visible when using xor against the background
vdi:vst_color(svwk_h, 0)
vdi:vswr_mode(svwk_h, vdidefs.swmo_xor)
vdi:v_gtext(svwk_h, 0, hcell*13, "UNITTEST")

-- Check vqt_attributes
vdi:vst_alignment(svwk_h, vdidefs.stal_center,
  vdidefs.stal_descent)
vdi:vst_rotation(svwk_h, 2700)
local text_face, text_color, angle, hor_align, ver_align,
  wr_mode, char_w, char_h, cell_w, cell_h = vdi:vqt_attributes(svwk_h)
assert(text_face == setid)
assert(text_color == 0)
assert(angle == 2700)
assert(hor_align == vdidefs.stal_center)
assert(ver_align == vdidefs.stal_descent)
-- NOTE(mlpce): TOS 1.04 wr_mode is one less than set. EmuTOS okay.
assert(wr_mode == vdidefs.swmo_xor or -- EmuTOS correct
  wr_mode == vdidefs.swmo_xor - 1) -- TOS 1.04 one less
assert(char_w == wchar)
assert(char_h == hchar)
assert(cell_w == wcell)
assert(cell_h == hcell)

-- Check vst_point
vdi:vst_rotation(svwk_h, 0)
vdi:vst_color(svwk_h, 1)
vdi:vswr_mode(svwk_h, vdidefs.swmo_replace)
vdi:vst_alignment(svwk_h, vdidefs.stal_left, vdidefs.stal_top)
local wcharp, hcharp, wcellp, hcellp = vdi:vst_point(svwk_h, 8)
assert(wcharp == 8)
assert(hcharp == 5)
assert(wcellp == 4)
assert(hcellp == 6)

-- Render at the point size
vdi:v_gtext(svwk_h, 0, hcell*14, "UNITTEST")

-- Unloading fronts from screen vwk handle
vdi:vst_unload_fonts(svwk_h)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
