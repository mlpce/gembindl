global assert, setmetatable, require, gemdos, gempb, warn

local <const> k_allocm = gemdos.utility.allocm
local <const> k_u8 = gemdos.const.Imode.u8
local <const> k_aes_global = gempb.const.Pbid.aes_global

local <const> k_WindRefs = require("gembindl.utility.windrefs")

local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_wicr_name = aesdefs.wicr_name
local <const> k_wicr_info = aesdefs.wicr_info
local <const> k_wicr_vslide = aesdefs.wicr_vslide
local <const> k_wicr_hslide = aesdefs.wicr_hslide
local <const> k_wise_name = aesdefs.wise_name
local <const> k_wise_info = aesdefs.wise_info
local <const> k_wise_top = aesdefs.wise_top
local <const> k_wise_vslsize = aesdefs.wise_vslsize
local <const> k_wise_hslsize = aesdefs.wise_hslsize
local <const> k_wige_vslsize = aesdefs.wige_vslsize
local <const> k_wige_hslsize = aesdefs.wige_hslsize
local <const> k_wige_top = aesdefs.wige_top
local <const> k_wise_vslide = aesdefs.wise_vslide
local <const> k_wise_hslide = aesdefs.wise_hslide
local <const> k_wise_top = aesdefs.wise_top
local <const> k_wige_vslide = aesdefs.wige_vslide
local <const> k_wige_hslide = aesdefs.wige_hslide
local <const> k_wige_currxywh = aesdefs.wige_currxywh
local <const> k_wige_workxywh = aesdefs.wige_workxywh
local <const> k_wige_prevxywh = aesdefs.wige_prevxywh
local <const> k_wige_fullxywh = aesdefs.wige_fullxywh
local <const> k_evme_wm_closed = aesdefs.evme_wm_closed
local <const> k_evme_wm_fulled = aesdefs.evme_wm_fulled
local <const> k_evme_wm_sized = aesdefs.evme_wm_sized
local <const> k_evme_wm_moved = aesdefs.evme_wm_moved
local <const> k_evme_wm_redraw = aesdefs.evme_wm_redraw
local <const> k_evme_wm_topped = aesdefs.evme_wm_topped
local <const> k_evme_wm_vslid = aesdefs.evme_wm_vslid
local <const> k_evme_wm_hslid = aesdefs.evme_wm_hslid
local <const> k_evme_wm_arrowed = aesdefs.evme_wm_arrowed
local <const> k_evme_wm_untopped = aesdefs.evme_wm_untopped
local <const> k_wige_firstxywh = aesdefs.wige_firstxywh
local <const> k_wige_nextxywh = aesdefs.wige_nextxywh
local <const> k_wise_currxywh = aesdefs.wise_currxywh
local <const> k_grmo_m_off = aesdefs.grmo_m_off
local <const> k_grmo_m_on = aesdefs.grmo_m_on
local <const> k_wiup_beg_update = aesdefs.wiup_beg_update
local <const> k_wiup_end_update = aesdefs.wiup_end_update
local <const> k_wica_work = aesdefs.wica_work
local <const> k_wica_border = aesdefs.wica_border
aesdefs = nil

local <const> Wind = {}

local function min(a, b) return a < b and a or b end
local function max(a, b) return a > b and a or b end

-- rcintersect. Compute intersection of two rectangles
-- Inputs:
--   1) integer: x1
--   2) integer: y1
--   3) integer: w1
--   4) integer: h1
--   5) integer: x2
--   6) integer: y2
--   7) integer: w2
--   8) integer: h2
-- Returns:
--   1) boolean: true if intersected
--   2) integer: intersected x
--   3) integer: intersected y
--   4) integer: intersected w
--   5) integer: intersected h
function Wind.rcintersect(x1, y1, w1, h1, x2, y2, w2, h2)
  local <const> tw = min(x2 + w2, x1 + w1)
  local <const> th = min(y2 + h2, y1 + h1)
  local <const> tx = max(x2, x1)
  local <const> ty = max(y2, y1)
  return tw > tx and th > ty, tx, ty, tw - tx, th - ty
end

-- rcconstrain. Constrain rectangle 2 within rectangle 1 by
-- adjusting x and y
-- Inputs:
--   1) integer: x1
--   2) integer: y1
--   3) integer: w1
--   4) integer: h1
--   5) integer: x2
--   6) integer: y2
--   7) integer: w2
--   8) integer: h2
-- Returns:
--   1) integer: constrained x
--   2) integer: constrained y
--   3) integer: constrained w
--   4) integer: constrained h
function Wind.rcconstrain(x1, y1, w1, h1, x2, y2, w2, h2)
  if x2 < x1 then x2 = x1 end
  if y2 < y1 then y2 = y1 end
  local <const> r1 = x1 + w1
  if x2 + w2 > r1 then x2 = r1 - w2 end
  local <const> b1 = y1 + h1
  if y2 + h2 > b1 then y2 = b1 - h2 end

  -- Return constrained coordinates of rectangle 2
  return x2, y2, w2, h2
end

-- rcequal. Determines if two rectanges are equal
-- Inputs:
--   1) integer: x1
--   2) integer: y1
--   3) integer: w1
--   4) integer: h1
--   5) integer: x2
--   6) integer: y2
--   7) integer: w2
--   8) integer: h2
-- Returns:
--   1) boolean: true if equal
function Wind.rcequal(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 == x2 and y1 == y2 and w1 == w2 and h1 == h2
end

-- rcalign. Align work area by changing border coordinates
-- Input:
--   1) integer: controls
--   2) integer: x
--   3) integer: y
--   4) integer: w
--   5) integer: h
function Wind:rcalign_(x, y, w, h)
  local astatus, ax, ay, aw, ah =
    self.aes_:wind_calc(k_wica_work, self.controls_,
      x, y, w, h)
  assert(astatus > 0)

  ax = (ax + 7) & (-16)

  astatus, ax, ay, aw, ah =
    self.aes_:wind_calc(k_wica_border, self.controls_,
      ax, ay, aw, ah)
  assert(astatus > 0)

  if ax < 0 then ax = 0 end
  return ax, ay, aw, ah
end

-- new. Create a new Wind
-- Inputs:
--   1) table: aes table
--   2) table: vdi table
--   3) table: table to use for Wind instance otherwise nil
-- Returns:
--   1) table: the Wind instance
function Wind:new(aes, vdi, o)
  o = o or {}
  o.aes_ = aes
  o.vdi_ = vdi
  o.ap_id_ = aes:pb():peek(k_aes_global, 2)
  o.wi_handle_ = -1
  o.controls_ = 0
  o.open_ = false
  self.__index = self

  -- Cleanup function
  local function cleanup(w)
    if w.wi_handle_ == -1 then return end
    if w.open_ then w:close() end
    w:delete()
  end

  self.__gc = cleanup
  self.__close = cleanup
  return setmetatable(o, self)
end

-- handle. Obtains the window handle
-- Returns:
--   1) integer: the window handle, otherwise -1 if not valid
function Wind:handle()
  return self.wi_handle_
end

-- is_open. Returns true if the window is open
-- Returns:
--   1) boolean: true if the window is open
function Wind:is_open()
  return self.open_
end

-- create. Create a window
-- Inputs:
--   1) integer: controls
--   2) integer: fullx
--   3) integer: fully
--   4) integer: fullw
--   5) integer: fullh
-- Returns:
--   1) boolean: true on success
function Wind:create(controls, fullx, fully, fullw, fullh)
  assert(self.wi_handle_ == -1)

  -- get work area of desktop window
  local status
  status, self.deskx_, self.desky_, self.deskw_, self.deskh_ =
    self.aes_:wind_get(0, k_wige_workxywh)
  assert(status > 0)

  -- Constrain full window rectangle to desktop work area
  fullx, fully, fullw, fullh = self.rcconstrain(
    self.deskx_, self.desky_, self.deskw_, self.deskh_,
    fullx, fully, fullw, fullh)

  -- Full window rectangle
  self.fx_, self.fy_, self.fw_, self.fh_ =
    fullx, fully, fullw, fullh

  -- If needed allocate muds for name and info
  local created = self:create_muds_(controls)
  if not created then
    return false
  end

  -- Create the window
  local <const> wi_handle = self.aes_:wind_create(
    controls, fullx, fully, fullw, fullh)
  if wi_handle < 0 then
    return false
  end

  self.wi_handle_ = wi_handle
  self.controls_ = controls
  self.open_ = false

  -- Add the created Wind to the refs
  k_WindRefs:add_wind(self)

  return true
end

-- open. Open the window
-- Inputs:
--   1) integer: x
--   2) integer: y
--   3) integer: w
--   4) integer: h
-- Returns:
--   1) boolean: true on success
function Wind:open(x, y, w, h)
  assert(self.wi_handle_ ~= -1)
  assert(not self.open_)
  assert(self.view_)

  -- Get the handle of the top window
  local <const> status, top_wind_h =
    self.aes_:wind_get(self.wi_handle_, k_wige_top)
  assert(status > 0)

  -- Get the Wind for the top window. It might be a desk accessory
  -- in which case get_wind will return nil
  local <const> top_wind = k_WindRefs:get_wind(top_wind_h)
  local top_wind_view
  if top_wind then
    -- untop the view of the top window e.g. to hide edit box cursor
    top_wind_view = top_wind:view()
    top_wind_view:view_untopped(top_wind)
  end

  local <const> ax, ay, aw, ah = self:rcalign_(x, y, w, h)
  local <const> opened =
    self.aes_:wind_open(self.wi_handle_, ax, ay, aw, ah) > 0
  if opened then
    -- Notify view of open
    self.view_:view_open(self)

    -- Notify view of workxywh
    local <const> wstatus, wx, wy, ww, wh =
      self.aes_:wind_get(self.wi_handle_, k_wige_workxywh)
    assert(wstatus > 0)
    self.view_:view_workxywh(self, wx, wy, ww, wh)
  else
    warn("Wind:open: wind_open failed")
    -- open failed. Retop the original top window view.
    if top_wind_view then
      -- Set it as topped
      top_wind_view:view_topped(top_wind, true)
      -- Send redraw to e.g. show edit box cursor
      top_wind_view:view_send_redraw()
    end
  end
  self.open_ = opened
  return opened
end

-- set_name. Set the name of the window
-- Inputs:
--   1) string: name of the window
function Wind:set_name(name)
  assert(self.wi_handle_ ~= -1 and self.controls_ & k_wicr_name ~= 0)
  local <const> mud = self.name_mud_
  local <const> aname = mud:address()
  mud:poke(k_u8, mud:writes(0, name), 0)
  return self.aes_:wind_set(self.wi_handle_, k_wise_name,
    (aname >> 16) & 0xFFFF, aname & 0xFFFF, 0, 0)
end

-- set_info. Set the info of the window
-- Inputs:
--   1) string: info of the window
function Wind:set_info(info)
  assert(self.wi_handle_ ~= -1 and self.controls_ & k_wicr_info ~= 0)
  local <const> mud = self.info_mud_
  local <const> ainfo = mud:address()
  mud:poke(k_u8, mud:writes(0, info), 0)
  return self.aes_:wind_set(self.wi_handle_, k_wise_info,
    (ainfo >> 16) & 0xFFFF, ainfo & 0xFFFF, 0, 0)
end

-- set_top. Sets the window as the top window
function Wind:set_top()
  assert(self.wi_handle_ ~= -1)
  local <const> ap_id = self.ap_id_
  return self.aes_:appl_write_v(
    ap_id, -- destination application id
    k_evme_wm_topped, -- message type
    ap_id, -- sender application id,
    self.wi_handle_, 0, 0, 0, 0)
end

-- top_handle. Gets the top window handle
-- Returns:
--   1) integer: the top window handle
function Wind:top_handle()
  assert(self.wi_handle_ ~= -1)
  local <const> status, top_wind_h =
    self.aes_:wind_get(self.wi_handle_, k_wige_top)
  assert(status > 0)
  return top_wind_h
end

-- set_vslsize. Set the size of the vertical slider
-- Input:
--   1) integer: size: the size of the slider (between 1 and 1000)
function Wind:set_vslsize(size)
  assert(self.wi_handle_ ~= -1 and self.controls_ & k_wicr_vslide ~= 0)
  return self.aes_:wind_set(self.wi_handle_,
    k_wise_vslsize, min(max(size, 1), 1000), 0, 0, 0)
end

-- set_hslsize. Set the size of the horizontal slider
-- Input:
--   1) integer: size: the size of the slider (between 1 and 1000)
function Wind:set_hslsize(size)
  assert(self.wi_handle_ ~= -1 and self.controls_ & k_wicr_hslide ~= 0)
  return self.aes_:wind_set(self.wi_handle_,
    k_wise_hslsize, min(max(size, 1), 1000), 0, 0, 0)
end

-- set_vslsize. Set position of the vertical slider
-- Input:
--   1) integer: pos: the position of the slider (between 0 and 1000)
function Wind:set_vslpos(pos)
  assert(self.wi_handle_ ~= -1 and self.controls_ & k_wicr_vslide ~= 0)
  return self.aes_:wind_set(self.wi_handle_,
    k_wise_vslide, min(max(pos, 0), 1000), 0, 0, 0)
end

-- set_hslsize. Set position of the horizontal slider
-- Input:
--   1) integer: pos: the position of the slider (between 0 and 1000)
function Wind:set_hslpos(pos)
  assert(self.wi_handle_ ~= -1 and self.controls_ & k_wicr_hslide ~= 0)
  return self.aes_:wind_set(self.wi_handle_,
    k_wise_hslide, min(max(pos, 0), 1000), 0, 0, 0)
end

-- redraw. Sends a redraw mesag for the window
-- Input:
--   1) integer: x
--   2) integer: y
--   3) integer: w
--   4) integer: h
function Wind:send_redraw(x, y, w, h)
  assert(self.wi_handle_ ~= -1)
  -- If window not open then nothing to redraw
  if not self.open_ then
    return
  end

  -- Constrain the damage rectangle
  x, y, w, h = self.rcconstrain(
    self.deskx_, self.desky_, self.deskw_, self.deskh_,
    x, y, w, h)

  local <const> ap_id = self.ap_id_
  return self.aes_:appl_write_v(
    ap_id, -- destination application id
    k_evme_wm_redraw, -- message type
    ap_id, -- sender application id,
    self.wi_handle_, x, y, w, h)
end

-- close. Close the window
-- Returns:
--   1) boolean: true on success
function Wind:close()
  assert(self.wi_handle_ ~= -1)
  if self.open_ and self.aes_:wind_close(self.wi_handle_) > 0 then
    self.open_ = false
    self.view_:view_close(self)
  end
  return not self.open_
end

-- delete. Delete the window
-- Returns:
--   1) boolean: true on success
function Wind:delete()
  assert(self.wi_handle_ ~= -1)
  assert(not self.open_)
  local <const> deleted = self.aes_:wind_delete(self.wi_handle_) > 0
  if deleted then
    -- Remove the deleted wind from the refs
    k_WindRefs:remove_wind(self)

    -- Free muds
    self:destroy_muds_()

    self.wi_handle_ = -1
    self.wi_controls_ = 0
  end
  return deleted
end

-- set_view. Sets the window's view
-- Inputs:
--   1) table: the window's view
--   NOTE: the table must implement view functions
function Wind:set_view(view)
  self.view_ = view
end

-- view. Gets the window's view
-- Returns:
--   1) table: the view
function Wind:view()
  return self.view_
end

-- Dispatches mesag to handler
-- Inputs:
--   varag: mesag
function Wind:dispatch(mesag)
  return self.mesag_fn_[mesag[1]](self, mesag)
end

-- Create muds for name and info
function Wind:create_muds_(controls)
  local <const> mud_size = 80
  local ec = 0

  -- name mud
  if controls & k_wicr_name ~= 0 then
    ec, self.name_mud_ = k_allocm(mud_size)
  end
  if ec < 0 then
    return false
  end

  -- info mud
  if controls & k_wicr_info ~= 0 then
    ec, self.info_mud_ = k_allocm(mud_size)
  end
  if ec < 0 then
    return false
  end

  -- muds created
  self.controls_ = controls
  return true
end

-- Destroy muds for name and info
function Wind:destroy_muds_()
  local <const> controls = self.controls_
  if controls & k_wicr_name ~= 0 then
    self.name_mud_:free()
    self.name_mud_ = nil
  end
  if controls & k_wicr_info ~= 0 then
    self.info_mud_:free()
    self.info_mud_ = nil
  end
end

-- Process closed mesag
function Wind:do_closed_mesag_(mesag)
  if mesag[4] ~= self.wi_handle_ then
    return
  end
  if not self.view_:view_preclose(self) then
    return
  end

  return self:close()
end

-- Process fulled mesag
function Wind:do_fulled_mesag_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end

  -- Get current, previous and full coordinates
  local <const> cstatus, cx, cy, cw, ch =
    self.aes_:wind_get(wi_handle, k_wige_currxywh)
  local <const> pstatus, px, py, pw, ph =
    self.aes_:wind_get(wi_handle, k_wige_prevxywh)
  local <const> fstatus, fx, fy, fw, fh =
    self.aes_:wind_get(wi_handle, k_wige_fullxywh)
  assert(cstatus > 0 and pstatus > 0 and fstatus > 0)

  if self.rcequal(cx, cy, cw, ch, fx, fy, fw, fh) then
    -- Currently full so shrink to previous
    self.aes_:graf_shrinkbox(px, py, pw, ph, fx, fy, fw, fh)
    self.aes_:wind_set(wi_handle, k_wise_currxywh, px, py, pw, ph)
  else
    -- Currently not full so grow to full
    self.aes_:graf_growbox(cx, cy, cw, ch, fx, fy, fw, fh)
    self.aes_:wind_set(wi_handle, k_wise_currxywh, fx, fy, fw, fh)
  end

  -- Notify view of workxywh
  local <const> wstatus, wx, wy, ww, wh =
    self.aes_:wind_get(wi_handle, k_wige_workxywh)
  assert(wstatus > 0)
  return self.view_:view_sized(self, wx, wy, ww, wh)
end

-- Process sized mesag
function Wind:do_sized_mesag_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end

  -- Set the window size
  self.aes_:wind_set(wi_handle, k_wise_currxywh,
    mesag[5], mesag[6], mesag[7], mesag[8])

  -- Notify view of workxywh
  local <const> wstatus, wx, wy, ww, wh =
    self.aes_:wind_get(wi_handle, k_wige_workxywh)
  assert(wstatus > 0)
  return self.view_:view_sized(self, wx, wy, ww, wh)
end

-- Process moved mesag
function Wind:do_moved_mesag_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end

  local <const> ax, ay, aw, ah =
    self:rcalign_(mesag[5], mesag[6], mesag[7], mesag[8])
  self.aes_:wind_set(wi_handle,
    k_wise_currxywh, ax, ay, aw, ah)

  -- Notify view of workxywh
  local <const> wstatus, wx, wy, ww, wh =
    self.aes_:wind_get(wi_handle, k_wige_workxywh)
  assert(wstatus > 0)
  return self.view_:view_workxywh(self, wx, wy, ww, wh)
end

-- Process redraw mesag
function Wind:do_redraw_mesag_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end

  -- Damage rectangle
  local <const> dx, dy, dw, dh =
    mesag[5], mesag[6], mesag[7], mesag[8]

  -- Full screen rectangle
  local <const> fx, fy, fw, fh =
    self.fx_, self.fy_, self.fw_, self.fh_

  -- Turn mouse off and begin update
  local <const> aes = self.aes_
  aes:graf_mouse(k_grmo_m_off)
  aes:wind_update(k_wiup_beg_update)

  -- First window rectangle
  local <const> view = self.view_
  local <const> rcintersect = self.rcintersect
  local status, x, y, w, h =
    aes:wind_get(wi_handle, k_wige_firstxywh)
  while status > 0 and w > 0 and h > 0 do
    -- Intersect full screen rectangle against window rectangle
    local intersect
    intersect, x, y, w, h =
      rcintersect(fx, fy, fw, fh, x, y, w, h)
    if intersect then
      -- Intersect damage rectangle against window rectangle
      intersect, x, y, w, h =
        rcintersect(dx, dy, dw, dh, x, y, w, h)
      if intersect then
        -- Draw the view
        view:view_draw(self, x, y, w, h)
      end
    end

    -- Next window rectangle
    status, x, y, w, h =
      aes:wind_get(wi_handle, k_wige_nextxywh)
  end

  -- End update and turn mouse on
  aes:wind_update(k_wiup_end_update)
  return aes:graf_mouse(k_grmo_m_on)
end

-- Process topped message
function Wind:do_wm_topped_(mesag)
  local <const> wi_handle = self.wi_handle_
  local <const> is_topped = mesag[4] == wi_handle

  self.view_:view_topped(self, is_topped)
  if not is_topped then
    return
  end

  return self.aes_:wind_set(wi_handle, k_wise_top, 0, 0, 0, 0)
end

-- Process untopped message. This is sent by EmuTOS but not
-- TOS 1.04. Useful for detecting when the top window has been
-- untopped by a desk accessory window - e.g. the view may need
-- to undraw an edit box cursor.
function Wind:do_wm_untopped_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end

  self.view_:view_untopped(self)
end

-- Process vertical slider
function Wind:do_wm_vslid_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end
  return self.view_:view_vslid(self, mesag[5])
end

-- Process horizontal slider
function Wind:do_wm_hslid_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end
  return self.view_:view_hslid(self, mesag[5])
end

function Wind:do_wm_arrowed_(mesag)
  local <const> wi_handle = self.wi_handle_
  if mesag[4] ~= wi_handle then
    return
  end
  return self.view_:view_arrowed(self, mesag[5])
end

-- Function dispatch table for mesag
Wind.mesag_fn_ = {
  [k_evme_wm_closed] = Wind.do_closed_mesag_,
  [k_evme_wm_fulled] = Wind.do_fulled_mesag_,
  [k_evme_wm_sized] = Wind.do_sized_mesag_,
  [k_evme_wm_moved] = Wind.do_moved_mesag_,
  [k_evme_wm_redraw] = Wind.do_redraw_mesag_,
  [k_evme_wm_topped] = Wind.do_wm_topped_,
  [k_evme_wm_vslid] = Wind.do_wm_vslid_,
  [k_evme_wm_hslid] = Wind.do_wm_hslid_,
  [k_evme_wm_arrowed] = Wind.do_wm_arrowed_,
  [k_evme_wm_untopped] = Wind.do_wm_untopped_
}

local <const> unhandled = function() end
setmetatable(Wind.mesag_fn_,
  { __index = function(t, k) return unhandled end })

return Wind
