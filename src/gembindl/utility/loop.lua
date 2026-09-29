global assert, error, ipairs, pairs, require, setmetatable, string,
  table, type, warn, gemdos, gempb

local <const> k_aes_global = gempb.const.Pbid.aes_global

local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local msgdefs = k_RCache.require("gembindl.utility.defs.msgdefs")
local <const> k_evme_mn_selected = aesdefs.evme_mn_selected
local <const> k_evmu_keybd = aesdefs.evmu_keybd
local <const> k_evmu_button = aesdefs.evmu_button
local <const> k_evmu_mesag = aesdefs.evmu_mesag
local <const> k_loop_events = k_evmu_keybd | k_evmu_button | k_evmu_mesag
local <const> k_evbu_left_button = aesdefs.evbu_left_button

local <const> k_mesag_internal = msgdefs.mesag_internal 
aesdefs = nil
msgdefs = nil

local <const> Loop = {}

-- Create a new loop
-- Input:
--   1) table: aes: aes instance
--   2) table: vdi: vdi instance
--   3) table: rsrc: rsrc instance
--   4) string: rsrc_dir: the directory that contains the resource file
--   5) table: cdefs: C defines table for the resource
-- Returns:
--   1) table: the loop instance
function Loop:new(aes, vdi, rsrc, rsrc_dir, cdefs, o)
  o = o or {}

  -- Used by jobs
  o.aes = aes
  o.vdi = vdi
  o.rsrc = rsrc
  o.rsrc_dir = rsrc_dir
  o.cdefs = cdefs
  o.return_code = 0
  o.ap_id = aes:pb():peek(k_aes_global, 2)

  -- Raise an error if key is not found in cdefs
  setmetatable(cdefs, { __index = function(t, k)
      return error(string.format("key %q not in cdefs", k), 2)
    end })

  -- Used internally
  o.jobs_ = {}
  o.new_jobs_ = {}
  o.init_jobs_  = {}
  o.del_jobs_ = {}
  o.term_jobs_ = {}
  o.ordered_ = {}
  o.next_job_id_ = 1
  o.jobs_updated_ = false
  o.running_ = true
  o.timelo_ = 0
  o.timehi_ = 0

  self.__index = self
  return setmetatable(o, self)
end

-- add_job. Add a new job to the loop
-- Input:
--   1) table: The job to add
--   2) string: The name of the job
--   3) integer: relative bias for dispatch
--   4) on_update: function to call when a job is updated
--      NOTE: on_update(update_type, result)
function Loop:add_job(job, job_name, bias, on_update)
  assert(type(job.evmu_mask) == "number")
  assert(job.job_id == nil)
  assert(type(job_name) == "string")

  bias = bias or 0
  on_update = on_update or function() end

  assert(type(bias) == "number")
  assert(type(on_update) == "function")

  local <const> job_id = self.next_job_id_
  job.job_id = job_id
  job.job_name = job_name
  job.bias = bias
  job.loop = self
  job.on_update = on_update

  -- Add job to new_jobs table
  local <const> new_jobs = self.new_jobs_
  new_jobs[#new_jobs + 1] = job
  self.next_job_id_ = job_id + 1
  self.jobs_updated_ = true
end

-- del_job. Delete a job from the loop
-- Input:
--   1) table: the job to delete
function Loop:del_job(job)
  local <const> job_id = job.job_id
  assert(job_id)

  local <const> job_tbl = self.jobs_[job_id]
  if job_tbl == job then
    -- Job found - add job to del_jobs table
    local <const> del_jobs = self.del_jobs_
    del_jobs[#del_jobs + 1] = job
    self.jobs_updated_ = true
  end
end

-- get_job_by_name. Gets the job using the job name
-- Input:
--   1) string: job_name: the name of the job to obtain
-- Returns:
--   1) table: found job otherwise nil
function Loop:get_job_by_name(job_name)
  for k,v in ipairs(self.new_jobs_) do
    if v.job_name == job_name then
      return v
    end
  end

  for k,v in pairs(self.jobs_) do
    if v.job_name == job_name then
      return v
    end
  end
end

-- get_job_by_id. Gets the job using the job id
-- Input:
--   1) integer: job_id: the job_id of the job to obtain
-- Returns:
--   1) table: found job otherwise nil
function Loop:get_job_by_id(job_id)
  for k,v in ipairs(self.new_jobs_) do
    if v.job_id == job_id then
      return v
    end
  end

  return self.jobs_[job_id]
end

-- jobs. Job iterator factory
-- Returns:
--   1) function: job iterator function
function Loop:jobs()
  local n = 0

  return function()
    if n < #self.ordered_ then
      n = n + 1
      return self.ordered_[n]
    end
  end
end

-- send_mesag. Send a message
function Loop:send_mesag(...)
  local <const> ap_id = self.ap_id
  return self.aes:appl_write_v(
    ap_id,  -- destination application id
    k_mesag_internal,  -- message type
    ap_id,  -- sender application id,
    ...)
end

-- set_timeout. Set timeout
function Loop:set_timeout(timeout)
  self.timelo_ = timeout & 0xFFFF
  self.timehi_ = timeout >> 16
end

-- stop. Stop the loop from running
function Loop:stop()
  self.running_ = false
  self:del_all_jobs_()
end

-- del_all_jobs_. Calls del_job for all jobs
function Loop:del_all_jobs_()
  for k,v in ipairs(self.ordered_) do
    self:del_job(v)
  end
end

-- abort. Terminates all running jobs.
-- This is called from without the loop so jobs are also updated.
function Loop:abort()
  self:stop()
  self:update_jobs_()
end

-- run. Runs the loop
function Loop:run()
  local <const> aes = self.aes
  local <const> ordered = self.ordered_
  local mesag = table.create(8, 1) -- 8 vals and .n field
  local num_jobs = 0

  -- Unblock evnt_multi straight away as a job needs to run
  local evmu_events = k_evmu_mesag
  self:send_mesag()

  repeat
    -- Call evnt_multi
    local happened, mx, my, button, shiftkey, keycode, clicked =
      aes:evnt_multi(
        evmu_events, 2, k_evbu_left_button, k_evbu_left_button,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, self.timelo_, self.timehi_)

    -- read the mesag if one arrived. Any appl_read is left to jobs.
    if happened & k_evmu_mesag ~= 0 then
      -- Read the mesag into a table
      mesag = aes:mesag_t(mesag)
    end

    -- Dispatch events to jobs
    for n = 1, num_jobs do
      local <const> job = ordered[n]
      if job.evmu_mask & happened ~= 0 then
        job:dispatch(happened,
          mx, my, button, shiftkey, keycode, clicked, mesag)
      end
    end

    -- Update the jobs
    if self.jobs_updated_ then
      num_jobs, evmu_events = self:update_jobs_()
    end
  until num_jobs == 0

  return self.return_code
end

-- update_jobs_. Takes jobs from new_jobs and initialises them, adding
-- them to the jobs table. Takes jobs from del_jobs and terminates them,
-- removing them from the jobs table. Finally, sorts the jobs for dispatch
-- into the ordered table according to the job's bias and job_id.
function Loop:update_jobs_()
  local <const> init_jobs = self.init_jobs_
  local <const> new_jobs = self.new_jobs_
  local <const> jobs = self.jobs_
  local <const> term_jobs = self.term_jobs_
  local <const> del_jobs = self.del_jobs_
  local <const> ordered = self.ordered_
  local <const> running = self.running_

  repeat
    self.jobs_updated_ = false

    -- Initialising jobs may add extra jobs, so copy new_jobs to init_jobs
    for k,v in ipairs(new_jobs) do
      init_jobs[k] = v
      new_jobs[k] = nil
    end

    -- Call init_job for each initialising job
    for k,v in ipairs(init_jobs) do
      local <const> job_id = v.job_id
      if running and not jobs[job_id] then
        local <const> init_result = v:init_job()
        if init_result then
          -- Job is running
          jobs[job_id] = v
        else
          warn("Loop: " .. v.job_name .. " init_job failed")
        end
        v:on_update("init", init_result)
      end
      init_jobs[k] = nil
    end

    -- Terminating jobs may del other jobs, so copy del_jobs to term_jobs
    for k,v in ipairs(del_jobs) do
      term_jobs[k] = v
      del_jobs[k] = nil
    end

    -- Call term_job for each terminating job
    for k,v in ipairs(term_jobs) do
      local <const> job_id = v.job_id
      -- Only call term_job if the job is running
      if jobs[job_id] == v then
        local <const> term_result = v:term_job()
        if term_result then
          -- job has terminated
          jobs[job_id] = nil
        else
          warn("Loop: " .. v.job_name .. " term_job failed")
        end
        v:on_update("term", term_result)
      end
      term_jobs[k] = nil
    end
  until not self.jobs_updated_

  -- clear the ordered array
  for k = 1, #ordered do
    ordered[k] = nil
  end

  -- Add jobs to ordered, and generate event bits
  local evmu_events = 0
  for k,v in pairs(jobs) do
    ordered[#ordered + 1] = v
    evmu_events = evmu_events | v.evmu_mask
  end

  -- Sort the ordered table
  table.sort(ordered, self.sort_jobs_)
  return #ordered, evmu_events
end

-- Sorts jobs for dispatch by their bias, and for equal bias by
-- their job_id.
function Loop.sort_jobs_(a, b)
  local <const> a_bias = a.bias
  local <const> b_bias = b.bias
  if a_bias < b_bias then
    return true
  elseif a_bias > b_bias then
    return false
  elseif a.job_id < b.job_id then
    return true
  end
  return false
end

return Loop
