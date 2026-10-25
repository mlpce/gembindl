global assert, require, gempb, gemdos, ipairs, setmetatable, table

local <const> WindRefs = require("gembindl.utility.windrefs")
local <const> AES = require("gembindl.aes")
local <const> VDI = require("gembindl.vdi")
local <const> Wind = require("gembindl.utility.wind")
local <const> aesdefs = require("gembindl.utility.defs.aesdefs")
local <const> k_evme_wm_topped = aesdefs.evme_wm_topped
local <const> k_evme_wm_redraw = aesdefs.evme_wm_redraw
local <const> k_evme_wm_sized = aesdefs.evme_wm_sized
local <const> k_evme_wm_moved = aesdefs.evme_wm_moved
local <const> k_evme_wm_fulled = aesdefs.evme_wm_fulled
local <const> k_evme_wm_untopped = aesdefs.evme_wm_untopped
local <const> k_evme_wm_arrowed = aesdefs.evme_wm_arrowed
local <const> k_evme_wm_vslid = aesdefs.evme_wm_vslid
local <const> k_evme_wm_hslid = aesdefs.evme_wm_hslid
local <const> k_wige_workxywh = aesdefs.wige_workxywh
local <const> k_wige_currxywh = aesdefs.wige_currxywh

local <const> k_wmar_pageup = aesdefs.wmar_pageup
local <const> k_wmar_pagedown = aesdefs.wmar_pagedown
local <const> k_wmar_lineup = aesdefs.wmar_lineup
local <const> k_wmar_linedown = aesdefs.wmar_linedown
local <const> k_wmar_pageleft = aesdefs.wmar_pageleft
local <const> k_wmar_pageright = aesdefs.wmar_pageright
local <const> k_wmar_columnleft = aesdefs.wmar_columnleft
local <const> k_wmar_columnright = aesdefs.wmar_columnright

-- Each Wind has a view
local test_view = {
}

function test_view:new(o)
  o = o or {}
  o.res = {
  }
  self.__index = self
  return setmetatable(o, self)
end

function test_view:clear_results()
  self.res = {}
end

function test_view:view_modal_override(wind, override)
  self.res.wind = wind
  self.res.override = override
end

function test_view:view_preclose(wind)
  self.res.wind = wind
end

function test_view:view_close(wind)
  self.res.wind = wind
  self.res.open = false
end

function test_view:view_draw(wind, x, y, w, h)
  self.res.wind = wind
  self.res.drawx = x
  self.res.drawy = y
  self.res.draww = w
  self.res.drawh = h
end

function test_view:view_open(wind)
  self.res.wind = wind
  self.res.open = true
end

function test_view:view_sized(wind, wx, wy, ww, wh)
  self.res.wind = wind
  self.res.workwx = wx
  self.res.workwy = wy
  self.res.workww = ww
  self.res.workwh = wh
end

function test_view:view_workxywh(wind, wx, wy, ww, wh)
  self.res.wind = wind
  self.res.workwx = wx
  self.res.workwy = wy
  self.res.workww = ww
  self.res.workwh = wh
end

function test_view:view_topped(wind, is_topped)
  self.res.wind = wind
  self.res.is_topped = is_topped
end

function test_view:view_untopped(wind)
  self.res.wind = wind
  self.res.is_topped = false
end

function test_view:view_arrowed(wind, action)
  self.res.wind = wind
  self.res.arrowed = action
end

function test_view:view_vslid(wind, pos)
  self.res.wind = wind
  self.res.vslid = pos
end

function test_view:view_hslid(wind, pos)
  self.res.wind = wind
  self.res.hslid = pos
end

-- Create parameter block and aes/vdi tables
local <const> pb = gempb.create_pb()
local <const> aes = AES:new(pb)
local <const> vdi = VDI:new(pb)

-- appl_init
local <const> ap_id = aes:appl_init()
-- Open virtual workstation for screen
local <const> gh, wcel, hcel, wbox, hbox = aes:graf_handle()
gemdos.Cconws("hcel: " .. hcel .. "\r\n")

local <const> svwk_h, workout = vdi:v_opnvwk(gh)
assert(#workout == 57)

-- Set clip
local <const> x_max, y_max = workout[1], workout[2]
vdi:vs_clip(svwk_h, 1, 0, 0, x_max, y_max)

-- get work area of desktop window
local status, deskx, desky, deskw, deskh =
  aes:wind_get(0, aesdefs.wige_workxywh)

-- Create the Wind instance
local <const> wind1 = Wind:new(aes, vdi)

-- Window handle is initially invalid and not open
assert(wind1:handle() == -1)
assert(not wind1:is_open())

-- Set the test_view as the view
local view1 = test_view:new()

-- Use different appl_write_v
function aes:appl_write_v(dst_ap_id, msg_type, src_ap_id,
    word1, word2, word3, word4, word5, extra_imode, ...vararg)
  view1.res.writev_pack = table.pack(dst_ap_id, msg_type, src_ap_id,
    word1, word2, word3, word4, word5)
end

wind1:set_view(view1)
assert(wind1:view() == view1)

-- WindRefs must contain no windows
for k,v in WindRefs:pairs() do
  assert(false)
end

-- Create a window
local controls = aesdefs.wicr_name |
  aesdefs.wicr_closer | aesdefs.wicr_fuller | aesdefs.wicr_mover |
  aesdefs.wicr_info | aesdefs.wicr_sizer | aesdefs.wicr_uparrow |
  aesdefs.wicr_dnarrow | aesdefs.wicr_vslide | aesdefs.wicr_lfarrow |
  aesdefs.wicr_rtarrow | aesdefs.wicr_hslide

-- full coordinates must be constrained to desktop
local created = wind1:create(controls, -100, -200, 10000, 10100)
assert(created)

-- WindRefs must now contain the wind1 reference
local found_wind1 = false
for k,v in WindRefs:pairs() do
  if v == wind1 then
    found_wind1 = true
  else
    assert(false)
  end
end
assert(found_wind1)
-- Check WindRefs get_wind can get the Wind from the window handle
assert(WindRefs:get_wind(wind1:handle()) == wind1)

-- slider positions
wind1:set_hslpos(0)
wind1:set_hslsize(1000)
wind1:set_vslpos(0)
wind1:set_vslsize(1000)

-- Window name and title
wind1:set_name("Wind name")
wind1:set_info("Wind info")

-- Open a window
local opened = wind1:open(deskx, desky, deskw, deskh)
assert(opened)

-- Check view notification
assert(view1.res.wind == wind1)
assert(view1.res.open)
view1:clear_results()

-- Check top handle. Is must be window just opened.
local top_h = wind1:top_handle()
assert(top_h == wind1:handle())

-- Check set_top. set_top writes a message to top the window,
-- rather than calling wind_set with aesdefs.wise_top immediately.
-- Writing a message allows all Wind instances to receive the
-- evme_wm_topped mesag through dispatch, allowing each one to call
-- view_topped with true or false.
wind1:set_top()
local writev_pack = view1.res.writev_pack
assert(writev_pack)
assert(writev_pack[1] == ap_id)
assert(writev_pack[2] == k_evme_wm_topped)
assert(writev_pack[3] == ap_id)
assert(writev_pack[4] == wind1:handle())
assert(writev_pack[5] == 0)
assert(writev_pack[6] == 0)
assert(writev_pack[7] == 0)
assert(writev_pack[8] == 0)
view1:clear_results()

-- Check send_redraw - send evme_wm_redraw with a rectangle engulfing
-- the desk area. The redraw must be intersected with the desktop area.
wind1:send_redraw(-100, -200, 5000, 5000)
writev_pack = view1.res.writev_pack
assert(writev_pack)
assert(writev_pack[1] == ap_id)
assert(writev_pack[2] == k_evme_wm_redraw)
assert(writev_pack[3] == ap_id)
assert(writev_pack[4] == wind1:handle())

-- Redraw is limited to desk area
assert(writev_pack[5] == deskx)
assert(writev_pack[6] == desky)
assert(writev_pack[7] == deskw)
assert(writev_pack[8] == deskh)
view1:clear_results()

-- Dispatch sized mesag. The view must be notified of the changed work
-- area.
local mesag = { k_evme_wm_sized, ap_id, 0, wind1:handle(),
  deskx, desky, deskw // 2, deskh // 2 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
-- the view work rectangle matches work area of window
local wstatus, wx, wy, ww, wh =
  aes:wind_get(wind1:handle(), k_wige_workxywh)
assert(wstatus > 0)
assert(view1.res.workwx == wx)
assert(view1.res.workwy == wy)
assert(view1.res.workww == ww)
assert(view1.res.workwh == wh)
view1:clear_results()

-- Dispatch moved mesag. The view must be notified of the changed work
-- area. Wind aligns the window work area by 16 pixels, so even though
-- the window is moved to deskx + 18 here the view work area x coordinate
-- is set to 16.
mesag = { k_evme_wm_moved, ap_id, 0, wind1:handle(),
  deskx + 18, desky, deskw // 2, deskh // 2 }
wind1:dispatch(mesag)
-- the view work area x coordinate is aligned on 16
assert(view1.res.wind == wind1)
assert(view1.res.workwx == 16)
assert(view1.res.workwy == wy)
assert(view1.res.workww == ww)
assert(view1.res.workwh == wh)
view1:clear_results()

-- Dispatch fulled mesag. The view must be notified of the changed work
-- area. Note that although Wind aligns the work area by 16 pixels, it
-- doesn't in this case because that would mean the left hand border x
-- coordinate of the window would be less than zero.
mesag = { k_evme_wm_fulled, ap_id, 0, wind1:handle(), 0, 0, 0, 0 }
wind1:dispatch(mesag)
local wstatus, cx, cy, cw, ch =
  aes:wind_get(wind1:handle(), k_wige_currxywh)
assert(wstatus > 0)
assert(cx == deskx)
assert(cy == desky)
assert(cw == deskw)
assert(ch == deskh)
assert(view1.res.wind == wind1)
-- the view work area x coordinate is not aligned on 16
assert(view1.res.workwx % 16 ~= 0)
view1:clear_results()

-- Dispatch fulled again to restore size. The x coordinate of the
-- work area is once again aligned by 16 pixels.
mesag = { k_evme_wm_fulled, ap_id, 0, wind1:handle(), 0, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.workwx == 16)
assert(view1.res.workwy == wy)
assert(view1.res.workww == ww)
assert(view1.res.workwh == wh)
view1:clear_results()

-- Dispatch redraw mesag. As there is nothing covering the window, the
-- draw coordinates must match the work area of the window.
wstatus, cx, cy, cw, ch =
  aes:wind_get(wind1:handle(), k_wige_currxywh)
assert(wstatus > 0)
mesag = { k_evme_wm_redraw, ap_id, 0, wind1:handle(), cx, cy, cw, ch }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.drawx == 16)
assert(view1.res.drawy == wy)
assert(view1.res.draww == ww)
assert(view1.res.drawh == wh)
view1:clear_results()

-- Dispatch pageup mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_pageup, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_pageup)
view1:clear_results()

-- Dispatch pagedown mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_pagedown, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_pagedown)
view1:clear_results()

-- Dispatch lineup mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_lineup, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_lineup)
view1:clear_results()

-- Dispatch linedown mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_linedown, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_linedown)
view1:clear_results()

-- Dispatch pageleft mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_pageleft, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_pageleft)
view1:clear_results()

-- Dispatch pageright mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_pageright, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_pageright)
view1:clear_results()

-- Dispatch columnleft mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_columnleft, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_columnleft)
view1:clear_results()

-- Dispatch columnright mesag.
mesag =
  { k_evme_wm_arrowed, ap_id, 0, wind1:handle(), k_wmar_columnright, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.arrowed == k_wmar_columnright)
view1:clear_results()

-- Dispatch vertical slider mesag.
mesag = { k_evme_wm_vslid, ap_id, 0, wind1:handle(), 500, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.vslid == 500)
view1:clear_results()

-- Dispatch horizontal slider mesag.
mesag = { k_evme_wm_hslid, ap_id, 0, wind1:handle(), 501, 0, 0, 0 }
wind1:dispatch(mesag)
assert(view1.res.wind == wind1)
assert(view1.res.hslid == 501)
view1:clear_results()

-- Create a second Wind instance
local <const> wind2 = Wind:new(aes, vdi)

-- Window handle is initially invalid and not open
assert(wind2:handle() == -1)
assert(not wind2:is_open())

-- Create a view and set it as the Wind view
local view2 = test_view:new()
wind2:set_view(view2)
assert(wind2:view() == view2)

-- Create a window
controls = aesdefs.wicr_name |
  aesdefs.wicr_closer | aesdefs.wicr_mover

-- full coordinates will be constrained to desktop, however this window
-- has no fuller.
local created = wind2:create(controls, deskx, desky, deskw, deskh)
assert(created)

-- WindRefs must now contain the wind1 and wind2 references
local found_wind2
found_wind1, found_wind2 = false, false
for k,v in WindRefs:pairs() do
  if v == wind1 then
    found_wind1 = true
  elseif v == wind2 then
    found_wind2 = true
  else
    assert(false)
  end
end
assert(found_wind1 and found_wind2)
-- Check WindRefs get_wind can get the Wind from the window handle
assert(WindRefs:get_wind(wind1:handle()) == wind1)
assert(WindRefs:get_wind(wind2:handle()) == wind2)

-- Call WindRefs call_modal. When the passed function callback runs,
-- both views must have their override flag set.
WindRefs:call_modal(function()
    assert(view1.res.wind == wind1)
    assert(view1.res.override == true)
    assert(view2.res.wind == wind2)
    assert(view2.res.override == true)
  end)

-- After call_modal returns, both views must have their override flag
-- set to false
assert(view1.res.wind == wind1)
assert(view1.res.override == false)
assert(view2.res.wind == wind2)
assert(view2.res.override == false)
view1:clear_results()
view2:clear_results()

-- Open the second window
local opened = wind2:open(deskx, desky, deskw, deskh)
assert(opened)
-- Check view notification
assert(view2.res.wind == wind2)
assert(view2.res.open)
view2:clear_results()

-- Send topped mesag to each Wind, topping wind1. Each Wind must
-- notify its view, with a boolean indicating if it is top or not.
mesag = { k_evme_wm_topped, ap_id, 0, wind1:handle(), 0, 0, 0, 0 }
wind1:dispatch(mesag)
wind2:dispatch(mesag)

-- view1 must now be marked topped, and view2 untopped
assert(view1.res.wind == wind1)
assert(view1.res.is_topped == true)
assert(view2.res.wind == wind2)
assert(view2.res.is_topped == false)
view1:clear_results()
view2:clear_results()

-- Send topped mesag to each wind, topping wind2. Each Wind must
-- notify its view, with a boolean indicating if it is top or not.
mesag = { k_evme_wm_topped, ap_id, 0, wind2:handle(), 0, 0, 0, 0 }
wind1:dispatch(mesag)
wind2:dispatch(mesag)

-- view2 must now be marked topped, and view1 untopped
assert(view1.res.wind == wind1)
assert(view1.res.is_topped == false)
assert(view2.res.wind == wind2)
assert(view2.res.is_topped == true)
view1:clear_results()
view2:clear_results()

-- Send untopped mesag for a particular window handle to each Wind. If
-- the handle matches the Wind's handle, the Wind must notify its view
-- that it has been untopped.
mesag = { k_evme_wm_untopped, ap_id, 0, wind2:handle(), 0, 0, 0, 0 }
wind1:dispatch(mesag)
wind2:dispatch(mesag)

-- view1 must not be notified as it was not top
assert(view1.res.wind == nil)
assert(view1.res.is_topped == nil)
-- view2 must now be marked as untopped
assert(view2.res.wind == wind2)
assert(view2.res.is_topped == false)
view1:clear_results()
view2:clear_results()

-- Close the second window. The Wind must notify its view that the window
-- has been closed.
local closed = wind2:close()
assert(closed)
assert(view2.res.wind == wind2)
assert(not view2.res.open)
view2:clear_results()

-- Delete the second window.
local deleted = wind2:delete()
assert(deleted)

-- wind2 has been deleted, WindRefs now only contains a reference to wind1
found_wind1 = false
for k,v in WindRefs:pairs() do
  if v == wind1 then
    found_wind1 = true
  else
    assert(false)
  end
end
assert(found_wind1)
-- Check WindRefs get_wind can get the Wind from the window handle
assert(WindRefs:get_wind(wind1:handle()) == wind1)
-- wind2 window has been deleted so the reference must no longer be
-- in WindRefs
assert(WindRefs:get_wind(wind2:handle()) == nil)

-- Close the first window. The Wind must notify its view that the window
-- has been closed.
closed = wind1:close()
assert(closed)
assert(view1.res.wind == wind1)
assert(not view1.res.open)
view1:clear_results()

-- Delete the window
deleted = wind1:delete()
assert(deleted)

-- WindRefs now contains no references
for k,v in WindRefs:pairs() do
  assert(false)
end

-- Both wind1 and wind2 refs are no longer in WindRefs
assert(WindRefs:get_wind(wind1:handle()) == nil)
assert(WindRefs:get_wind(wind2:handle()) == nil)

-- Test window creation failure. create must return false if window
-- creation failed. It must also discard muds immediately on creation
-- failure.
controls = aesdefs.wicr_name | aesdefs.wicr_info |
  aesdefs.wicr_closer | aesdefs.wicr_mover
local winds = {}
repeat
  local <const> wind = Wind:new(aes, vdi)
  local <const> created = wind:create(controls, deskx, desky, deskw, deskh)
  if created then
    assert(wind.name_mud_:address() ~= 0)
    assert(wind.info_mud_:address() ~= 0)
    winds[#winds + 1] = wind
  else
    assert(wind.name_mud_ == nil)
    assert(wind.info_mud_ == nil)
  end
until not created 
assert(#winds > 0)
for k,v in ipairs(winds) do
  v:delete()
end

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
