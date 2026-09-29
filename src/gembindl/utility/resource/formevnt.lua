global require, setmetatable

local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_root = aesdefs.obdr_root
local <const> k_max_depth = aesdefs.obdr_max_depth
local <const> k_init = aesdefs.obed_init
local <const> k_ends = aesdefs.obed_ends
local <const> k_char = aesdefs.obed_char
local <const> k_button = aesdefs.evmu_button
local <const> k_keybd = aesdefs.evmu_keybd
aesdefs = nil

local <const> FormEvnt = { }

-- Create a new FormEvnt
function FormEvnt:new(aes, rsrc, o)
  o = o or {}
  o.aes_ = aes
  o.rsrc_ = rsrc
  self.__index = self
  return setmetatable(o, self )
end

-- FormEvnt:init. Initialise a FormEvnt.
-- Input:
--   1) integer: tree_objn: tree number
--   2) integer: edit_objn: object number of editable text otherwise zero
function FormEvnt:init(tree_objn, edit_objn)
  self.tree_addr = self.rsrc_:tree_addr(tree_objn)
  self.tree_objn = tree_objn
  self.edit_objn = edit_objn
  self.char_idx = 0
  self.continue = 1

  -- Intialise edit object if used
  if edit_objn ~= 0 then
    return self:init_edit_obj_(edit_objn)
  end
end

-- FormEvnt:term. Terminate a FormEvnt.
function FormEvnt:term()
  return self:change_edit_obj_(0)
end

-- FormEvnt:proc_evnt. Process form interaction event.
-- Input:
--   1) integer: events: event bits received from evnt_multi
--   2) integer: mx: mouse x position from evnt_multi
--   3) integer: my: mouse y position from evnt_multi
--   4) integer: keycode: keycode received from evnt_multi
--   5) integer: num_clicks: num_clicks received from evnt_multi
-- Returns:
--   1) boolean: true if interaction continues
--   2) integer: clicked object number, otherwise -1
--   3) integer: edited object number, otherwise -1
function FormEvnt:proc_evnt(events, mx, my, keycode, num_clicks)
  local clicked_object, edited_object = -1, -1

  -- Was there a button event?
  if self.continue ~= 0 and events & k_button ~= 0 then
    -- Find the object clicked on
    local click_obj <const> =
      self.aes_:objc_find(self.tree_addr, k_root, k_max_depth, mx, my)
    if click_obj ~= -1 then
      clicked_object = click_obj
      -- Process left button click with form_button
      local new_edit_objn
      self.continue, new_edit_objn =
        self.aes_:form_button(self.tree_addr, click_obj, num_clicks)
      -- If continue is 0 it was an exit click
      -- Edit object changing?
      if self.continue ~= 0 and new_edit_objn ~= 0 then
        self:change_edit_obj_(new_edit_objn)
      end
    end
  end

  -- Was there a key press?
  if self.continue ~= 0 and events & k_keybd ~= 0 then
    -- Process key press with form_keybd
    local new_edit_objn, key_out
    self.continue, new_edit_objn, key_out =
      self.aes_:form_keybd(self.tree_addr, self.edit_objn, keycode)
    -- If continue is 0 it was an exit key press
    if self.continue == 1 then
      -- Edit object changing?
      if new_edit_objn ~= self.edit_objn then
        self:change_edit_obj_(new_edit_objn)
      end
      if key_out ~= 0 and self.edit_objn ~= 0 then
        edited_object = self.edit_objn
        -- Edit object with key press 
        local status
        status, self.char_idx =
          self.aes_:objc_edit(self.tree_addr, self.edit_objn, key_out,
            self.char_idx, k_char)
      end
    else
      -- Return pressed on default object
      clicked_object = new_edit_objn
    end
  end

  local continuing <const> = self.continue == 1 and true or false
  return continuing, clicked_object, edited_object
end

-- initialise edit object
function FormEvnt:init_edit_obj_(edit_objn)
  self.edit_objn = edit_objn
  -- Set cursor position to end of edit object text
  local <const> rsrc = self.rsrc_
  self.char_idx =
    #rsrc:tedinfo_read_text(rsrc:obj_tedinfo_offset(
        rsrc:tree_obj_offset(self.tree_objn, edit_objn)))
  -- Turn cursor on in new edit object
  return self.aes_:objc_edit(self.tree_addr,
    edit_objn, 0, self.char_idx, k_init)
end

-- change edit object
function FormEvnt:change_edit_obj_(new_edit_objn)
  -- Turn cursor off in old edit object
  local <const> edit_objn = self.edit_objn
  if edit_objn ~= 0 then
    self.aes_:objc_edit(
      self.tree_addr, edit_objn, 0, self.char_idx, k_ends)
  end

  -- Initialise new edit object
  if new_edit_objn ~= 0 then
    return self:init_edit_obj_(new_edit_objn)
  end
end

return FormEvnt
