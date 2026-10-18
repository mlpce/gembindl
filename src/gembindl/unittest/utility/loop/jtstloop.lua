global assert, require, setmetatable, next, ipairs, pairs, string, type,
  gemdos

local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_evmu_timer = aesdefs.evmu_timer
local <const> k_evmu_keybd = aesdefs.evmu_keybd
local <const> k_evmu_mesag = aesdefs.evmu_mesag
local <const> k_evmu_button = aesdefs.evmu_button
local <const> k_grmo_arrow = aesdefs.grmo_arrow
aesdefs = nil

local <const> k_mesag_type_jtstloop = 3 -- mesag sent to JTstLoop
local <const> k_mesag_type_jtester = 4 -- mesag sent to JTester

local <const> JTstLoop = {
  evmu_mask = k_evmu_mesag, -- JTstLoop receives mesag events
  subjobs_ = {} -- Running JTester jobs added to subjobs_
}

local <const> JTester = {
  evmu_mask = 0 -- Customised by each JTester instance
}

-- new. Create a new JTester job
-- Input:
--   1) integer: the event mask for the job
-- Returns:
--   1) table: the table instance
function JTester:new(mask, o)
  o = o or {}
  o.evmu_mask = mask -- Set the event mask for the instance
  self.__index = self
  return setmetatable(o, self)
end

-- Get description string for an event
local function event_desc(event)
  if event == k_evmu_keybd then
    return "key event"
  elseif event == k_evmu_button then
    return "mouse button event"
  elseif event == k_evmu_mesag then
    return "mesag event"
  elseif event == k_evmu_timer then
    return "timer event"
  end
  return "unhandled event"
end

-- init_job. Initialises the job
-- Returns:
--   1) boolean: true if job initialised successfully
function JTester:init_job()
  -- Log what event the job is waiting for
  gemdos.Cconws(
    string.format(
    "JTester: init_job: Job id: %d name: '%s' waiting for: '%s'\r\n",
    self.job_id, self.job_name, event_desc(self.evmu_mask)))
  return true
end

function JTester:dispatch(
    happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  -- Check the correct event was dispatched
  assert(happened & self.evmu_mask ~= 0)

  if happened == k_evmu_mesag and mesag[1] ~= k_mesag_type_jtester then
    -- mesag was for the jtstloop so ignore
    return
  end

  -- Log what event the job has received
  gemdos.Cconws(
    string.format(
    "JTester: dispatch: Job id: %d name: '%s' event: '%s'\r\n",
    self.job_id, self.job_name, event_desc(happened)))

  -- Delete the job
  self.loop:del_job(self)
end

-- term_job. Terminates the job
-- Returns:
--   1) boolean: true if job terminated successfully
function JTester:term_job()
  gemdos.Cconws(
    string.format(
    "JTester: term_job: Job id: %d name: '%s'\r\n",
    self.job_id, self.job_name))
  return true
end

-- init_job. Initialises the job
-- Returns:
--   1) boolean: true if job initialised successfully
function JTstLoop:init_job()
  -- Get the loop the job is part of
  local <const> loop = self.loop
  local <const> aes = loop.aes
  local <const> ap_id = loop.ap_id

  gemdos.Cconws("Adding tester jobs\r\n")
  gemdos.Cconws("Press key and mouse button\r\n")

  -- Change the mouse pointer to an arrow.
  loop.aes:graf_mouse(k_grmo_arrow)

  -- on_update function for passing to Loop:add_job
  local <const> on_update = function(job, update_type, result)
      assert(result)
      assert(update_type == "init" or update_type == "term")
      if update_type == "init" then
        self.subjobs_[job] = job.job_name
      elseif update_type == "term" then
        self.subjobs_[job] = nil
      end

      -- Send a mesag to JTstLoop indicating JTester job has
      -- initialised or terminated
      local <const> status = aes:appl_write_v(
        ap_id, -- destination application id
        k_mesag_type_jtstloop, -- message type
        ap_id, -- sender application id,
        job.job_id, -- job_id that has init or term
        update_type == "init" and 1 or 0 -- 1 for init, 0 for term
      )
      assert(status > 0)
    end

  -- add_job_and_check function adds the JTester job and checks
  -- the job's properties and that it is accessible from the Loop
  local <const> loop = self.loop
  local <const> add_job_and_check = function(event_mask, name, bias)
    local <const> j = JTester:new(event_mask)
    loop:add_job(j, name, bias, on_update)
    -- Check Loop has set job properties
    assert(type(j.job_id) == "number")
    assert(j.job_name == name)
    assert(j.bias == bias)
    assert(j.loop == loop)
    assert(j.on_update == on_update)
    -- Check job is accessible by job name and job id
    assert(loop:get_job_by_name(name) == j)
    assert(loop:get_job_by_id(j.job_id) == j)
    self.last_added_job_id_ = j.job_id
    -- Deleting job that has not been started yet has no effect
    loop:del_job(j)
  end

  -- Job descriptions for the JTester jobs. Each JTester job
  -- has an event mask, a job name, and a bias. Jobs are dispatched
  -- in bias order, and for same bias in job_id order.
  self.job_desc_ = { 
    { k_evmu_keybd, "keyboard", 2 },
    { k_evmu_button, "button", 1 },
    { k_evmu_mesag, "mesag", 3 },
    { k_evmu_timer, "timer", 3 }
  }

  -- Add the described JTester jobs
  for k,v in ipairs(self.job_desc_) do
    add_job_and_check(v[1], v[2], v[3])
  end

  -- Set loop timer timeout, used for sending the timer event to
  -- the timer JTester job.
  loop:set_timeout(1)

  -- Jobs should not be iterable yet as they have not been started.
  -- Even JTstLoop is still initialising.
  assert(loop:jobs()() == nil)

  -- JTstLoop job initialise completed
  return true
end

-- Dispatch handler for JTstLoop.
function JTstLoop:dispatch(
    happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  assert(happened & k_evmu_mesag ~= 0)
  if mesag[1] ~= k_mesag_type_jtstloop then
    -- mesag was for the JTester job so ignore
    return
  end

  -- Message recieved indicates that a JTester job has either
  -- initialised or terminated.
  local <const> job_id = mesag[4]
  local <const> is_init = mesag[5] == 1
  gemdos.Cconws("JTstLoop: job_id " .. job_id .. " has " ..
    (is_init and "initialised" or "terminated") .. "\r\n")

  -- Has the JTester job initialised or terminated?
  local <const> loop = self.loop
  if is_init then
    -- Has the last JTester job launched been intialised?
    if job_id == self.last_added_job_id_ then
      -- Check the job order. Jobs are ordered by bias, and for identical
      -- bias by job id.
      local last_bias = 0
      local last_job_id = 0

      for j in loop:jobs() do
        -- Jobs are ordered by increasing bias
        assert(j.bias >= last_bias)
        -- And for equal bias by job_id
        if j.bias == last_bias then
          assert(j.job_id > last_job_id)
        end
        last_bias = j.bias
        last_job_id = j.job_id
      end

      -- Send JTester job a mesag
      local <const> aes = loop.aes
      local <const> ap_id = loop.ap_id
      gemdos.Cconws("JTstLoop: Sending mesag to JTester\r\n")
      local <const> status = aes:appl_write_v(
        ap_id, -- destination application id
        k_mesag_type_jtester, -- message type
        ap_id -- sender application id,
      )
      assert(status > 0)
    end
  else
    -- JTester job has terminated, log what JTester jobs are still
    -- running.
    for j in loop:jobs() do
      if j.job_id ~= 1 then
        gemdos.Cconws("JTstLoop: Still waiting for Job id: " ..
          j.job_id .. " wanting: '" ..
          event_desc(j.evmu_mask) .. "'\r\n")
      end
    end
  end
  -- Are there any JTester jobs left? If not then delete JTstLoop.
  if not next(self.subjobs_) then
    -- No more subjobs - delete the job
    gemdos.Cconws("JTstLoop: JTester jobs complete\r\n")
    loop:del_job(self)
  end
end

-- term_job. Terminates the job
-- Returns:
--   1) boolean: true if job terminated successfully
function JTstLoop:term_job()
  -- Job terminated successfully
  return true
end

return JTstLoop
