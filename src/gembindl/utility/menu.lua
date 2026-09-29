global assert, gempb, require, setmetatable, string

local <const> k_aes_global = gempb.const.Pbid.aes_global
local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_evme_mn_selected = aesdefs.evme_mn_selected
local <const> k_metn_normal = aesdefs.metn_normal
local <const> k_grmk_control = aesdefs.grmk_control
local <const> k_obch_disabled = aesdefs.obch_disabled
aesdefs = nil

local <const> Menu = {}

-- new. Create a new Menu for a menu tree
-- Inputs:
--   1) table: rsrc: Resource wrapper table
--   2) table: aes: AES table
--   3) integer: menu_objn: menu tree object number
--   4) table: table to use for Menu instance otherwise nil
function Menu:new(rsrc, aes, menu_objn, o)
  o = o or {}
  o.rsrc_ = rsrc
  o.rsrc_addr_ = rsrc:address()
  o.aes_ = aes
  o.menu_objn_ = menu_objn
  o.menu_tree_addr_ = rsrc:tree_addr(menu_objn)

  o.title_tables_ = {}
  o.ctrl_key_table_ = {}
  o.alt_key_table_ = {}
  o.ap_id_ = aes:pb():peek(k_aes_global, 2)
  o.shortcut_mesag_table_ = {
    k_evme_mn_selected, o.ap_id_, 0, 0, 0, 0, 0, 0
  }

  self.__index = self
  return setmetatable(o, self)
end

-- menu_objn. Returns the object number of the menu tree
-- Result:
--   1) integer: menu object number
function Menu:menu_objn()
  return self.menu_objn_
end

-- menu_tree_addr. Returns the address of the menu tree
-- Result:
--   1) integer: menu tree address
function Menu:menu_tree_addr()
  return self.menu_tree_addr_
end

-- add_handler
-- Inputs:
--   1) integer: title_objn: object number of menu title
--   2) integer: entry_objn: object number of menu entry
--   3) function: handler: entry handler function
function Menu:add_handler(title_objn, entry_objn, handler)
  -- Each title object number has a table with entry object numbers as keys
  -- and handlers as values.
  local tt = self.title_tables_[title_objn]
  if not tt then
    -- Title object number does not have a handler table yet.
    tt = {}
    self.title_tables_[title_objn] = tt
  end
  -- Using the entry object number as key, add the handler to the title
  -- handler table.
  tt[entry_objn] = handler

  -- Determine keyboard shortcut for the entry_objn by processing the entry's
  -- text and looking for ^ for control key. Only control shortcuts are
  -- handled by parsing the menu entry.
  local <const> rsrc = self.rsrc_
  local <const> entry_spec =
    rsrc:obj_peek_spec(rsrc:tree_obj_offset(self.menu_objn_, entry_objn))
  local <const> entry_text = rsrc:reads(entry_spec - self.rsrc_addr_, nil, 0)
  if string.find(entry_text, "%^%g%s$") then
    local shortcut_byte = string.byte(entry_text, -2)
    -- Allow shortcuts between A and Z
    if shortcut_byte >= 65 and shortcut_byte <= 90 then
      -- Found a control key shortcut. Add it to the ctrl_key_table
      self.ctrl_key_table_[shortcut_byte - 64] = {
        handler, title_objn, entry_objn
      }
    end
  end
end

-- Dispatches event to handler
-- Inputs:
--   1) table: the job
--   2) integer: the event bits that happened
--   3) integer: mouse x position (always valid)
--   4) integer: mouse y position (always valid)
--   5) integer: mouse button state (always valid)
--   6) integer: shift key states (always valid)
--   7) integer: keycode (valid on event)
--   8) integer: clicked (valid on event)
--   9) table: the mesag table
function Menu:dispatch(job,
    happened, mx, my, button, shiftkey, keycode, clicked, mesag_tbl)
  if mesag_tbl[1] == k_evme_mn_selected then
    return self:do_selected_mesag_(job,
      happened, mx, my, button, shiftkey, keycode, clicked, mesag_tbl)
  elseif shiftkey ~= 0 and keycode ~= 0 then
    local short_cut_table
    if shiftkey == k_grmk_control then
      -- Control key pressed
      short_cut_table = self.ctrl_key_table_[keycode & 0xFF]
    end
    if short_cut_table then
      -- There is a short cut. Check the entry is not disabled.
      local <const> rsrc = self.rsrc_
      local <const> entry_offset =
        rsrc:tree_obj_offset(self.menu_objn_, short_cut_table[3])
      local <const> entry_state = rsrc:obj_peek_state(entry_offset)
      if entry_state & k_obch_disabled == 0 then
        -- Invoke keyboard shortcut handler
        self.shortcut_mesag_table_[4] = short_cut_table[2]  -- title objn
        self.shortcut_mesag_table_[5] = short_cut_table[3]  -- entry objn

        return short_cut_table[1](job,
          happened, mx, my, button, shiftkey, keycode, clicked,
          self.shortcut_mesag_table_)
      end
    end
  end
end

-- Process selected mesag
-- Inputs:
--   1) table: the job
--   2) integer: the event bits that happened
--   3) integer: mouse x position (always valid)
--   4) integer: mouse y position (always valid)
--   5) integer: mouse button state (always valid)
--   6) integer: shift key states (always valid)
--   7) integer: keycode (valid on event)
--   8) integer: clicked (valid on event)
--   9) table: the mesag table
function Menu:do_selected_mesag_(job, happened, mx, my, button, shiftkey,
    keycode, clicked, mesag_tbl)
  assert(mesag_tbl[1] == k_evme_mn_selected)
  local <const> title_objn, entry_objn = mesag_tbl[4], mesag_tbl[5]

  -- Normal video the title
  self.aes_:menu_tnormal(self.menu_tree_addr_, title_objn, k_metn_normal)

  -- Call the handler
  local <const> tt = self.title_tables_[title_objn]
  local <const> handler = tt and tt[entry_objn]
  if handler then
    return handler(job, happened, mx, my,
      button, shiftkey, keycode, clicked, mesag_tbl)
  end
end

return Menu
