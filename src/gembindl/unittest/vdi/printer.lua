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
local gh = aes:graf_handle()

local svwk_h, workout = vdi:v_opnvwk(gh,
  { gempb.utility.scr_devid(), 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 })
assert(#workout == 57)
gemdos.Cconws("screen virtual wk handle " .. svwk_h .. "\r\n")

-- Open physical workstation for printer
local ppwk_h, workout = vdi:v_opnwk({ 21, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 })
gemdos.Cconws("printer physical wk handle " .. ppwk_h .. "\r\n")

-- Open virtual workstation for printer
local pvwk_h, workout = vdi:v_opnvwk(ppwk_h,
  { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 })
gemdos.Cconws("printer virtual wk handle " .. pvwk_h .. "\r\n")

-- Query scan values
local grh, passes, alh, apage, div = vdi:vq_scan(pvwk_h)
gemdos.Cconws(
  "grh: " .. grh .. " passes: " .. passes .. " alh: " .. alh .. " apage: " ..
  apage .. " div: " .. div .. "\r\n")

-- Log printer resolution
local x_max, y_max = workout[1], workout[2]
gemdos.Cconws(
  "printer resolution x_max: " .. x_max .. " y_max: " .. y_max .. "\r\n")

-- Set clip on printer virtual workstation
vdi:vs_clip(pvwk_h, 1, 0, 0, x_max, y_max)

-- Enumerate the fonts
local enum_fonts_fn = function(work_handle, num_loaded)
  local fonts = {}
  for font_number=1, num_loaded + 1 do -- one is system font
    local font_id, font_name = vdi:vqt_name(work_handle, font_number)
    gemdos.Cconws(
      "font_id: " .. font_id .. " font_name: " .. font_name .. "\r\n")
    if font_id > 0 then
      -- Store font id and the name of the font
      fonts[#fonts + 1] = { font_id, font_name }
    end
  end
  return fonts
end

-- Load fonts through screen virtual work handle
gemdos.Cconws("Loading screen fonts...\r\n")
local num_loaded = vdi:vst_load_fonts(svwk_h)
gemdos.Cconws("Loaded " .. num_loaded .. " screen fonts\r\n")

-- Enumerate the screen fonts
gemdos.Cconws("Screen fonts:\r\n")
enum_fonts_fn(svwk_h, num_loaded)

-- Load fonts through printer virtual work handle
gemdos.Cconws("Loading printer fonts...\r\n")
num_loaded = vdi:vst_load_fonts(pvwk_h)
gemdos.Cconws("Loaded " .. num_loaded .. " printer fonts\r\n")

-- Enumerate the printer fonts
gemdos.Cconws("Printer fonts:\r\n")
local enumed_printer_fonts = enum_fonts_fn(pvwk_h, num_loaded)

-- Output some alpha text to the printer
gemdos.Cconws(
  "Call v_alpha_text to printer virtual wk handle: " .. pvwk_h .. "\r\n")
vdi:v_alpha_text(pvwk_h, "Hello world")

-- Perform graphic output with the printer fonts
gemdos.Cconws("Outputting to printer virtual wk handle: " .. pvwk_h .. "\r\n")
for k,v in ipairs(enumed_printer_fonts) do
  local setid = vdi:vst_font(pvwk_h, v[1])
  if setid == v[1] then
    gemdos.Cconws(
      "Testing: " .. v[1] .. " name: " .. v[2] .. "\r\n")
    vdi:v_gtext(pvwk_h, 100, 100 + (32*k), "Graphic text")
  else
    gemdos.Cconws(
      "ERROR: requested fontid " .. v[1] .. " got " .. setid .. "\r\n")
  end
end

-- For graphics output call updwk
gemdos.Cconws(
  "Call v_updwk on printer virtual wk handle: " .. pvwk_h .. "\r\n")
local res = vdi:v_updwk(pvwk_h)
gemdos.Cconws("v_updwk result: " .. res .. "\r\n")

-- Advance the form
gemdos.Cconws(
  "Call v_form_adv on printer virtual wk handle: " .. pvwk_h .. "\r\n")
vdi:v_form_adv(pvwk_h)

-- Now output the graphics again but just middle of page
gemdos.Cconws(
  "Call v_output_window on printer virtual wk handle: " .. pvwk_h .. "\r\n")
local x1, y1, x2, y2 = x_max // 4, y_max // 4, x_max * 3 // 4, y_max * 3 // 4
gemdos.Cconws(
  "With coordinates x1: " .. x1 .. " y1: " .. y1 ..
  " x2: " .. x2 .. " y2: " .. y2 .. "\r\n")
vdi:v_output_window(pvwk_h, x1, y1, x2, y2)

-- Clear the display list
gemdos.Cconws(
  "Call v_clear_disp_list on printer virtual wk handle: " .. pvwk_h .. "\r\n")
vdi:v_clear_disp_list(pvwk_h)

-- After the v_clear_disp_list updwk will output no graphic
gemdos.Cconws(
  "Call v_updwk on printer virtual wk handle: " .. pvwk_h .. "\r\n")
res = vdi:v_updwk(pvwk_h)
gemdos.Cconws("v_updwk result: " .. res .. "\r\n")

gemdos.Cconws(
"Calling c_clrwk on printer virtual wk handle: " .. pvwk_h .. "\r\n")
vdi:v_clrwk(pvwk_h)

-- Bit image
gemdos.Cconws(
  "Calling v_bit_image on printer virtual wk handle: " .. pvwk_h .. "\r\n")
vdi:v_bit_image(pvwk_h, "UNITTEST.IMG", 1, 0, 0,
  vdidefs.biim_center, vdidefs.biim_center,
  { 0, 0, x_max, y_max })

gemdos.Cconws(
  "Call v_updwk on printer virtual wk handle: " .. pvwk_h .. "\r\n")
res = vdi:v_updwk(pvwk_h)
gemdos.Cconws("v_updwk result: " .. res .. "\r\n")

gemdos.Cconws(
"Calling c_clrwk on printer virtual wk handle: " .. pvwk_h .. "\r\n")
vdi:v_clrwk(pvwk_h)

-- Unloading fonts from printer vwk handle
gemdos.Cconws("Unloading fonts from printer vwh: " .. pvwk_h .. "\r\n")
vdi:vst_unload_fonts(pvwk_h)

-- Unloading fonts from screen vwk handle
gemdos.Cconws("Unloading fonts from screen vwh: " .. svwk_h .. "\r\n")
vdi:vst_unload_fonts(svwk_h)

gemdos.Cconws("Close printer virtual workstation: " .. pvwk_h .. "\r\n")
-- Close virtual workstation for printer
vdi:v_clswk(pvwk_h)

gemdos.Cconws("Close printer physical workstation: " .. ppwk_h .. "\r\n")
-- Close physical workstation for printer
vdi:v_clswk(ppwk_h)

-- Now a hard copy of the screen
gemdos.Cconws("Hardcopy screen virtual workstation: " .. svwk_h .. "\r\n")
vdi:v_hardcopy(svwk_h)

gemdos.Cconws("Close screen virtual workstation: " .. svwk_h .. "\r\n")
-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
