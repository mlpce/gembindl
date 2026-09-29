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

-- Log the ap_id
gemdos.Cconws("ap_id: " .. ap_id .. "\r\n")

status = aes:graf_mouse(aesdefs.grmo_m_on)
assert(status > 0)

-- get work area of desktop window
local deskx, desky, deskw, deskh
status, deskx, desky, deskw, deskh =
  aes:wind_get(0, aesdefs.wige_workxywh)
assert(status > 0)

gemdos.Cconws("evnt_button: Press left button\r\n")

local left_button = aesdefs.evbu_left_button
local clicked, mousex, mousey, button, shiftkey =
  aes:evnt_button(1, left_button, left_button)

gemdos.Cconws("clicked " .. clicked .. " mousex " .. mousex ..
  " mousey " .. mousey .. " button " .. button .. " shiftkey " ..
  shiftkey .. "\r\n")

gemdos.Cconws("evnt_keybd: Press a\r\n")
local code = aes:evnt_keybd()
gemdos.Cconws(string.format("evnt_keybd: got scan 0x%x ascii 0x%x\r\n",
  code >> 8, code & 0xff))
assert(code == 0x1e61)

gemdos.Cconws("evnt_mouse: Enter top left with mouse\r\n")
local _, x, y, bs, ss =
  aes:evnt_mouse(aesdefs.evmo_enter, 0, 0, 8, 8)
gemdos.Cconws("_ " .. _ .. " x " .. x .. " y " .. y ..
  " bs " .. bs .. " ss " .. ss .. "\r\n")

gemdos.Cconws("evnt_mouse: Leave top left with mouse\r\n")
_, x, y, bs, ss =
  aes:evnt_mouse(aesdefs.evmo_leave, 0, 0, 8, 8)
gemdos.Cconws("_ " .. _ .. " x " .. x .. " y " .. y ..
  " bs " .. bs .. " ss " .. ss .. "\r\n")

local original_speed = aes:evnt_dclick(0, aesdefs.evdc_read)
gemdos.Cconws("evnt_dclick: original speed: " .. original_speed .. "\r\n")
local speed_set = aes:evnt_dclick(4, aesdefs.evdc_set)
gemdos.Cconws("evnt_dclick: set speed: " .. speed_set .. "\r\n")
speed_set = aes:evnt_dclick(4, aesdefs.evdc_read)
gemdos.Cconws("evnt_dclick: read speed: " .. speed_set .. "\r\n")
speed_set = aes:evnt_dclick(original_speed, aesdefs.evdc_set)
gemdos.Cconws("evnt_dclick: restored speed: " .. speed_set .. "\r\n")

-- Test evnt_timer

gemdos.Cconws("evnt_timer: 500ms\r\n")
_ = aes:evnt_timer(500, 0)
gemdos.Cconws("evnt_timer: got " .. _ .. "\r\n")

-- Test appl_write_v/evnt_mesag/appl_readv with imode

local Imode = gemdos.const.Imode
local imode_test = {
  { imode = Imode.s8, rotate = 0, vals =
    { -128, 127, -127, 126 } },
  { imode = Imode.u8, rotate = 0, vals =
    { 0, 255, 1, 254 } },
  { imode = Imode.s16, rotate = 1, vals =
    { -32768, 32767, -32767, 32766 } },
  { imode = Imode.u16, rotate = 1, vals =
    { 0, 65535, 1, 65534 } },
  { imode = Imode.s32, rotate = 2, vals =
    { -2147483648, 2147483647, -2147483647, 2147483646 } }
}

-- Mapping of Imode to string
local imode_str <const> = {}
for k,v in pairs(gemdos.const.Imode) do
  imode_str[v] = k
end

local mesag_tbl = table.create(8, 1)
for k,v in ipairs(imode_test) do
  gemdos.Cconws("Test appl_write_v/evnt_mesag/appl_read_v with imode " ..
    imode_str[v.imode] .. "\r\n")
  local s1 = gemdos.SuperPeek("_hz_200")
  status = aes:appl_write_v(
    ap_id, -- destination application id
    42,    -- message type
    ap_id,  -- sender application id,
    1, 2, 3, 4, 5,
    v.imode, table.unpack(v.vals)
  )
  assert(status > 0)

  local r, mess_type, mess_ap_id, mess_extra_bytes, w1, w2, w3, w4, w5 =
    aes:evnt_mesag()

  assert(--[[r == 1 and]] mess_type == 42 and mess_ap_id == ap_id and
    mess_extra_bytes == #v.vals << v.rotate and
    w1 == 1 and w2 == 2 and w3 == 3 and w4 == 4 and w5 == 5)
  local e1, e2, e3, e4
  status, e1, e2, e3, e4 = aes:appl_read_v(v.imode, ap_id, mess_extra_bytes)
  assert(status > 0 and e1 == v.vals[1] and e2 == v.vals[2] and
    e3 == v.vals[3] and e4 == v.vals[4])
  local s2 = gemdos.SuperPeek("_hz_200")

  gemdos.Cconws("Took " .. (s2 - s1)/200 .. "\r\n")

  gemdos.Cconws("Test appl_write_v/evnt_mesag/appl_read_t with imode " ..
    imode_str[v.imode] .. "\r\n")
  local s1 = gemdos.SuperPeek("_hz_200")
  status = aes:appl_write_v(
    ap_id, -- destination application id
    42,    -- message type
    ap_id,  -- sender application id,
    1, 2, 3, 4, 5,
    v.imode, table.unpack(v.vals)
  )
  assert(status > 0)

  local r, mess_type, mess_ap_id, mess_extra_bytes, w1, w2, w3, w4, w5 =
    aes:evnt_mesag()

  assert(--[[r == 1 and]] mess_type == 42 and mess_ap_id == ap_id and
    mess_extra_bytes == #v.vals << v.rotate and
    w1 == 1 and w2 == 2 and w3 == 3 and w4 == 4 and w5 == 5)
  status, mesag_tbl =
    aes:appl_read_t(v.imode, ap_id, mess_extra_bytes, mesag_tbl)
  assert(status > 0 and
    mesag_tbl[1] == v.vals[1] and mesag_tbl[2] == v.vals[2] and
    mesag_tbl[3] == v.vals[3] and mesag_tbl[4] == v.vals[4])
  local s2 = gemdos.SuperPeek("_hz_200")

  gemdos.Cconws("Took " .. (s2 - s1)/200 .. "\r\n")
end

gemdos.Cconws("testing evnt_multi with button press left button\r\n")
local left_button = aesdefs.evbu_left_button
local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_button,
    1, aesdefs.evbu_left_button, aesdefs.evbu_left_button,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

gemdos.Cconws("happened " .. happened .. "\r\n")
assert(happened == aesdefs.evmu_button)
assert(clicked == 1)
assert(button == aesdefs.evbu_left_button)

gemdos.Cconws("clicked " .. clicked .. " mx " .. mx ..
  " my " .. my .. " button " .. button .. " shiftkey " .. shiftkey .. "\r\n")

gemdos.Cconws("testing evnt_multi with keyboard: Press a\r\n")
local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_keybd,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
gemdos.Cconws("happened " .. happened .. "\r\n")
assert(happened == aesdefs.evmu_keybd)
gemdos.Cconws(string.format("keybd: got scan 0x%x ascii 0x%x\r\n",
  keycode >> 8, keycode & 0xff))
assert(keycode == 0x1e61)

gemdos.Cconws(
  "testing evnt_multi with mouse m1: Enter top left with mouse\r\n")
local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_m1,
    0, 0, 0, aesdefs.evmo_enter, 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0)
gemdos.Cconws("happened " .. happened .. "\r\n")
assert(happened == aesdefs.evmu_m1)
gemdos.Cconws("mx " .. mx .. " my " .. my .. " button " .. button ..
  " shiftkey " .. shiftkey .. "\r\n")

gemdos.Cconws(
  "testing evnt_multi with mouse m1: Leave top left with mouse\r\n")
local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_m1,
    0, 0, 0, aesdefs.evmo_leave, 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0)
gemdos.Cconws("happened " .. happened .. "\r\n")
assert(happened == aesdefs.evmu_m1)
gemdos.Cconws("mx " .. mx .. " my " .. my .. " button " .. button ..
  " shiftkey " .. shiftkey .. "\r\n")

gemdos.Cconws(
  "testing evnt_multi with mouse m2: Enter top left with mouse\r\n")
local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_m2,
    0, 0, 0, 0, 0, 0, 0, 0, aesdefs.evmo_enter, 0, 0, 8, 8, 0, 0)
gemdos.Cconws("happened " .. happened .. "\r\n")
assert(happened == aesdefs.evmu_m2)
gemdos.Cconws("mx " .. mx .. " my " .. my .. " button " .. button ..
  " shiftkey " .. shiftkey .. "\r\n")

gemdos.Cconws(
  "testing evnt_multi with mouse m2: Leave top left with mouse\r\n")
local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_m2,
    0, 0, 0, 0, 0, 0, 0, 0, aesdefs.evmo_leave, 0, 0, 8, 8, 0, 0)
gemdos.Cconws("happened " .. happened .. "\r\n")
assert(happened == aesdefs.evmu_m2)
gemdos.Cconws("mx " .. mx .. " my " .. my .. " button " .. button ..
  " shiftkey " .. shiftkey .. "\r\n")

gemdos.Cconws("testing evnt_multi with mesag\r\n")
for k,v in ipairs(imode_test) do
  gemdos.Cconws("Test appl_write_v/evnt_multi/appl_read_v with imode " ..
    imode_str[v.imode] .. "\r\n")
  local s1 = gemdos.SuperPeek("_hz_200")
  status = aes:appl_write_v(
    ap_id, -- destination application id
    42,    -- message type
    ap_id,  -- sender application id,
    1, 2, 3, 4, 5,
    v.imode, table.unpack(v.vals)
  )
  assert(status > 0)

  local happened, mx, my, button, shiftkey, keycode, clicked =
      aes:evnt_multi(aesdefs.evmu_mesag,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

  -- mesag_v pushes mesag values onto the stack
  local mesag_msg_id, mesag_ap_id, mesag_extra_bytes,
    mesag_1, mesag_2, mesag_3, mesag_4, mesag_5
  if happened & aesdefs.evmu_mesag ~= 0 then
    mesag_msg_id, mesag_ap_id, mesag_extra_bytes,
    mesag_1, mesag_2, mesag_3, mesag_4, mesag_5 = aes:mesag_v()
  end

  assert(mesag_msg_id == 42 and mesag_ap_id == ap_id and
    mesag_extra_bytes == #v.vals << v.rotate and
    mesag_1 == 1 and mesag_2 == 2 and mesag_3 == 3 and mesag_4 == 4 and
    mesag_5 == 5)

  -- mesag_t reads mesag values into a table
  local <const> mesag_tbl = aes:mesag_t()
  assert(mesag_tbl.n == 8)
  assert(mesag_tbl[1] == mesag_msg_id and
    mesag_tbl[2] == mesag_ap_id and
    mesag_tbl[3] == mesag_extra_bytes and
    mesag_tbl[4] == mesag_1 and
    mesag_tbl[5] == mesag_2 and
    mesag_tbl[6] == mesag_3 and
    mesag_tbl[7] == mesag_4 and
    mesag_tbl[8] == mesag_5)

  local e1, e2, e3, e4
  status, e1, e2, e3, e4 = aes:appl_read_v(v.imode, ap_id, mesag_extra_bytes)
  assert(status > 0 and e1 == v.vals[1] and e2 == v.vals[2] and
    e3 == v.vals[3] and e4 == v.vals[4])
  local s2 = gemdos.SuperPeek("_hz_200")

  gemdos.Cconws("Took " .. (s2 - s1)/200 .. "\r\n")
end

gemdos.Cconws("testing evnt_multi with timer 500ms\r\n")
local s1 = gemdos.SuperPeek("_hz_200")
local happened, mx, my, button, shiftkey, keycode, clicked =
    aes:evnt_multi(aesdefs.evmu_timer,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 0)
local s2 = gemdos.SuperPeek("_hz_200")
gemdos.Cconws("Took " .. (s2 - s1)/200 .. "\r\n")

gemdos.Cconws("happened " .. happened .. "\r\n")
assert(happened == aesdefs.evmu_timer)

local find_result = aes:appl_find("LUA")
gemdos.Cconws("find_result " .. find_result .. "\r\n")
assert(find_result == ap_id)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
local xreturn = aes:appl_exit()
assert(xreturn == 1)
gemdos.Cconws("xreturn " .. xreturn .. "\r\n")
