global assert, require

local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_Menu = k_RCache.require("gembindl.utility.menu")
local <const> k_evme_mn_selected = aesdefs.evme_mn_selected
local <const> k_meba_show = aesdefs.meba_show
local <const> k_meba_erase = aesdefs.meba_erase
local <const> k_meie_disable = aesdefs.meie_disable
local <const> k_meie_enable = aesdefs.meie_enable
local <const> k_evmu_mesag = aesdefs.evmu_mesag
local <const> k_evmu_keybd = aesdefs.evmu_keybd
local <const> k_grmo_arrow = aesdefs.grmo_arrow
aesdefs = nil

local <const> JTstRsrc = {
  evmu_mask = k_evmu_mesag | k_evmu_keybd
}

-- init_job. Initialises the job
-- Returns:
--   1) boolean: true if job initialised successfully
function JTstRsrc:init_job()
  -- Get the loop the job is part of
  local <const> loop = self.loop
  local <const> rsrc, aes, cdefs = loop.rsrc, loop.aes, loop.cdefs

  -- Create new menu
  local <const> menu = k_Menu:new(rsrc, aes, cdefs.mn1)
  self.menu_ = menu

  -- Add menu handlers for each selectable menu entry
  menu:add_handler(cdefs.mn1_file, cdefs.mn1_enable_quit,
    self.mn1_enable_quit_handler)
  menu:add_handler(cdefs.mn1_file, cdefs.mn1_quit,
    self.mn1_quit_handler)

  -- Show the menu bar
  local <const> menu_tree_addr = menu:menu_tree_addr()
  local <const> status = aes:menu_bar(menu_tree_addr, k_meba_show)
  if status == 0 then
    -- Failed to show the menu bar. Indicate to Loop that the
    -- initialisation has failed.
    return false
  end

  -- Disable the quit menu entry
  local status = aes:menu_ienable(menu_tree_addr,
    cdefs.mn1_quit, k_meie_disable)
  assert(status > 0)

  -- Change the mouse pointer to an arrow.
  aes:graf_mouse(k_grmo_arrow)

  -- Menu dispatch without k_evmu_mesag event or shiftkey/keycode
  -- must be ignored
  menu:dispatch(self, 0, 0, 0, 0, 0, 0, 0, nil)

  -- Send a mesag selecting mn1_no_handler. As there is no handler
  -- for this menu entry it must do nothing.
  local <const> ap_id = loop.ap_id
  aes:appl_write_v(
    ap_id,  -- destination application id
    k_evme_mn_selected,  -- message type
    ap_id,  -- sender application id,
    cdefs.mn1_desk,
    cdefs.mn1_no_handler)

  -- Job initialised successfully
  return true
end

function JTstRsrc:dispatch(
    happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  if happened & (k_evmu_keybd | k_evmu_mesag) ~= 0 then
    return self.menu_:dispatch(self,
      happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  end
end

-- term_job. Terminates the job
-- Returns:
--   1) boolean: true if job terminated successfully
function JTstRsrc:term_job()
  -- Erase the menu bar
  local <const> status =
    self.loop.aes:menu_bar(self.menu_:menu_tree_addr(), k_meba_erase)
  return status > 0
end

-- Handler for enable quit
function JTstRsrc:mn1_enable_quit_handler(happened, mx, my,
    button, shiftkey, keycode, clicked, mesag_tbl)
  -- Enable the quit menu entry
  local <const> aes, cdefs, menu =
    self.loop.aes, self.loop.cdefs, self.menu_
  local status = aes:menu_ienable(
    menu:menu_tree_addr(), cdefs.mn1_quit, k_meie_enable)
  assert(status > 0)
  -- Disable the enable quit menu entry
  status = aes:menu_ienable(
    menu:menu_tree_addr(), cdefs.mn1_enable_quit, k_meie_disable)
  assert(status > 0)
end

-- Handler for quit
function JTstRsrc:mn1_quit_handler(happened, mx, my,
    button, shiftkey, keycode, clicked, mesag_tbl)
  -- Stop the loop. This will quit the program.
  self.loop:stop()
end

return JTstRsrc
