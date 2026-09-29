global assert, pairs, setmetatable, gemdos, gempb

local <const> AES = {}

local <const> k_aes_control = gempb.const.Pbid.aes_control
local <const> k_aes_global = gempb.const.Pbid.aes_global
local <const> k_aes_intin = gempb.const.Pbid.aes_intin
local <const> k_aes_intout = gempb.const.Pbid.aes_intout
local <const> k_aes_addrin = gempb.const.Pbid.aes_addrin
local <const> k_aes_addrout = gempb.const.Pbid.aes_addrout
local <const> k_Imode = gemdos.const.Imode
local <const> k_u8 = gemdos.const.Imode.u8
local <const> k_s16 = gemdos.const.Imode.s16
local <const> k_u16 = gemdos.const.Imode.u16
local <const> k_s32 = gemdos.const.Imode.s32
local <const> k_allocm = gemdos.utility.allocm
local <const> k_wrapm = gemdos.utility.wrapm

-- Mapping of error code to string
local <const> k_ec_str = {}
for k,v in pairs(gemdos.const.Error) do
  k_ec_str[v] = k
end

-- Size rotator for imodes
local <const> imode_sz_r = {
  [k_Imode.s8] = 0,
  [k_Imode.u8] = 0,
  [k_Imode.s16] = 1,
  [k_Imode.u16] = 1,
  [k_Imode.s32] = 2
}

-- Memory user data buffer size
local <const> k_buffer_size = 4096

-- new. Create AES table using passed GEM parameter block.
-- Input:
--   1) userdata: pb the GEMPB userdata
--   2) table: table to use or nil for a new table
-- Result:
--   1) table: the AES table
function AES:new(pb, o)
  o = o or {}
  local <const> ec, buffer = k_allocm(k_buffer_size)
  assert(ec == k_buffer_size, k_ec_str[ec])
  o.pb_ = pb
  o.buffer_ = buffer
  o.buffer_addr_ = buffer:address()
  self.__index = self
  return setmetatable(o, self)
end

-- pb
-- Returns:
--   1) integer: parameter block user data
function AES:pb()
  return self.pb_
end

-- bversion. gemdbindl AES binding version
-- Returns:
--   1) integer: gembindl AES binding major version
--   2) integer: gembindl AES binding minor version
--   3) integer: gembindl AES binding micro version
function AES:bversion()
  return 1, 0, 0
end

-- appl_init
-- Returns:
--   1) integer: ap_id
--   2) integer: aes version
function AES:appl_init()
  return self.pb_:call(
    k_aes_intout, 1, -1,
    k_aes_global, 1, 0,
    k_aes_control, 3, 10, 0, 1,
    k_aes_intout, 1,
    k_aes_global, 1)
end

-- appl_read_v. Read message to return values
-- Input:
--   1) integer: imode integer mode
--   2) integer: ap_id of target application
--   3) integer: num_bytes number of bytes to read
-- Returns:
--   1) integer: >0 on success, 0 on error
--   n) integer: message integer values
function AES:appl_read_v(imode, ap_id, num_bytes)
  assert(num_bytes > 0 and num_bytes < k_buffer_size)
  return self.pb_:call(
    k_aes_intin, 2, ap_id, num_bytes,
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 11, 2, 1, 1,
    k_aes_intout, 1),
    self.buffer_:peek(imode, 0, num_bytes >> imode_sz_r[imode])
end

-- appl_read_t. Read message to table values
-- Input:
--   1) integer: imode integer mode
--   2) integer: ap_id of target application
--   3) integer: num_bytes number of bytes to read
--   4) optional table: the result table (a new one is created if missing)
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) table: message integer values read
function AES:appl_read_t(imode, ap_id, num_bytes, tbl)
  assert(num_bytes > 0 and num_bytes < k_buffer_size)
  return self.pb_:call(
    k_aes_intin, 2, ap_id, num_bytes,
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 11, 2, 1, 1,
    k_aes_intout, 1),
    self.buffer_:readt(imode, 0, num_bytes >> imode_sz_r[imode], tbl)
end

-- appl_write_v. Write message using varg values for any extra data
-- Input:
--   1) integer: application id of destination
--   2) integer: the type of message
--   3) integer: application id of sender
--   4) optional integer: message word
--   5) optional integer: message word
--   6) optional integer: message word
--   7) optional integer: message word
--   8) optional integer: message word
--   9) optional integer: Imode integer mode for extra data
--   n) optional integers: Extra data values to write
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:appl_write_v(dst_ap_id, msg_type, src_ap_id,
    word1, word2, word3, word4, word5, extra_imode, ...vararg)
  local <const> buffer, num_extra_bytes =
    self.buffer_, vararg.n << imode_sz_r[extra_imode or 0]

  -- Set word values to zero if missing
  word1 = word1 or 0
  word2 = word2 or 0
  word3 = word3 or 0
  word4 = word4 or 0
  word5 = word5 or 0

  local n = buffer:poke(k_s16, 0, msg_type, src_ap_id,
    num_extra_bytes, word1, word2, word3, word4, word5)
  if num_extra_bytes > 0 then
    n = n + buffer:poke(extra_imode, n, ...)
  end

  return self.pb_:call(
    k_aes_intin, 2, dst_ap_id, n,
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 12, 2, 1, 1,
    k_aes_intout, 1)
end

-- appl_write_t. Write message using table values for any extra data
-- Input:
--   1) integer: application id of destination
--   2) integer: the type of message
--   3) integer: application id of sender
--   4) optional integer: message word
--   5) optional integer: message word
--   6) optional integer: message word
--   7) optional integer: message word
--   8) optional integer: message word
--   9) optional integer: Imode integer mode for extra data
--   n) optional table: Extra data values to write
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:appl_write_t(dst_ap_id, msg_type, src_ap_id,
    word1, word2, word3, word4, word5, extra_imode, vals)
  local <const> buffer, num_extra_bytes =
    self.buffer_, vals ~= nil and #vals or 0

  -- Set word values to zero if missing
  word1 = word1 or 0
  word2 = word2 or 0
  word3 = word3 or 0
  word4 = word4 or 0
  word5 = word5 or 0

  local n = buffer:poke(k_s16, 0, msg_type, src_ap_id,
    num_extra_bytes, word1, word2, word3, word4, word5)
  if num_extra_bytes > 0 then
    n = n + buffer:writet(extra_imode, n, vals)
  end

  return self.pb_:call(
    k_aes_intin, 2, dst_ap_id, n,
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 12, 2, 1, 1,
    k_aes_intout, 1)
end

-- appl_find. Find application id
-- Input:
--   1) string: name of application
-- Returns:
--   1) integer: application id or -1 if not found
function AES:appl_find(fname)
  local <const> buffer, fname_len = self.buffer_, #fname
  assert(fname_len <= 8)
  buffer:set(buffer:writes(0, fname), 32, 8 - fname_len)
  buffer:poke(k_u8, 8, 0)
  return self.pb_:call(
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 13, 0, 1, 1,
    k_aes_intout, 1)
end

-- appl_exit
-- Returns:
--   1) integer: ap_xreturn
function AES:appl_exit()
  return self.pb_:call(
    k_aes_control, 4, 19, 0, 1, 0,
    k_aes_intout, 1)
end

-- evnt_keybd
-- Returns:
--   1) integer: scancode (bits 8-15) and ascii (bits 0 - 7)
function AES:evnt_keybd()
  return self.pb_:call(
    k_aes_control, 4, 20, 0, 1, 0,
    k_aes_intout, 1)
end

-- evnt_button
-- Input:
--   1) integer: clicks
--   2) integer: bmask
--   3) integer: bstate
-- Returns:
--   1) integer: clicked
--   2) integer: mousex
--   3) integer: mousey
--   4) integer: button
--   5) integer: shiftkey
--   NOTE: See AESDefs for button and key bits
function AES:evnt_button(clicks, bmask, bstate)
  return self.pb_:call(
    k_aes_intin, 3, clicks, bmask, bstate,
    k_aes_control, 4, 21, 3, 5, 0,
    k_aes_intout, 5)
end

-- evnt_mouse
-- Input:
--   1) integer: flag
--   2) integer: x
--   3) integer: y
--   4) integer: w
--   5) integer: h
--   NOTE: See AES.const.evnt_mouse for flag
-- Returns:
--   1) integer: reserved (always 1)
--   2) integer: mousex
--   3) integer: mousey
--   4) integer: button
--   5) integer: shiftkey
--   NOTE: see AESDefs for button and shiftkey bits
function AES:evnt_mouse(flag, x, y, w, h)
  return self.pb_:call(
    k_aes_intin, 5, flag, x, y, w, h,
    k_aes_control, 4, 22, 5, 5, 0,
    k_aes_intout, 5)
end

-- evnt_mesag.
-- Returns:
--   1) integer: reserved (always 1)
--   2) integer: word 1: message id
--   3) integer: word 2: sender application id
--   4) integer: word 3: number of extra bytes
--   5) integer: word 4: message dependent
--   6) integer: word 5: message dependent
--   7) integer: word 6: message dependent
--   8) integer: word 7: message dependent
--   9) integer: word 8: message dependent
--   NOTE: if word 3 is greater than zero the extra bytes must be read
--   separately using appl_read.
function AES:evnt_mesag()
  return self.pb_:call(
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 23, 0, 1, 1,
    k_aes_intout, 1),
    self.buffer_:peek(k_s16, 0,  8)
end

-- evnt_timer
-- Input:
--   1) integer: timelo
--   2) integer: timehi
-- Returns:
--   1) integer: reserved (always 1)
function AES:evnt_timer(timelo, timehi)
  return self.pb_:call(
    k_aes_intin, 2, timelo, timehi,
    k_aes_control, 4, 24, 2, 1, 0,
    k_aes_intout, 1)
end

-- evnt_multi
-- Input:
--   1) integer: events to wait for
--   2) integer: number of clicks to wait for
--   3) integer: bmask
--   4) integer: bstate
--   5) integer: m1flag
--   6) integer: m1x first mouse rectangle x
--   7) integer: m1y first mouse rectangle y
--   8) integer: m1w first mouse rectangle w
--   9) integer: m1h first mouse rectangle h
--   10) integer: m2flag
--   11) integer: m2x second mouse rectangle x
--   12) integer: m2y second mouse rectangle y
--   13) integer: m2w second mouse rectangle w
--   14) integer: m2h second mouse rectangle h
--   15) integer: timelo low word of timer
--   16) integer: timehi high word of timer
--   NOTE: See AESDefs for events bits, bmask, bstate, m1flag and m2flag
-- Returns:
--   1) integer: the event bits that happened
--   2) integer: mouse x position (always valid)
--   3) integer: mouse y position (always valid)
--   4) integer: mouse button state (always valid)
--   5) integer: shift key states (always valid)
--   6) integer: keycode (valid on event)
--   7) integer: clicked (valid on event)
--   NOTE: See AESDefs for button and key bits. If evmu.mesag occurs,
--   the message can be read separately with mesag_v.
function AES:evnt_multi(events, clicks, bmask, bstate, m1flag,
    m1x, m1y, m1w, m1h, m2flag, m2x, m2y, m2w, m2h, timelo, timehi)
  return self.pb_:call(
      k_aes_intin, 16,
        events, clicks, bmask, bstate,
        m1flag, m1x, m1y, m1w, m1h,
        m2flag, m2x, m2y, m2w, m2h,
        timelo, timehi,
      k_aes_addrin, 1, self.buffer_addr_,
      k_aes_control, 4, 25, 16, 7, 1,
      k_aes_intout, 7)
end

-- mesag_v. When evnt_multi mesag occurs, this fn reads the values.
-- This function must be called immediately after evnt_multi.mesag is
-- received, otherwise the values may get overwritten by subsequent API
-- calls.
-- Returns:
--   1) integer: word 1: message id (valid on event)
--   2) integer: word 2: sender application id (valid on event)
--   3) integer: word 3: number of extra bytes (valid on event)
--   4) integer: word 4: message dependent (valid on event)
--   5) integer: word 5: message dependent (valid on event)
--   6) integer: word 6: message dependent (valid on event)
--   7) integer: word 7: message dependent (valid on event)
--   8) integer: word 8: message dependent (valid on event)
function AES:mesag_v()
  return self.buffer_:peek(k_s16, 0, 8)
end

-- mesag_v. When evnt_multi mesag occurs, this fn reads the values.
-- This function must be called immediately after evnt_multi mesag is
-- received, otherwise the values may get overwritten by subsequent API
-- calls.
-- Input:
--   1) optional table: the result table (a new one is created if missing)
-- Returns:
--   1) table: array of 8 integers holding the 8 words (valid on event)
function AES:mesag_t(tbl)
  return self.buffer_:readt(k_s16, 0, 8, tbl)
end  

-- evnt_dclick
-- Input:
--   1) integer: speed (0 slowest to 4 fastest)
--   2) integer: flag
--   NOTE: see AESDefs for flag
-- Returns:
--   1) integer: existing or new double click speed
function AES:evnt_dclick(speed, flag)
  return self.pb_:call(
    k_aes_intin, 2, speed, flag,
    k_aes_control, 4, 26, 2, 1, 0,
    k_aes_intout, 1)
end

-- menu_bar
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: show_flag: 1=display 0=erase
--   NOTE: see AESDefs for show_flag
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:menu_bar(tree_addr, show_flag)
  return self.pb_:call(
    k_aes_intin, 1, show_flag,
    k_aes_addrin, 1, tree_addr,
    k_aes_control, 4, 30, 1, 1, 1,
    k_aes_intout, 1)
end

-- menu_icheck
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: the object to check/uncheck
--   3) integer: setting: 1=check 0=uncheck
--   NOTE: See AESDefs for setting
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:menu_icheck(tree_addr, obj, setting)
  return self.pb_:call(
    k_aes_intin, 2, obj, setting,
    k_aes_addrin, 1, tree_addr,
    k_aes_control, 4, 31, 2, 1, 1,
    k_aes_intout, 1)
end

-- menu_ienable
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: the object to enable/disable
--   3) integer: setting: 1=enable 0=disable
--   NOTE: See AESDefs for setting
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:menu_ienable(tree_addr, obj, setting)
  return self.pb_:call(
    k_aes_intin, 2, obj, setting,
    k_aes_addrin, 1, tree_addr,
    k_aes_control, 4, 32, 2, 1, 1,
    k_aes_intout, 1)
end

-- menu_tnormal
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: the title object to reverse/normal
--   3) integer: setting: 1=normal 0=reverse
--   NOTE: See AESDefs for setting
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:menu_tnormal(tree_addr, obj, setting)
  return self.pb_:call(
    k_aes_intin, 2, obj, setting,
    k_aes_addrin, 1, tree_addr,
    k_aes_control, 4, 33, 2, 1, 1,
    k_aes_intout, 1)
end

-- menu_text
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: the object having text replaced
--   3) integer: text: replacement menu text (<= original str length)
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:menu_text(tree_addr, obj, text)
  local buffer = self.buffer_
  buffer:poke(k_u8, buffer:writes(0, text), 0)
  return self.pb_:call(
    k_aes_intin, 1, obj,
    k_aes_addrin, 2, tree_addr, self.buffer_addr_,
    k_aes_control, 4, 34, 1, 1, 2,
    k_aes_intout, 1)
end

-- objc_add
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: parent: parent object number
--   3) integer: child: child object number
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:objc_add(tree_addr, parent_obj, child_obj)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 2, parent_obj, child_obj,
    k_aes_control, 4, 40, 2, 1, 1,
    k_aes_intout, 1)
end

-- objc_delete
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: the object to delete
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:objc_delete(tree_addr, obj)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 1, obj,
    k_aes_control, 4, 41, 1, 1, 1,
    k_aes_intout, 1)
end

-- objc_draw
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: firstobj: number of first object to be drawn
--   3) integer: depth: number of generations to draw
--   4) integer: clipping left
--   5) integer: clipping top
--   6) integer: clipping width
--   7) integer: clipping height
--   NOTE: see AESDefs for maximum depth
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:objc_draw(tree_addr, firstobj, depth, clipx, clipy, clipw, cliph)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 6, firstobj, depth, clipx, clipy, clipw, cliph,
    k_aes_control, 4, 42, 6, 1, 1,
    k_aes_intout, 1)
end

-- objc_draw
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: firstobj: number of first object to search
--   3) integer: depth: number of generations to search
--   4) integer: x coordinate
--   5) integer: y coordinate
--   NOTE: see AESDefs for maximum depth
-- Returns:
--   1) integer: number of object found, otherwise -1
function AES:objc_find(tree_addr, firstobj, depth, x, y)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 4, firstobj, depth, x, y,
    k_aes_control, 4, 43, 4, 1, 1,
    k_aes_intout, 1)
end

-- objc_offset
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: number of object
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: x coordinate
--   3) integer: y coordinate
function AES:objc_offset(tree_addr, obj)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 1, obj,
    k_aes_control, 4, 44, 1, 3, 1,
    k_aes_intout, 3
  )
end

-- objc_order
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: number of object
--   3) integer: newpos: new position (-1=top, 0=bottom, 1=bottom+1, etc)
-- Returns:
--   1) integer: number of object found, otherwise -1
function AES:objc_order(tree_addr, obj, newpos)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 2, obj, newpos,
    k_aes_control, 4, 45, 2, 1, 1,
    k_aes_intout, 1)
end

-- objc_edit
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: number of object
--   3) integer: keycode: key_code from e.g. evnt_multi and form_keybd
--   4) integer: idx: index of next character (cursor position)
--   5) integer: mode: 0=res, 1=init, 2=char, 3=end
--   NOTE: see AESDefs for mode
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: index of next character to be edited
function AES:objc_edit(tree_addr, obj, keycode, idx, mode)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 4, obj, keycode, idx, mode,
    k_aes_control, 4, 46, 4, 2, 1,
    k_aes_intout, 2)
end

-- objc_change
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: changeobj: number of object to be changed
--   3) integer: reserved
--   4) integer: clipping left
--   5) integer: clipping top
--   6) integer: clipping width
--   7) integer: clipping height
--   8) integer: state
--   9) integer: redraw
--   NOTE: see AESDefs for redraw flag
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:objc_change(tree_addr, changeobj, reserved,
    clipx, clipy, clipw, cliph, state, redraw)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 8, changeobj, reserved, clipx, clipy, clipw, cliph,
      state, redraw,
    k_aes_control, 4, 47, 8, 1, 1,
    k_aes_intout, 1)
end

-- form_do
-- Input:
--   1) integer: tree address
--   2) integer: editobj index of editable object (use 0 for none)
-- Returns:
--   1) integer: object index of the EXIT or TOUCHEXIT button activated
--   NOTE: returns with bit 15 set if TOUCHEXIT button is double clicked
function AES:form_do(tree_addr, editobj)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 1, editobj,
    k_aes_control, 4, 50, 1, 1, 1,
    k_aes_intout, 1
  )
end

-- form_dial
-- Input:
--   1) integer: type
--   2) integer: smallx
--   3) integer: smally
--   4) integer: smallw
--   5) integer: smallh
--   6) integer: largex
--   7) integer: largey
--   8) integer: largew
--   9) integer: largeh
--   NOTE: See AESDefs for type
function AES:form_dial(type, smallx, smally, smallw, smallh,
    largex, largey, largew, largeh)
  return self.pb_:call(
    k_aes_intin, 9, type, smallx, smally, smallw, smallh,
      largex, largey, largew, largeh,
    k_aes_control, 4, 51, 9, 1, 0,
    k_aes_intout, 1)
end

-- form_alert
-- Input:
--   1) integer: default exit button: 0=none, 1=first, 2=second, 3=third
--   2) string: alert text: [icon number][message text][exit button text]
-- Returns:
--   1) integer: selected button: 1=first, 2=second, 3=third
function AES:form_alert(def_exitbtn, text)
  local buffer = self.buffer_
  buffer:poke(k_u8, buffer:writes(0, text), 0)
  return self.pb_:call(
    k_aes_intin, 1, def_exitbtn,
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 52, 1, 1, 1,
    k_aes_intout, 1
  )
end

-- form_error
-- Input:
--   1) integer: dos error code
-- Returns:
--   1) integer: selected button
function AES:form_error(error_code)
  return self.pb_:call(
    k_aes_intin, 1, error_code,
    k_aes_control, 4, 53, 1, 1, 0,
    k_aes_intout, 1)
end

-- form_center
-- Input:
--   1) integer: tree_addr: tree address
-- Returns:
--   1) integer: reserved (always 1)
--   2) integer: x
--   3) integer: y
--   4) integer: width
--   5) integer: height
function AES:form_center(tree_addr)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_control, 4, 54, 0, 5, 1,
    k_aes_intout, 5
  )
end

-- form_keybd
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: object being edited
--   3) integer: keycode: from e.g. evnt_multi 
-- Returns:
--   1) integer: 0=exit obj selected, 1 = exit obj not selected
--   2) integer: new_obj: new object with edit focus or exit object
--   3) integer: key_out: value to be passed to obj_edit, or 0 if handled
function AES:form_keybd(tree_addr, obj, keycode)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 3, obj, keycode, obj,
    k_aes_control, 4, 55, 3, 3, 1,
    k_aes_intout, 3)
end

-- form_button
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: object clicked on
--   3) integer: clicks: number of mouse button clicks
-- Returns:
--   1) integer: 0=exit obj selected, 1 = exit obj not selected
--   2) integer: Number of new edit object or zero
function AES:form_button(tree_addr, obj, clicks)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 2, obj, clicks,
    k_aes_control, 4, 56, 2, 2, 1,
    k_aes_intout, 2)
end

-- graf_rubberbox
-- Input:
--   1) integer: x position
--   2) integer: y position
--   3) integer: minimum width
--   4) integer: minimum height
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: width of box
--   3) integer: height of box
function AES:graf_rubberbox(x, y, minw, minh)
  return self.pb_:call(
    k_aes_intin, 4, x, y, minw, minh,
    k_aes_control, 4, 70, 4, 3, 0,
    k_aes_intout, 3)
end

-- graf_dragbox
-- Input:
--   1) integer: box width
--   2) integer: box height
--   3) integer: begin x
--   4) integer: begin y
--   5) integer: bounding x
--   6) integer: bounding y
--   7) integer: bounding width
--   8) integer: bounding height
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: end x
--   3) integer: end y
function AES:graf_dragbox(width, height, beginx, beginy,
    boundx, boundy, boundw, boundh)
  return self.pb_:call(
    k_aes_intin, 8, width, height, beginx, beginy,
    boundx, boundy, boundw, boundh,
    k_aes_control, 4, 71, 8, 3, 0,
    k_aes_intout, 3)
end

-- graf_movebox
-- Input:
--   1) integer: width
--   2) integer: height
--   3) integer: beginx
--   4) integer: beginy
--   5) integer: endx
--   6) integer: endy
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:graf_movebox(width, height, beginx, beginy, endx, endy)
  return self.pb_:call(
    k_aes_intin, 6, width, height, beginx, beginy, endx, endy,
    k_aes_control, 4, 72, 6, 1, 0,
    k_aes_intout, 1)
end

-- graf_growbox
-- Input:
--   1) integer: small box left
--   2) integer: small box top
--   3) integer: small box width
--   4) integer: small box height
--   5) integer: large box left
--   6) integer: large box top
--   7) integer: large box width
--   8) integer: large box height
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:graf_growbox(sx, sy, sw, sh, lx, ly, lw, lh)
  return self.pb_:call(
    k_aes_intin, 8, sx, sy, sw, sh, lx, ly, lw, lh,
    k_aes_control, 4, 73, 8, 1, 0,
    k_aes_intout, 1)
end

-- graf_shrinkbox
-- Input:
--   1) integer: small box left
--   2) integer: small box top
--   3) integer: small box width
--   4) integer: small box height
--   5) integer: large box left
--   6) integer: large box top
--   7) integer: large box width
--   8) integer: large box height
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:graf_shrinkbox(sx, sy, sw, sh, lx, ly, lw, lh)
  return self.pb_:call(
    k_aes_intin, 8, sx, sy, sw, sh, lx, ly, lw, lh,
    k_aes_control, 4, 74, 8, 1, 0,
    k_aes_intout, 1
  )
end

-- graf_watchbox
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: obj: the object to watch
--   3) integer: instate: state when mouse in rectangle
--   4) integer: outstate: state when mouse out of rectangle
-- Returns:
--   1) integer: =0 pointer outside, =1 pointer inside
function AES:graf_watchbox(tree_addr, obj, instate, outstate)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 4, 0, obj, instate, outstate,
    k_aes_control, 4, 75, 4, 1, 1,
    k_aes_intout, 1)
end

-- graf_slidebox
-- Input:
--   1) integer: tree_addr: tree address
--   2) integer: parent_obj: parent object (slide bar)
--   3) integer: obj: child object (slider)
--   4) integer: orientation: =0 horizontal, =1 vertical
-- Returns:
--   1) integer: position: in range =0 left/top, =1000 right/bottom
function AES:graf_slidebox(tree_addr, parent_obj, obj, orientation)
  return self.pb_:call(
    k_aes_addrin, 1, tree_addr,
    k_aes_intin, 3, parent_obj, obj, orientation,
    k_aes_control, 4, 76, 3, 1, 1,
    k_aes_intout, 1)
end

-- graf_handle
-- Returns:
--   1) integer: physical workstation handle
--   2) integer: wcel
--   3) integer: hcel
--   4) integer: wbox
--   5) integer: hbox
function AES:graf_handle()
  return self.pb_:call(
    k_aes_control, 4, 77, 0, 5, 0,
    k_aes_intout, 5)
end

-- graf_mouse
-- Input:
--   1) integer: form number
--   2) integer: hot spot x position
--   3) integer: hot spot y position
--   4) integer: bg pen
--   5) integer: fg pen
--   6) table: table of 16 words for mask as integers
--   7) table: table of 16 words for data as integers
--   NOTE: See AESDefs for mouse forms
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:graf_mouse(form_no, xhot, yhot, bg, fg, mask, data)
  local address
  local <const> grmo_user_def = 255
  if form_no == grmo_user_def then
    assert(#mask == 16 and #data == 16)
    local <const> buffer = self.buffer_
    local offset = buffer:poke(k_s16, 0, xhot, yhot, 1, bg, fg)
    offset = offset + buffer:writet(k_u16, offset, mask)
    buffer:writet(k_u16, offset, data)
    address = self.buffer_addr_
  else
    address = 0
  end

  return self.pb_:call(
    k_aes_intin, 1, form_no,
    k_aes_addrin, 1, address,
    k_aes_control, 4, 78, 1, 1, 1,
    k_aes_intout, 1)
end

-- graf_mkstate
-- Returns:
--   1) integer: reserved (always 1)
--   2) integer: mouse x
--   3) integer: mouse y
--   4) integer: button state
--   5) integer: shift key state
--   NOTE: See AESDefs for state constants
function AES:graf_mkstate()
  return self.pb_:call(
    k_aes_control, 4, 79, 0, 5, 0,
    k_aes_intout, 5)
end

-- scrp_read
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) string: directory path
function AES:scrp_read()
  local <const> status =
    self.pb_:call(
      k_aes_addrin, 1, self.buffer_addr_,
      k_aes_control, 4, 80, 0, 1, 1,
      k_aes_intout, 1)
  return status, status > 0 and self.buffer_:reads(0, nil, 0) or ""
end

-- scrp_write
-- Input:
--   1) string: the directory path
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:scrp_write(scrap_dir)
  local <const> buffer = self.buffer_
  buffer:writes(0, scrap_dir .. "\0")
  return self.pb_:call(
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 81, 0, 1, 1,
    k_aes_intout, 1)
end

-- fsel_input
-- Input:
--   1) string: path
--   2) string: file
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: 0 = cancel, 1 = okay
--   3) string: selected path
--   4) string: selected file
function AES:fsel_input(path, file)
  local buffer = self.buffer_
  local <const> max_len, off_path = buffer:size() >> 1, 0
  local <const> off_file = off_path + max_len

  assert(#path < max_len)
  assert(#file < max_len)
  buffer:writes(off_path, path .. "\0")
  buffer:writes(off_file, file .. "\0")

  local <const> addr = self.buffer_addr_
  local <const> status, exitbutn =
    self.pb_:call(
      k_aes_addrin, 2, addr + off_path, addr + off_file,
      k_aes_control, 4, 90, 0, 2, 2,
      k_aes_intout, 2)

  local sel_path, sel_file
  if status > 0 then
    sel_path = buffer:reads(off_path, nil, 0)
    sel_file = buffer:reads(off_file, nil, 0)
  else
    sel_path = ""
    sel_file = ""
  end

  return status, exitbutn, sel_path, sel_file
end

-- fsel_exinput
-- Input:
--   1) string: path
--   2) string: file
--   3) string: title
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: 0 = cancel, 1 = okay
--   3) string: selected path
--   4) string: selected file
function AES:fsel_exinput(path, file, title)
  local <const> pb, buffer = self.pb_,self.buffer_
  local <const> max_len, off_path = buffer:size() >> 2, 0
  local <const> off_file = off_path + max_len
  local <const> off_title = off_file + max_len
  local <const> aes_ver = pb:peek(k_aes_global, 0)

  assert(aes_ver >= 320)
  assert(#path < max_len)
  assert(#file < max_len)
  assert(#title < max_len)
  buffer:writes(off_path, path .. "\0")
  buffer:writes(off_file, file .. "\0")
  buffer:writes(off_title, title .. "\0")

  local <const> addr = self.buffer_addr_
  local <const> status, exitbutn =
    self.pb_:call(
      k_aes_addrin, 3, addr + off_path, addr + off_file, addr + off_title,
      k_aes_control, 4, 91, 0, 2, 3,
      k_aes_intout, 2)

  local sel_path, sel_file
  if status > 0 then
    sel_path = buffer:reads(off_path, nil, 0)
    sel_file = buffer:reads(off_file, nil, 0)
  else
    sel_path = ""
    sel_file = ""
  end

  return status, exitbutn, sel_path, sel_file
end

-- fsel_wrapper. Checks title parameter and AES version and calls either
-- fsel_input or fsel_exinput.
-- Input:
--   1) string: path
--   2) string: file
--   3) optional string: title
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: 0 = cancel, 1 = okay
--   3) string: selected path
--   4) string: selected file
function AES:fsel_wrapper(path, file, title)
  local <const> aes_ver = self.pb_:peek(k_aes_global, 0)
  if title and aes_ver >= 320 then
    return self:fsel_exinput(path, file, title)
  end
  return self:fsel_input(path, file)
end

-- wind_create
-- Input:
--   1) integer: bit combination of window controls
--   2) integer: left edge of maximised window
--   3) integer: top edge of maximised window 
--   4) integer: width of maximised window
--   5) integer: height of maximised window
--   NOTE: See AESDefs for window control bits
-- Returns:
--   1) integer: window handle, negative on error
function AES:wind_create(controls, fullx, fully, fullw, fullh)
  return self.pb_:call(
    k_aes_intin, 5, controls, fullx, fully, fullw, fullh,
    k_aes_control, 4, 100, 5, 1, 0,
    k_aes_intout, 1)
end

-- wind_open
-- Input:
--   1) integer: window handle
--   2) integer: left position of window
--   3) integer: top position of window
--   4) integer: width of window in pixels
--   5) integer: height of window in pixels
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:wind_open(wi_handle, x, y, width, height)
  return self.pb_:call(
    k_aes_intin, 5, wi_handle, x, y, width, height,
    k_aes_control, 4, 101, 5, 1, 0,
    k_aes_intout, 1)
end

-- wind_close
-- Input:
--   1) integer: window handle
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:wind_close(wi_handle)
  return self.pb_:call(
    k_aes_intin, 1, wi_handle,
    k_aes_control, 4, 102, 1, 1, 0,
    k_aes_intout, 1)
end

-- wind_close
-- Input:
--   1) integer: window handle
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:wind_delete(wi_handle)
  return self.pb_:call(
    k_aes_intin, 1, wi_handle,
    k_aes_control, 4, 103, 1, 1, 0,
    k_aes_intout, 1)
end

-- wind_get
-- Input:
--   1) integer: window handle
--   2) integer: mode
--   NOTE: See AESDefs for modes
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: x
--   3) integer: y
--   4) integer: w
--   5) integer: h
function AES:wind_get(wi_handle, mode)
  return self.pb_:call(
    k_aes_intin, 2, wi_handle, mode,
    k_aes_control, 4, 104, 2, 5, 0,
    k_aes_intout, 5)
end

-- wind_set
-- Input:
--   1) integer: window handle
--   2) integer: mode
--   3) integer: x
--   4) optional integer: y (default 0)
--   5) optional integer: w (default 0)
--   6) optional integer: h (default 0)
--   NOTE: See AESDefs for modes
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:wind_set(wi_handle, mode, x, y, w, h)
  return self.pb_:call(
    k_aes_intin, 6, wi_handle, mode, x, y or 0, w or 0, h or 0,
    k_aes_control, 4, 105, 6, 1, 0,
    k_aes_intout, 1)
end

-- wind_find
-- Input:
--   1) integer: x
--   2) integer: y
-- Returns:
--   1) integer: window handle
function AES:wind_find(x, y)
  return self.pb_:call(
    k_aes_intin, 2, x, y,
    k_aes_control, 4, 106, 2, 1, 0,
    k_aes_intout, 1)
end

-- wind_update
-- Input:
--   1) integer: code
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:wind_update(code)
  return self.pb_:call(
    k_aes_intin, 1, code,
    k_aes_control, 4, 107, 1, 1, 0,
    k_aes_intout, 1)
end

-- wind_calc
-- Input:
--   1) integer: type
--   2) integer: controls
--   3) integer: x
--   4) integer: y
--   5) integer: w
--   6) integer: h
--   NOTE: See AESDefs for type and controls
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: calculated x
--   3) integer: calculated y
--   4) integer: calculated w
--   5) integer: calculated h
function AES:wind_calc(type, controls, x, y, w, h)
  return self.pb_:call(
    k_aes_intin, 6, type, controls, x, y, w, h,
    k_aes_control, 4, 108, 6, 5, 0,
    k_aes_intout, 5)
end

-- rsrc_load
-- Input:
--   1) string: filename of resource
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:rsrc_load(fname)
  local <const> buffer = self.buffer_
  buffer:poke(k_u8, buffer:writes(0, fname), 0)
  return self.pb_:call(
    k_aes_addrin, 1, self.buffer_addr_,
    k_aes_control, 4, 110, 0, 1, 1,
    k_aes_intout, 1)
end

-- rsrc_free
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:rsrc_free()
  return self.pb_:call(
    k_aes_control, 4, 111, 0, 1, 0,
    k_aes_intout, 1)
end

-- rsrc_gaddr
-- Input:
--   1) integer: type of resource element containing address
--   2) integer: index of element to read
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) integer: address within the element
function AES:rsrc_gaddr(type, index)
  return self.pb_:call(
    k_aes_intin, 2, type, index,
    k_aes_control, 5, 112, 2, 1, 0, 1,
    k_aes_intout, 1,
    k_aes_addrout, 1
  )
end

-- shel_read. Read application parent and command tail
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) string: command
--   3) string: tail
function AES:shel_read()
  local <const> buffer, buffer_addr =
    self.buffer_, self.buffer_addr_
  local max_len <const> = k_buffer_size >> 1

  buffer:poke(k_u8, max_len, 0)
  local <const> status =
    self.pb_:call(
      k_aes_addrin, 2, buffer_addr, buffer_addr + max_len,
      k_aes_control, 4, 120, 0, 1, 2,
      k_aes_intout, 1)

  local command
  local tail
  if status > 0 then
    command = buffer:reads(0, nil, 0)
    tail = buffer:reads(max_len + 1, buffer:peek(k_u8, max_len))
  else
    command = ""
    tail = ""
  end

  return status, command, tail
end

-- shel_write_chain. Chain application launch
-- Inputs:
--   1) integer: isgr: 0 = tos application, 1 = gem application
--   2) string: command
--   3) string: tail
--   Note: See AESDefs for isgr
-- Returns:
--   1) integer: >0 on success, 0 on error
function AES:shel_write_chain(isgr, cmd, tail)
  local <const> tosapp, gemapp = 0, 1
  assert(isgr == tosapp or isgr == gemapp)
  local <const> wodex_launchnow, wiscr_chain = 1, 1
  local <const> buffer, buffer_addr, max_len =
    self.buffer_, self.buffer_addr_, k_buffer_size >> 1
  buffer:poke(k_u8, buffer:writes(0, cmd), 0)
  buffer:poke(k_u8, max_len, #tail)
  buffer:writes(max_len + 1, tail .. "\0")
  return self.pb_:call(
    k_aes_intin, 3, wodex_launchnow, isgr, wiscr_chain,
    k_aes_addrin, 2, buffer_addr, buffer_addr + max_len,
    k_aes_control, 4, 121, 3, 1, 2,
    k_aes_intout, 1)
end

-- shel_find. Search for a filename
-- Input:
--   1) string: filename
-- Returns:
--   1) integer: >0 on success, 0 on error
--   2) string: file path
function AES:shel_find(filename)
  local <const> buffer = self.buffer_
  buffer:poke(k_u8, buffer:writes(0, filename), 0)
  local <const> status =
    self.pb_:call(
      k_aes_addrin, 1, self.buffer_addr_,
      k_aes_control, 4, 124, 0, 1, 1,
      k_aes_intout, 1)
  return status, status > 0 and buffer:reads(0, nil, 0) or ""
end

-- shel_envrn. Search for environment string
-- Input:
--   1) string: name of environment string
-- Returns:
--   1) optional string: Value of environment string, otherwise nil
function AES:shel_envrn(name)
  local <const> buffer, buffer_addr = self.buffer_, self.buffer_addr_
  buffer:poke(k_u8, buffer:poke(k_s32, 0, 0) + buffer:writes(4, name), 0)
  self.pb_:call(
    k_aes_addrin, 2, buffer_addr, buffer_addr + 4,
    k_aes_control, 4, 125, 0, 1, 2)
  local <const> addr = buffer:peek(k_s32, 0)
  local value
  if addr ~= 0 then
    value = k_wrapm(addr & -2, 1024):reads(addr & 1, nil, 0)
  end
  return value
end

return AES
