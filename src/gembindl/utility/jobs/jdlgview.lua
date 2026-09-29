global assert, require, setmetatable, string, warn, gempb

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_Wind = k_RCache.require("gembindl.utility.wind")
local <const> k_FormEvnt =
  k_RCache.require("gembindl.utility.resource.formevnt")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local vdidefs = k_RCache.require("gembindl.utility.defs.vdidefs")
local msgdefs = k_RCache.require("gembindl.utility.defs.msgdefs")
local <const> k_controls = 
  aesdefs.wicr_closer | aesdefs.wicr_mover | aesdefs.wicr_name
local <const> k_wige_workxywh = aesdefs.wige_workxywh
local <const> k_wige_top = aesdefs.wige_top
local <const> k_grmo_m_off = aesdefs.grmo_m_off
local <const> k_grmo_m_on = aesdefs.grmo_m_on
local <const> k_wiup_beg_update = aesdefs.wiup_beg_update
local <const> k_wiup_end_update = aesdefs.wiup_end_update
local <const> k_rsga_tree = aesdefs.rsga_tree
local <const> k_wica_border = aesdefs.wica_border
local <const> k_obdr_root = aesdefs.obdr_root
local <const> k_obdr_max_depth = aesdefs.obdr_max_depth
local <const> k_obch_selected = aesdefs.obch_selected
local <const> k_obch_normal = aesdefs.obch_normal
local <const> k_evmu_mesag = aesdefs.evmu_mesag
local <const> k_form_evnt_mask = aesdefs.evmu_button | aesdefs.evmu_keybd
local <const> k_text = aesdefs.obty_text
local <const> k_boxtext = aesdefs.obty_boxtext
local <const> k_ftext = aesdefs.obty_ftext
local <const> k_fboxtext = aesdefs.obty_fboxtext
local <const> k_obfl_editable = aesdefs.obfl_editable
local <const> k_indirect = aesdefs.obfl_indirect
local <const> k_scli_off = vdidefs.scli_off
local <const> k_scli_on = vdidefs.scli_on

local <const> k_msg_error = msgdefs.msg_error
local <const> k_err_wicr = msgdefs.err_wicr

aesdefs = nil
vdidefs = nil
msgdefs = nil

local function min(a, b) return a < b and a or b end
local function max(a, b) return a > b and a or b end

local <const> JDlgView = {
}

-- new. Create a new JDlgView instance
-- Inputs:
--   2) table: o: optional table to use as instance
function JDlgView:new(o)
  o = o or {}
  o.evmu_mask = k_form_evnt_mask | k_evmu_mesag
  o.name_ = "JDlgView"
  o.on_form_evnt_ =
    function(view, continuing, clicked_objn, edited_objn)
      warn("form_evnt_: ", continuing and "true" or "false",
        " clicked_objn ", clicked_objn, " edited_objn ", edited_objn)
      return continuing
    end
  self.__index = self
  return setmetatable(o, self)
end

-- set_on_preclose. Set function to call when window receives
-- close mesag. If function returns true the window will close.
-- Returning false will prevent the window from being closed.
-- Inputs:
--   1) function: on_preclose: function to call
function JDlgView:set_on_preclose(on_preclose)
  self.on_preclose_ = on_preclose
end

-- set_of_form_evnt. Set function to call when form event processed
-- Inputs
--   1) function: on_form_evnt: function to call
function JDlgView:set_on_form_evnt(on_form_evnt)
  self.on_form_evnt_ = on_form_evnt
end

-- set_name. Sets the window name
-- Inputs:
--   1) string: name: the window name.
function JDlgView:set_name(name)
  self.name_ = name
  if self.wind_ then
    return self.wind_:set_name(name)
  end
end

-- set_dialog. Sets the dialog displayed by the view
-- Inputs:
--   1) integer: dialog object number
--   2) integer: editable object number otherwise zero 
function JDlgView:set_dialog(dialog_objn, edit_objn)
  self.dialog_objn_ = dialog_objn
  self.edit_objn_ = edit_objn or 0
end

-- set_top. Sets the window as top window
function JDlgView:set_top()
  if self.wind_ then
    return self.wind_:set_top()
  end
end

-- view_modal_override. Overrides view across a modal operation
-- Inputs:
--   1) boolean: override: true pre-modal, false post-modal
function JDlgView:view_modal_override(override)
  -- View only displays a cursor if it is the top window
  if not self.topped_ or
      self.wind_:top_handle() ~= self.wind_:handle() then
    return
  end

  -- Cursor is disabled when overridden
  return self:cursor_enable_(self.wind_, not override)
end

-- view_send_redraw. Send redraw message for view
function JDlgView:view_send_redraw()
  if not self.window_open_ then
    return
  end

  return self.wind_:send_redraw(self.work_x_, self.work_y_,
    self.work_width_, self.work_height_)
end

-- redraw_object. Redraws a dialog object indentified by object number
function JDlgView:send_object_redraw(objn)
  local <const> rsrc = self.rsrc_
  -- Find the coordinates of the object
  local <const> status, obx, oby =
    self.aes_:objc_offset(self.tree_addr_, objn)
  assert(status > 0)
  -- Find the dimensions of the object
  local <const> x, y, w, h =
    rsrc:obj_peek_pos(rsrc:tree_obj_offset(self.dialog_objn_, objn))
  -- Send redraw for coordinates and dimensions
  return self.wind_:send_redraw(obx, oby, w, h)
end

-- init_job. Initialises the job
-- Returns:
--   1) boolean: true if job initialised successfully
function JDlgView:init_job()
  self.aes_ = self.loop.aes
  self.vdi_ = self.loop.vdi
  self.rsrc_ = self.loop.rsrc
  -- Get address of dialog
  assert(self.dialog_objn_)
  self.tree_addr_ = self.rsrc_:tree_addr(self.dialog_objn_)
  -- double check with rsrc_gaddr
  local status, addr =
    self.aes_:rsrc_gaddr(k_rsga_tree, self.dialog_objn_)
  assert(status > 0)
  assert(addr == self.tree_addr_)

  -- Create a form evnt processor
  self.form_evnt_ = k_FormEvnt:new(self.aes_, self.rsrc_)
  -- Initialise form event processing with no edit object enabled
  self.form_evnt_:init(self.dialog_objn_, 0)

  return self:init_window_()
end

-- term_job. Terminates the job
-- Returns:
--   1) boolean: true if job terminated successfully
function JDlgView:term_job()
  if self.wind_ then
    -- Terminate form event processing
    self.form_evnt_:term()
    -- Close the window
    return self.wind_:close()
  end
  return true
end

-- dispatch. Dispatch to the JDlgView
-- Inputs:
--   1) integer: happened: the events that happened
--   2) integer: mx: mouse x position
--   3) integer: my: mouse y position
--   4) integer: button: buttons pressed
--   5) integer: keycode: the keycode
--   6) integer: clicks: the number of clicks
--   7) table: mesag: the mesag
function JDlgView:dispatch(
    happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  if self.topped_ and happened & k_form_evnt_mask ~= 0 then
    local <const> continuing, clicked_objn, edited_objn =
      self.form_evnt_:proc_evnt(happened, mx, my, keycode, clicked)
    if edited_objn ~= -1 then
      self.edit_objn_ = edited_objn
    end
    if clicked_objn ~= -1 or edited_objn ~= -1 then
      if not self:on_form_evnt_(continuing, clicked_objn, edited_objn) then
        return self.wind_:close()
      end
      if clicked_objn ~= -1 then
        -- If clicked_objn is editable then change edit_objn_ to it.
        local <const> rsrc = self.rsrc_
        local <const> obj_offset =
          rsrc:tree_obj_offset(self.dialog_objn_, clicked_objn)
        -- Check object flags
        local <const> obj_flags = rsrc:obj_peek_flags(obj_offset)
        if obj_flags & k_obfl_editable ~= 0 and
            obj_flags & k_indirect == 0 then
          -- Check object type
          local <const> obj_type = rsrc:obj_peek_type(obj_offset)
          if obj_type == k_ftext or obj_type == k_fboxtext then
            self.edit_objn_ = clicked_objn
          end
        end
      end
    end
  end

  if happened & k_evmu_mesag ~= 0 then
    return self.wind_:dispatch(mesag)
  end
end

-- open_vwork_. Opens a virtual workstation for the window
function JDlgView:open_vwork_()
  -- Open virtual workstation for screen
  local <const> gh = self.aes_:graf_handle()

  local workout
  self.svwk_h_, workout = self.vdi_:v_opnvwk(gh,
    { 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 2 })
  self.svwk_x_max_, self.svwk_y_max_ = workout[1], workout[2]
end

-- close_vwork_. Closes the virtual workstation for the window
function JDlgView:close_vwork_()
  self.svwk_x_max_ = nil
  self.svwk_y_max_ = nil
  -- Close virtual workstation for window
  local <const> svwk_h = self.svwk_h_
  self.swvk_h_ = nil
  return self.vdi_:v_clsvwk(svwk_h)
end

-- init_window_. Creates the vwork, inits state and opens Wind
function JDlgView:init_window_()
  -- Open virtual workstation
  self:open_vwork_()

  -- get work area of desktop window
  local status
  status, self.deskx_, self.desky_, self.deskw_, self.deskh_ =
    self.aes_:wind_get(0, k_wige_workxywh)
  assert(status > 0)

  -- Centre the form on the screen
  status, self.dlg_x_, self.dlg_y_, self.dlg_width_, self.dlg_height_ =
    self.aes_:form_center(self.tree_addr_)
  assert(status > 0)

  -- Get window border coordinates
  local bstatus, bx, by, bw, bh =
    self.aes_:wind_calc(k_wica_border, k_controls,
      self.dlg_x_, self.dlg_y_, self.dlg_width_, self.dlg_height_)
  assert(bstatus > 0)

  -- Create the window
  local wind = k_Wind:new(self.aes_, self.vdi_)

  if wind:create(k_controls,
      self.deskx_, self.desky_, self.deskw_, self.deskh_) then
    wind:set_name(self.name_)
    -- Set view to this job
    wind:set_view(self)
    self.wind_ = wind

    if wind:open(bx, by, bw, bh) then
      self.topped_ = true
    else
      -- Failed to open
      self.wind_ = nil
      warn("JDlgView:init_window_: open failed")
      wind:delete()
    end
  else
    warn("JDlgView:init_window_: create failed")
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
function JDlgView:term_window_()
  self.wind_:delete()
  self.wind_ = nil
  -- Close virtual workstation
  return self:close_vwork_()
end

-- view_preclose. Called by Wind after receiving closed mesag
-- Inputs:
--   1) table: wind: the Wind instance
-- Returns:
--   1) boolean: true if the window should be closed otherwise false
function JDlgView:view_preclose(wind)
  if self.on_preclose_ then
    return self:on_preclose_()
  end
  return true
end

-- view_close. Called by Wind after window closed
function JDlgView:view_close(wind)
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
function JDlgView:view_draw(wind, x, y, w, h)
  local <const> vdi = self.vdi_
  local <const> svwk_h = self.svwk_h_

  local x2 = x + w - 1
  local <const> y2 = y + h - 1
  vdi:vs_clip(svwk_h, k_scli_off, 0, 0, 0, 0)
  vdi:vr_recfl(svwk_h, x, y, x2, y2)

  -- Draw the form
  local <const> aes = self.aes_
  local status = aes:objc_draw(self.tree_addr_,
    k_obdr_root, k_obdr_max_depth,
    x, y, w, h)
  assert(status > 0)

  -- Is this window top window?
  if wind:top_handle() == wind:handle() then
    -- If a desk accessory just closed (causing this redraw)
    -- then fix up self.topped_
    self.topped_ = true

    -- Initialise form event processing. This will draw the edit box cursor
    -- if self.edit_objn_ is not zero.
    return self.form_evnt_:init(self.dialog_objn_, self.edit_objn_)
  end
end

-- view_open. Called by Wind when the window has been opened
-- Inputs:
--   1) table: wind: the Wind instance
function JDlgView:view_open(wind)
  self.window_open_ = true
end

-- view_workxywh. Called by Wind when the work area is determined.
-- Updates state and pokes the new position into the resource.
-- Inputs:
--   1) table: wind: the Wind instance
--   2) integer: wx: the work area x coordinate
--   3) integer: wy: the work area y coordinate
--   4) integer: ww: the work area width
--   5) integer: wh: the work area height
function JDlgView:view_workxywh(wind, wx, wy, ww, wh)
  -- Set window work rectangle
  self.work_x_ = wx
  self.work_y_ = wy
  self.work_width_ = ww
  self.work_height_ = wh

  -- Reposition the dialog
  local <const> rsrc = self.rsrc_
  local <const> top_offset = rsrc:tree_obj_offset(self.dialog_objn_, 0)
  local ox, oy, ow <const>, oh <const> = rsrc:obj_peek_pos(top_offset)
  ox = wx
  oy = wy
  return rsrc:obj_poke_pos(top_offset, ox, oy, ow, oh)
end

-- view_topped. Called by Wind for topped message
-- Inputs:
--   1) table: wind: the Wind instance
--   2) boolean: is_topped: true if view's window was topped
function JDlgView:view_topped(wind, is_topped)
  if self.topped_ then
    if not is_topped and
        wind:top_handle() == wind:handle() then
      -- View is no longer the top window
      self:cursor_enable_(wind, false)
    end
  elseif is_topped then
    -- View is becoming the top window
    self:cursor_enable_(wind, true)
  end
  self.topped_ = is_topped
end

-- view_untopped. Called by Wind for untopped window
-- Inputs:
--   1) table: wind: the Wind instance
function JDlgView:view_untopped(wind)
  return self:view_topped(wind, false)
end

function JDlgView:cursor_enable_(wind, is_enabled)
  if is_enabled then
    if self.edit_objn_ ~= 0 then
      -- Sending a full redraw ensures the edit box cursor is redrawn
      -- correctly even if the window  was only partially damaged by
      -- e.g. the file selector. AES will merge the dirty rectangle.
      return self:view_send_redraw()
    else
      -- There is no edit box. In this case the edit box cursor does
      -- not need restoring and form_evnt processing can be continued
      -- directly.
      return self.form_evnt_:init(self.dialog_objn_, self.edit_objn_)
    end
  else
    -- Terminate form event processing. This will undraw
    -- the edit box cursor if it was enabled.
    return self.form_evnt_:term()
  end
end

return JDlgView
