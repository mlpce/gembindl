global assert, require, gemdos

local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_evmu_timer = aesdefs.evmu_timer
local <const> k_grmo_arrow = aesdefs.grmo_arrow
aesdefs = nil

local <const> JJobRsrc = {
  -- Dispatch timer events to the job
  evmu_mask = k_evmu_timer
}

-- init_job. Initialises the job
-- Returns:
--   1) boolean: true if job initialised successfully
function JJobRsrc:init_job()
  -- Get the loop the job is part of
  local <const> loop = self.loop

  -- Read the freestring from the resource
  local <const> rsrc, cdefs = loop.rsrc, loop.cdefs
  local <const> freestring_offset = rsrc:frstr_offset(cdefs.fs1_message)
  local <const> message = rsrc:reads(freestring_offset, nil, 0)
  -- Check it matches the expected value
  assert(message == "JJobRsrc: Testing launcher with a resource file")
  gemdos.Cconws(message .. "\r\n")

  -- Change the mouse pointer to an arrow.
  loop.aes:graf_mouse(k_grmo_arrow)

  -- Set timeout
  loop:set_timeout(1)

  -- Job initialised successfully
  return true
end

function JJobRsrc:dispatch(
    happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  -- Check timer event happened
  assert(happened == k_evmu_timer)
  local <const> loop = self.loop

  -- Set return code
  loop.return_code = 42

  -- Delete the job
  loop:del_job(self)
end

-- term_job. Terminates the job
-- Returns:
--   1) boolean: true if job terminated successfully
function JJobRsrc:term_job()
  -- Job terminated successfully
  return true
end

return JJobRsrc
