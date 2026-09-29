global assert, ipairs, require, setmetatable, table, warn, gemdos, gempb

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_Wind = k_RCache.require("gembindl.utility.wind")
local <const> k_MFDB = k_RCache.require("gembindl.utility.mfdb")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local vdidefs = k_RCache.require("gembindl.utility.defs.vdidefs")
local msgdefs = k_RCache.require("gembindl.utility.defs.msgdefs")
local <const> k_controls = 
  aesdefs.wicr_closer | aesdefs.wicr_fuller | aesdefs.wicr_mover |
  aesdefs.wicr_sizer | aesdefs.wicr_uparrow | aesdefs.wicr_dnarrow |
  aesdefs.wicr_vslide | aesdefs.wicr_lfarrow | aesdefs.wicr_rtarrow |
  aesdefs.wicr_hslide | aesdefs.wicr_name
local <const> k_wicr_info = aesdefs.wicr_info
local <const> k_wige_workxywh = aesdefs.wige_workxywh
local <const> k_wmar_pageup = aesdefs.wmar_pageup
local <const> k_wmar_pagedown = aesdefs.wmar_pagedown
local <const> k_wmar_lineup = aesdefs.wmar_lineup
local <const> k_wmar_linedown = aesdefs.wmar_linedown
local <const> k_wmar_pageleft = aesdefs.wmar_pageleft
local <const> k_wmar_pageright = aesdefs.wmar_pageright
local <const> k_wmar_columnleft = aesdefs.wmar_columnleft
local <const> k_wmar_columnright = aesdefs.wmar_columnright
local <const> k_grmo_m_off = aesdefs.grmo_m_off
local <const> k_grmo_m_on = aesdefs.grmo_m_on
local <const> k_wiup_beg_update = aesdefs.wiup_beg_update
local <const> k_wiup_end_update = aesdefs.wiup_end_update
local <const> k_evmu_mesag = aesdefs.evmu_mesag

local <const> k_scli_off = vdidefs.scli_off
local <const> k_scli_on = vdidefs.scli_on
local <const> k_rocp_s_only = vdidefs.rocp_s_only

local <const> k_msg_error = msgdefs.msg_error
local <const> k_err_wicr = msgdefs.err_wicr

aesdefs = nil
vdidefs = nil
msgdefs = nil

local function min(a, b) return a < b and a or b end
local function max(a, b) return a > b and a or b end

local <const> JTxtView = {
}

-- new. Create a new JTxtView instance
-- Inputs:
--   1) table: txt: the text to view
--   2) table: o: optional table to use as instance
function JTxtView:new(txt, o)
  txt = txt or {}
  o = o or {}
  o.evmu_mask = k_evmu_mesag
  o.txt = txt
  o.txt.n = #txt
  o.controls_ = 0
  o.name_ = "JTxtView"
  o.max_lines_ = -1 -- negative means unlimited
  o.txt_ox_ = 0
  o.txt_oy_ = 0
  self.__index = self
  setmetatable(o, self)
  o:constrain_max_lines_(o.max_lines_)
  return o
end

-- set_on_preclose. Set function to call when window receives
-- close mesag. If function returns true the window will close.
-- Returning false will prevent the window from being closed.
-- Inputs:
--   1) function: on_preclose: function to call
function JTxtView:set_on_preclose(on_preclose)
  self.on_preclose_ = on_preclose
end

-- set_name. Sets the window name
-- Inputs:
--   1) string: name: the window name.
function JTxtView:set_name(name)
  self.name_ = name
  if self.wind_ then
    return self.wind_:set_name(name)
  end
end

-- set_info. Sets the window info
-- Inputs:
--   1) string: info: the window info.
function JTxtView:set_info(info)
  self.info_ = info
  if self.wind_ and self.controls_ & k_wicr_info ~= 0 then
    return self.wind_:set_info(info)
  end
end

-- set_top. Sets the window as top window
function JTxtView:set_top()
  if self.wind_ then
    return self.wind_:set_top()
  end
end

-- view_modal_override. Overrides view across a modal operation
-- Inputs:
--   1) boolean: override: true pre-modal, false post-modal
function JTxtView:view_modal_override(override)
end

-- set_max_lines. Changes the maxmimum number of lines
-- Inputs:
--   1) integer: max_lines: the maximum number of lines
function JTxtView:set_max_lines(max_lines)
  self.max_lines_ = max_lines
  self:constrain_max_lines_(max_lines)
  return self:view_send_redraw()
end

-- set_small_text. When true text is small.
-- Window must be closed and re-opened to take affect.
-- Inputs:
--   1) boolean: enabled: true for small text
function JTxtView:set_small_text(enabled)
  self.small_text_enabled_ = enabled
end

function JTxtView:constrain_max_lines_(max_lines)
  if max_lines >= 0 and self.txt.n > max_lines then
    local <const> n_remove = self.txt.n - max_lines
    table.move(self.txt, n_remove + 1, self.txt.n, 1)

    for k = self.txt.n, max_lines + 1, -1 do
      self.txt[k] = nil
    end

    self.txt.n = max_lines
    -- Reduce text origin by number of lines removed
    self.txt_oy_ = self.txt_oy_ - n_remove
    if self.txt_oy_ < 0 then
      self.txt_oy_ = 0
    end
  end

  self.txt_nlines = self.txt.n
  local max_width = 0
  for k = 1, self.txt.n do
    local <const> len = #self.txt[k]
    if len > max_width then
      max_width = len
    end
  end

  self.txt_ncolumns = max_width
end

-- view_send_redraw. Send redraw message for view
function JTxtView:view_send_redraw()
  if not self.window_open_ then
    return
  end

  self:view_workxywh(self.wind_,
    self.work_x_, self.work_y_, self.work_width_, self.work_height_)

  return self.wind_:send_redraw(self.work_x_, self.work_y_,
    self.work_width_, self.work_height_)
end

-- init_job. Initialises the job
-- Returns:
--   1) boolean: true if job initialised successfully
function JTxtView:init_job()
  return self:init_window_()
end

-- term_job. Terminates the job
-- Returns:
--   1) boolean: true if job terminated successfully
function JTxtView:term_job()
  if self.wind_ then
    return self.wind_:close()
  end
  return true
end

-- dispatch. Dispatch to the JTxtView
-- Inputs:
--   1) integer: happened: the events that happened
--   2) integer: mx: mouse x position
--   3) integer: my: mouse y position
--   4) integer: button: buttons pressed
--   5) integer: keycode: the keycode
--   6) integer: clicks: the number of clicks
--   7) table: mesag: the mesag
function JTxtView:dispatch(
    happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  return self.wind_:dispatch(mesag)
end

-- open_vwork_. Opens a virtual workstation for the window
function JTxtView:open_vwork_()
  -- Open virtual workstation for screen
  local <const> gh = self.aes_:graf_handle()

  local workout
  self.svwk_h_, workout = self.vdi_:v_opnvwk(gh,
    { 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 2 })
  self.svwk_x_max_, self.svwk_y_max_ = workout[1], workout[2]
end

-- close_vwork_. Closes the virtual workstation for the window
function JTxtView:close_vwork_()
  self.svwk_x_max_ = nil
  self.svwk_y_max_ = nil
  -- Close virtual workstation for window
  local <const> svwk_h = self.svwk_h_
  self.swvk_h_ = nil
  return self.vdi_:v_clsvwk(svwk_h)
end

-- init_window_. Creates the vwork, inits state and opens Wind
function JTxtView:init_window_()
  self.aes_ = self.loop.aes
  self.vdi_ = self.loop.vdi

  -- Open virtual workstation
  self:open_vwork_()

  -- Query font attributes for the char height
  local text_face, text_color, angle, hor_align, ver_align, wr_mode,
    char_w, char_h, cell_w, cell_h = self.vdi_:vqt_attributes(self.svwk_h_)

  -- Determine small system font height
  local small_height
  if cell_h == 16 then
    small_height = 6
  elseif cell_h == 8 then
    small_height = 4
  end

  -- Set font height
  local wchar, hchar, wcel, hcel =
    self.vdi_:vst_height(self.svwk_h_,
    self.small_text_enabled_ and small_height or char_h)
  self.wcel_ = wcel
  self.hcel_ = hcel

  -- Check vqt_fontinfo
  local first_char, last_char, dist_tbl, max_cellw, effects_tbl =
    self.vdi_:vqt_fontinfo(self.svwk_h_)
  assert(first_char == 0 and last_char == 255)
  self.base_distance_ = dist_tbl[5]
  self.bottom_distance_ = dist_tbl[1]

  -- get work area of desktop window
  local status
  status, self.deskx_, self.desky_, self.deskw_, self.deskh_ =
    self.aes_:wind_get(0, k_wige_workxywh)
  assert(status > 0)

  -- MFDB for screen
  self.screen_mfdb_ = k_MFDB:new()
  self.screen_mfdb_:set(0)
  self.screen_mfdb_addr_ = self.screen_mfdb_:address()

  -- Coordinate table for cpyfm
  self.cpyfm_coords_ = table.create(8)

  -- Create the window
  local wind = k_Wind:new(self.aes_, self.vdi_)
  local controls = k_controls
  if self.info_ then
    controls = controls | k_wicr_info
  end

  if wind:create(controls,
      self.deskx_, self.desky_, self.deskw_, self.deskh_) then
    self.controls_ = controls
    wind:set_name(self.name_)
    if self.info_ then
      wind:set_info(self.info_)
    end
    -- Set view to this job
    wind:set_view(self)
    self.wind_ = wind

    if wind:open(self.deskx_, self.desky_, self.deskw_, self.deskh_) then
      self.topped_ = true
    else
      -- Failed to open
      self.wind_ = nil
      self.controls_ = 0
      warn("JTxtView:init_window_: open failed")
      wind:delete()
    end
  else
    warn("JTxtView:init_window_: create ", self.name_, " failed")
    -- Send error message to loop
    self.loop:send_mesag(k_msg_error, k_err_wicr)
  end

  if self.wind_ == nil then
    -- Close virtual workstation
    self:close_vwork_()
    return false
  end

  return true
end

-- term_window_. Deletes the Wind and closes vwork
function JTxtView:term_window_()
  self.wind_:delete()
  self.wind_ = nil
  self.controls_ = 0
  -- Close virtual workstation
  return self:close_vwork_()
end

-- view_preclose. Called by Wind after receiving closed mesag
-- Inputs:
--   1) table: wind: the Wind instance
-- Returns:
--   1) boolean: true if the window should be closed otherwise false
function JTxtView:view_preclose(wind)
  if self.on_preclose_ then
    return self:on_preclose_()
  end
  return true
end

-- view_close. Called by Wind after window closed
function JTxtView:view_close(wind)
  self:term_window_()
  self.window_open_ = false
  return self.loop:del_job(self)
end

-- view_draw. Called by Wind to draw work area
-- Inputs:
--   1) table: wind: the Wind instance
--   2) integer: x: the x coordinate of rectangle
--   3) integer: y: the y coordinate of rectangle
--   4) integer: w: the width of the rectangle
--   5) integer: h: the height of the rectangle
--   NOTE: The rectangle may be partial or the full work area
function JTxtView:view_draw(wind, x, y, w, h)
  local <const> vdi = self.vdi_
  local <const> svwk_h = self.svwk_h_

  local x2 = x + w - 1
  local <const> y2 = y + h - 1
  vdi:vs_clip(svwk_h, k_scli_off, 0, 0, 0, 0)
  vdi:vr_recfl(svwk_h, x, y, x2, y2)

  x2 = min(x2, self.work_x_ + self.visible_cols_width_ - 1)
  if x <= x2 then
    vdi:vs_clip(svwk_h, k_scli_on, x, y, x2, y2)
    local <const> txt = self.txt
    local <const> hcel = self.hcel_
    local <const> rx = self.rx_
    local ry = self.ry_
    for line = self.txt_oy_ + 1, self.stop_line_ do
      vdi:v_gtext(svwk_h, rx, ry, txt[line])
      ry = ry + hcel
    end
  end
end

-- view_open. Called by Wind when the window has been opened
-- Inputs:
--   1) table: wind: the Wind instance
function JTxtView:view_open(wind)
  self.window_open_ = true
end

-- view_workxywh. Called by Wind, or JTxtView, when the window
-- work area has changed. Updates state and calls into Wind to
-- adjust sliders.
-- Inputs:
--   1) table: wind: the Wind instance
--   2) integer: wx: the work area x coordinate
--   3) integer: wy: the work area y coordinate
--   4) integer: ww: the work area width
--   5) integer: wh: the work area height
function JTxtView:view_workxywh(wind, wx, wy, ww, wh)
  -- Set window work rectangle
  self.work_x_ = wx
  self.work_y_ = wy
  self.work_width_ = ww
  self.work_height_ = wh

  -- Number of visible columns and rows in the view
  local <const> visible_cols = ww // self.wcel_
  local <const> visible_rows = wh // self.hcel_
  self.visible_cols_ = visible_cols
  self.visible_rows_ = visible_rows
  self.visible_cols_width_ = visible_cols * self.wcel_

  -- Adjust text origin x
  local <const> txt_ncolumns = self.txt_ncolumns
  if txt_ncolumns - self.txt_ox_ < visible_cols then
    self.txt_ox_ = txt_ncolumns - visible_cols
    if self.txt_ox_ < 0 then
      self.txt_ox_ = 0
    end
  end

  -- Adjust text origin y
  local <const> txt_nlines = self.txt_nlines
  if txt_nlines - self.txt_oy_ < visible_rows then
    self.txt_oy_ = txt_nlines - visible_rows
    if self.txt_oy_ < 0 then
      self.txt_oy_ = 0
    end
  end

  -- Work out render position
  self.rx_ = self.work_x_ - self.txt_ox_ * self.wcel_
  self.ry_ = self.work_y_ + self.base_distance_
  -- Work out stop line
  local stop_line = self.txt_oy_ + visible_rows
  if stop_line > txt_nlines then
    stop_line = txt_nlines
  end
  self.stop_line_ = stop_line
  self.stop_line_y_ = self.work_y_ + (self.visible_rows_ - 1) * self.hcel_

  -- Vertical slider size
  local size = 1000
  if txt_nlines > 0 then
    size = size * visible_rows // txt_nlines
  end
  if self.vslsize_ ~= size then
    self.wind_:set_vslsize(size)
    self.vslsize_ = size
  end
  -- Horizontal slider size
  size = 1000
  if txt_ncolumns > 0 then
    size = size * visible_cols // txt_ncolumns
  end
  if self.hslsize_ ~= size then
    self.wind_:set_hslsize(size)
    self.hslsize_ = size
  end
  -- Vertical slider position
  local pos = 0
  if txt_nlines > visible_rows then
    pos = 1000 * self.txt_oy_ // (txt_nlines - visible_rows)
  end
  if self.vslpos_ ~= pos then
    self.wind_:set_vslpos(pos)
    self.vslpos_ = pos
  end
  -- Horizonal slider position
  pos = 0
  if txt_ncolumns > visible_cols then
    pos = 1000 * self.txt_ox_ // (txt_ncolumns - visible_cols)
  end
  if self.hslpos_ ~= pos then
    self.wind_:set_hslpos(pos)
    self.hslpos_ = pos
  end
end

-- view_sized. Called by Wind when the window is resized
-- Calls view_workxywh and erases fringes when shrinking.
-- Inputs:
--   1) table: wind: the Wind instance
--   2) integer: wx: the window x coordinate
--   3) integer: wy: thw window y coordinate
--   4) integer: ww: the window width
--   5) integer: wy: the window height
function JTxtView:view_sized(wind, wx, wy, ww, wh)
  local <const> old_work_width = self.work_width_
  local <const> old_work_height = self.work_height_

  -- Set work rectangle
  self:view_workxywh(self, wx, wy, ww, wh)

  if ww >= old_work_width and wh >= old_work_height then
    return
  end

  -- Erase any text left in the fringe after an axis shrink
  local <const> aes = self.aes_
  aes:graf_mouse(k_grmo_m_off)
  aes:wind_update(k_wiup_beg_update)

  local <const> vdi = self.vdi_
  local <const> svwk_h = self.svwk_h_
  local <const> work_x2 = self.work_x_ + self.work_width_ - 1
  local <const> work_y2 = self.work_y_ + self.work_height_ - 1
  vdi:vs_clip(svwk_h, k_scli_off, 0, 0, 0, 0)
  if ww < old_work_width then
    -- Erase right hand fringe
    local <const> fringe = self.work_width_ % self.wcel_
    local <const> x = work_x2 - fringe
    vdi:vr_recfl(svwk_h, x, self.work_y_, work_x2, work_y2)
  end
  if wh < old_work_height then
    -- Erase bottom fringe
    local <const> fringe = self.work_height_ % self.hcel_
    local <const> y = work_y2 - fringe + self.bottom_distance_
    if y <= work_y2 then
      vdi:vr_recfl(svwk_h, self.work_x_, y, work_x2, work_y2)
    end
  end

  aes:wind_update(k_wiup_end_update)
  return aes:graf_mouse(k_grmo_m_on)
end

-- view_vslid. Called by Wind when the vertical slider is moved
-- Inputs:
--   1) table: wind: the Wind instance
--   2) integer: pos: the slider position
function JTxtView:view_vslid(wind, pos)
  local oy = 0
  if self.txt_nlines > self.visible_rows_ then
    oy = pos * (self.txt_nlines - self.visible_rows_) // 1000
  end
  self.txt_oy_ = oy
  self:view_workxywh(self.wind_,
    self.work_x_, self.work_y_, self.work_width_, self.work_height_)
  return self.wind_:send_redraw(self.work_x_, self.work_y_,
    self.work_width_, self.work_height_)
end

-- view_hslid. Called by Wind when the horizontal slider is moved
-- Inputs:
--   1) table: wind: the Wind instance
--   2) integer: pos: the slider position
function JTxtView:view_hslid(wind, pos)
  local ox = 0
  if self.txt_ncolumns > self.visible_cols_ then
    ox = pos * (self.txt_ncolumns - self.visible_cols_) // 1000
  end
  self.txt_ox_ = ox
  self:view_workxywh(self.wind_,
    self.work_x_, self.work_y_, self.work_width_, self.work_height_)
  return self.wind_:send_redraw(self.work_x_, self.work_y_,
    self.work_width_, self.work_height_)
end

-- view_arrowed. Called by Wind when a slider is paged or arrow pressed
-- Inputs:
--   1) table: wind: the Wind instance
--   2) integer: action: the slider action
function JTxtView:view_arrowed(wind, action)
  local old_txt_oy = self.txt_oy_
  local old_txt_ox = self.txt_ox_

  -- Adjust text origin
  if action == k_wmar_pageup then
    self.txt_oy_ = self.txt_oy_ - self.visible_rows_
  elseif action == k_wmar_pagedown then
    self.txt_oy_ = self.txt_oy_ + self.visible_rows_
  elseif action == k_wmar_lineup then
    self.txt_oy_ = self.txt_oy_ - 1
  elseif action == k_wmar_linedown then
    self.txt_oy_ = self.txt_oy_ + 1
  elseif action == k_wmar_pageleft then
    self.txt_ox_ = self.txt_ox_ - self.visible_cols_
  elseif action == k_wmar_pageright then
    self.txt_ox_ = self.txt_ox_ + self.visible_cols_
  elseif action == k_wmar_columnleft then
    self.txt_ox_ = self.txt_ox_ - 1
  elseif action == k_wmar_columnright then
    self.txt_ox_ = self.txt_ox_ + 1
  end

  if self.txt_oy_ < 0 then
    self.txt_oy_ = 0
  end
  if self.txt_ox_ < 0 then
    self.txt_ox_ = 0
  end

  local <const> work_x2 = self.work_x_ + self.work_width_ - 1
  local <const> work_y2 = self.work_y_ + self.work_height_ - 1

  -- Re-apply work rectangle
  self:view_workxywh(self.wind_,
    self.work_x_, self.work_y_, self.work_width_, self.work_height_)

  -- Vertical and width deltas for computing cpyfm coords
  local <const> vdelta = self.visible_rows_ * self.hcel_ - 1
  local <const> wdelta = self.visible_cols_ * self.wcel_ - 1
  local <const> vdi = self.vdi_
  local <const> aes = self.aes_
  local <const> svwk_h = self.svwk_h_
  local <const> screen_mfdb_addr = self.screen_mfdb_addr_
  local <const> coords = self.cpyfm_coords_

  vdi:vs_clip(svwk_h, k_scli_off, 0, 0, 0, 0)

  if self.txt_oy_ == old_txt_oy - 1 then
    -- Scroll up
    aes:graf_mouse(k_grmo_m_off)
    aes:wind_update(k_wiup_beg_update)

    -- Blit down
    -- Source rectangle
    coords[1] = self.work_x_
    coords[2] = self.work_y_
    coords[3] = work_x2
    coords[4] = self.work_y_ + vdelta - self.hcel_
    -- Destination rectangle
    coords[5] = self.work_x_
    coords[6] = self.work_y_ + self.hcel_
    coords[7] = work_x2
    coords[8] = self.work_y_ + vdelta

    vdi:vro_cpyfm(svwk_h, k_rocp_s_only, coords,
      screen_mfdb_addr, screen_mfdb_addr)

    -- Draw the top line of text
    local <const> x2 = self.work_x_ + self.visible_cols_width_ - 1
    local <const> y2 = self.work_y_ + self.hcel_ - 1
    vdi:vs_clip(svwk_h, k_scli_on,
      self.work_x_, self.work_y_, x2, y2)

    local top_line_txt = self.txt[self.txt_oy_ + 1]
    vdi:v_gtext(svwk_h,
      self.rx_, self.work_y_ + self.base_distance_,
      top_line_txt)

    vdi:vs_clip(svwk_h, k_scli_off, 0, 0, 0, 0)

    -- Draw residual rectangle at right hand side
    local <const> x1 = self.work_x_ +
      (#top_line_txt - self.txt_ox_) * self.wcel_
    if x1 <= x2 then
      vdi:vr_recfl(svwk_h, x1, self.work_y_, x2, y2)
    end

    aes:wind_update(k_wiup_end_update)
    aes:graf_mouse(k_grmo_m_on)
  elseif self.txt_oy_ == old_txt_oy + 1 then
    -- Scroll down
    aes:graf_mouse(k_grmo_m_off)
    aes:wind_update(k_wiup_beg_update)

    -- Blit up
    -- Source rectangle
    coords[1] = self.work_x_
    coords[2] = self.work_y_ + self.hcel_
    coords[3] = work_x2
    coords[4] = self.work_y_ + vdelta
    -- Destination rectangle
    coords[5] = self.work_x_
    coords[6] = self.work_y_
    coords[7] = work_x2
    coords[8] = self.work_y_ + vdelta - self.hcel_
    vdi:vro_cpyfm(svwk_h, k_rocp_s_only, coords,
      screen_mfdb_addr, screen_mfdb_addr)

    -- Draw the bottom line of text
    local <const> x2 = self.work_x_ + self.visible_cols_width_ - 1
    local <const> y2 = self.stop_line_y_ + self.hcel_ - 1
    vdi:vs_clip(svwk_h, k_scli_on,
      self.work_x_, self.stop_line_y_, x2, y2)

    local stop_line_txt = self.txt[self.stop_line_]
    vdi:v_gtext(svwk_h,
      self.rx_, self.stop_line_y_ + self.base_distance_,
      stop_line_txt)

    vdi:vs_clip(svwk_h, k_scli_off, 0, 0, 0, 0)

    -- Draw residual rectangle at right hand side
    local <const> x1 = self.work_x_ +
      (#stop_line_txt - self.txt_ox_) * self.wcel_
    if x1 <= x2 then
      vdi:vr_recfl(svwk_h, x1, self.stop_line_y_, x2, y2)
    end

    aes:wind_update(k_wiup_end_update)
    aes:graf_mouse(k_grmo_m_on)
  elseif self.txt_ox_ == old_txt_ox + 1 then
    -- Scroll right
    aes:graf_mouse(k_grmo_m_off)
    aes:wind_update(k_wiup_beg_update)

    -- Blit left
    -- Source rectangle
    coords[1] = self.work_x_ + self.wcel_
    coords[2] = self.work_y_
    coords[3] = self.work_x_ + wdelta
    coords[4] = work_y2
    -- Destination rectangle
    coords[5] = self.work_x_
    coords[6] = self.work_y_
    coords[7] = self.work_x_ + wdelta - self.wcel_
    coords[8] = work_y2

    vdi:vro_cpyfm(svwk_h, k_rocp_s_only, coords,
      screen_mfdb_addr, screen_mfdb_addr)

    -- Redraw right hand column
    self:view_draw(self.wind_,
      self.work_x_ + wdelta - self.wcel_ + 1, self.work_y_,
      self.wcel_, vdelta + 1)

    aes:wind_update(k_wiup_end_update)
    aes:graf_mouse(k_grmo_m_on)
  elseif self.txt_ox_ == old_txt_ox - 1 then
    -- Scroll left
    aes:graf_mouse(k_grmo_m_off)
    aes:wind_update(k_wiup_beg_update)

    -- Blit right
    -- Source rectangle
    coords[1] = self.work_x_
    coords[2] = self.work_y_
    coords[3] = self.work_x_ + wdelta - self.wcel_
    coords[4] = work_y2
    -- Destination rectangle
    coords[5] = self.work_x_ + self.wcel_
    coords[6] = self.work_y_
    coords[7] = self.work_x_ + wdelta
    coords[8] = work_y2

    vdi:vro_cpyfm(svwk_h, k_rocp_s_only, coords,
      screen_mfdb_addr, screen_mfdb_addr)

    -- Redraw left hand column
    self:view_draw(self.wind_,
      self.work_x_, self.work_y_,
      self.wcel_, vdelta + 1)

    aes:wind_update(k_wiup_end_update)
    aes:graf_mouse(k_grmo_m_on)
  elseif self.txt_oy_ ~= old_txt_oy or self.txt_ox_ ~= old_txt_ox then
    return self.wind_:send_redraw(self.work_x_, self.work_y_,
      self.work_width_, self.work_height_)
  end
end

-- view_topped. Called by Wind for topped message
-- Inputs:
--   1) table: wind: the Wind instance
--   2) boolean: is_topped: true if view's window was topped
function JTxtView:view_topped(wind, is_topped)
  self.topped_ = is_topped
end

-- view_untopped. Called by Wind for untopped window
-- Inputs:
--   1) table: wind: the Wind instance
function JTxtView:view_untopped(wind)
  return self:view_topped(wind, false)
end

-- append_array. Appends an array of strings as extra lines
-- Inputs:
--   1) table: string_tbl: array of strings to append
function JTxtView:append_array(string_tbl)
  if #string_tbl == 0 then
    -- No strings to append
    return
  end

  local <const> txt = self.txt
  table.move(string_tbl, 1, #string_tbl, txt.n + 1, txt)
  txt.n = txt.n + #string_tbl

  -- Increase text origin by number of lines added
  self.txt_oy_ = self.txt_oy_ + #string_tbl

  self:constrain_max_lines_(self.max_lines_)
  return self:view_send_redraw()
end

-- get_lines. Copies the lines into dest_tble
-- Inputs:
--   1) table: dest_tbl: the destination table or nil
-- Returns:
--   1) table: the copied lines. Field .n indicates num lines.
function JTxtView:get_lines(dest_tbl)
  dest_tbl = dest_tbl or table.create(self.txt.n, 1)
  dest_tbl.n = self.txt.n
  return table.move(self.txt, 1, self.txt.n, 1, dest_tbl)
end

return JTxtView
