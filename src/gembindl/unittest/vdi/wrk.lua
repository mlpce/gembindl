local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")

-- Create parameter block and aes/vdi tables
local pb = gempb.create_pb()
local aes = AES:new(pb)
local vdi = VDI:new(pb)

-- Check that gdos is present
assert(gempb.utility.vq_gdos() ~= 0)

-- appl_init
local ap_id, aes_version = aes:appl_init()
assert(ap_id ~= -1 and aes_version > 0)
gemdos.Cconws("ap_id " .. ap_id .. " aes_version " .. aes_version .. "\r\n")

-- Obtain screen physical workstation handle, and cell/box dimensions
local gh, wcel, hcel, wbox, hbox = aes:graf_handle()
gemdos.Cconws("graf_handle " .. gh .. " wcel " .. wcel .. " hcel " .. hcel ..
  " wbox " .. wbox .. " hbox " .. hbox .. "\r\n")
assert(
  (wcel == 8 and hcel == 8 and wbox == 12 and hbox == 11) or -- low
  (wcel == 8 and hcel == 8 and wbox == 24 and hbox == 11) or -- med
  (wcel == 8 and hcel == 16 and wbox == 19 and hbox == 19)   -- high
)

-- Open virtual workstation
local vwk_h, workout = vdi:v_opnvwk(gh)
assert(#workout == 57)

-- Clear the screen
vdi:v_clrwk(vwk_h)

-- Check screen dimensions
local x_max, y_max = workout[1], workout[2]

-- Log a value to check if not a normal ST x resolution
if x_max ~= 319 and x_max ~= 639 then
  gemdos.Cconws("check x_max: " .. x_max .. "\r\n")
end

-- Log a value to check if not a normal ST y resolution
if y_max ~= 199 and y_max ~= 399 then
  gemdos.Cconws("check y_max: " .. y_max .. "\r\n")
end

-- workstation type of input and output
local wrk_type = workout[45]
assert(wrk_type == 2)

-- minimum and maximum text character size
local min_cwidth, min_cheight, max_cwidth, max_cheight =
  workout[46], workout[47], workout[48], workout[49]
gemdos.Cconws("min_cwidth " .. min_cwidth .. " min_cheight " ..
  min_cheight ..  " max_cwidth " .. max_cwidth .. " max cheight " ..
  max_cheight .. "\r\n")
assert(min_cwidth == 5 and min_cheight == 4 and
  max_cwidth == 7 and max_cheight == 13)

-- Check vq_color
vdi:vs_color(vwk_h, 0, 0, 0, 0)
local idxr, rr, gr, br = vdi:vq_color(vwk_h, 0, 0)
local idxs, rs, gs, bs = vdi:vq_color(vwk_h, 0, 1)
assert(idxr == 0 and idxs == 0)
assert(rr == 0 and gr == 0 and br == 0)
assert(rs == 0 and gs == 0 and bs == 0)

vdi:vs_color(vwk_h, 0, 998, 998, 998)
idxr, rr, gr, br = vdi:vq_color(vwk_h, 0, 0)
idxs, rs, gs, bs = vdi:vq_color(vwk_h, 0, 1)
assert(idxr == 0 and idxs == 0)
assert(rr == 998 and gr == 998 and br == 998)
assert(rs == 1000 and gs == 1000 and bs == 1000)

assert(vdi:vq_color(vwk_h, 1000, 0, 0) == -1)

-- Close virtual workstation
vdi:v_clsvwk(vwk_h)

-- Open physical workstation for metafile
local wk_h
wk_h, workout = vdi:v_opnwk({ 31, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 })
gemdos.Cconws("meta phys handle " .. wk_h .. "\r\n")

-- Check screen dimensions
x_max, y_max = workout[1], workout[2]
gemdos.Cconws(("x_max " .. x_max .. " y_max " .. y_max .. "\r\n"))
assert(x_max == 32767 and y_max == 32767)

-- workstation type of metafile
wrk_type = workout[45]
assert(wrk_type == 4)

-- Close physical workstation
vdi:v_clswk(wk_h)

-- appl_exit
aes:appl_exit()
