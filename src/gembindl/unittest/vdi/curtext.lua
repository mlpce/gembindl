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
local vwk_h = vdi:v_opnvwk((aes:graf_handle()))

-- Number of text rows and columns
local num_rows, num_columns = vdi:vq_chcells(vwk_h)

-- Enter text mode
vdi:v_enter_cur(vwk_h)

-- Inquire cursor address
local row, column = vdi:vq_curaddress(vwk_h)
-- Cursor is at home position
assert(row == 1 and column == 1)

-- Move cursor to middle of screen
local str = "This is a test string"
local to_y = num_rows >> 1
local to_x = num_columns - #str >> 1
vdi:vs_curaddress(vwk_h, to_y, to_x)

-- Output the text string
vdi:v_curtext(vwk_h, str)

-- Inquire cursor address
row, column = vdi:vq_curaddress(vwk_h)
-- Cursor is placed after the output text
assert(row == to_y)
assert(column == to_x + #str)

-- Cursor home
vdi:v_curhome(vwk_h)

-- Normal text
vdi:v_curtext(vwk_h, "Normal text ")

-- Reverse video on
vdi:v_rvon(vwk_h)

-- Write text in reverse video
vdi:v_curtext(vwk_h, "Reverse video")

-- Reverse video off
vdi:v_rvoff(vwk_h)

-- Normal text
vdi:v_curtext(vwk_h, " Normal text")

-- Test cursor left and down
vdi:v_curleft(vwk_h) vdi:v_curleft(vwk_h)
vdi:v_curdown(vwk_h)

-- Query cursor address
row, column = vdi:vq_curaddress(vwk_h)
-- Cursor now at row 2 and column 36
assert(row == 2)
assert(column == 36)

-- Test cursor right and up
vdi:v_curright(vwk_h)
vdi:v_curup(vwk_h)
-- Query cursor address
row, column = vdi:vq_curaddress(vwk_h)
-- Cursor now at row 1 and column 37
assert(row == 1)
assert(column == 37)

-- Cursor home
vdi:v_curhome(vwk_h)

-- Several lines of text
vdi:v_curtext(vwk_h, "A test string\r\nA test string\r\nA test string")

-- Query cursor address
row, column = vdi:vq_curaddress(vwk_h)
assert(row == 3)
assert(column == 14)

-- Cursor home
vdi:v_curhome(vwk_h)

-- Erase to end of screen
vdi:v_eeos(vwk_h)

-- Test string
vdi:v_curtext(vwk_h, "A test string")
for i=1,7 do
  vdi:v_curleft(vwk_h)
end

-- Erase to end of line
vdi:v_eeol(vwk_h)

-- Query cursor address
row, column = vdi:vq_curaddress(vwk_h)
assert(row == 1)
assert(column == 7)

-- Exit text mode
vdi:v_exit_cur(vwk_h)

-- Close virtual workstation
vdi:v_clsvwk(vwk_h)

-- appl_exit
aes:appl_exit()
