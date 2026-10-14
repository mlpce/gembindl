global assert, debug, gemdos, gempb, loadfile, pcall, require, string, xpcall

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_AES = k_RCache.require("gembindl.aes")
local <const> k_VDI = k_RCache.require("gembindl.vdi")
local <const> k_Loop = k_RCache.require("gembindl.utility.loop")
local <const> k_Rsrc = k_RCache.require("gembindl.utility.resource.rsrc")
local <const> k_Path = k_RCache.require("gembindl.utility.disk.path")

local <const> error_handler = debug and debug.traceback or
  function(err) return err end

local <const> Launcher = {}

-- Launch a program
-- Inputs:
--   1) string: jobinit_fname: Name of the initial job
--   2) optional string: rsrc_fname: Name of the resource file
--   3) optional string: header_fname: Name of the resource C header
function Launcher:launch(jobinit_fname, rsrc_fname, header_fname)
  -- The initial job to launch must be specified
  assert(jobinit_fname)
  if rsrc_fname or header_fname then
    -- If the program uses a resource file, both the resource filename
    -- and C header filename must be specified.
    assert(rsrc_fname and header_fname)
  end

  -- Create the GEM parameter block
  local <const> pb = gempb.create_pb()
  -- Create AES and VDI tables using the created parameter block
  local <const> aes, vdi = k_AES:new(pb), k_VDI:new(pb)

  -- Initialise with AES
  self.ap_id_, self.aes_ver_ = aes:appl_init()
  if self.ap_id_ == -1 then
    gemdos.Cconws("appl_init failed\r\n")
    return 1
  end

  -- Load assets: initial job, optionally resource and its C header
  local status, alert_str, jobinit_error_str =
    self:load_assets_(aes, jobinit_fname, rsrc_fname, header_fname)
  if not status then
    -- If loadfile for jobinit failed then log the error
    if jobinit_error_str then
      gemdos.Cconws("jobinit: load: " ..
        string.gsub(jobinit_error_str, "\r?\n", "\r\n") .. "\r\n")
    end

    -- Display alert showing reason for failure
    aes:form_alert(1, alert_str)

    -- Launch failed
    aes:appl_exit()
    return 1
  end

  -- If a resource is being used then wrap it
  local rsrc
  if rsrc_fname then
    rsrc = k_Rsrc:new(pb)
    rsrc:wrap()
  end

  -- Create the event loop. rsrc and self.cdefs_ may be nil
  local <const> loop = k_Loop:new(aes, vdi,
    self.jobinit_dir_, rsrc, self.cdefs_)

  -- Call jobinit_ chunk for initial job
  local istatus <const>, initial_job = xpcall(self.jobinit_, error_handler)
  local return_code = 1
  if istatus then
    -- Add the initial job to the loop
    loop:add_job(initial_job, "init")

    -- Done with initial job
    self.jobinit_ = nil
    initial_job = nil

    -- Run the loop until exit
    local <const> rstatus, v = xpcall(loop.run, error_handler, loop)
    if not rstatus then
      -- The loop failed, abort the loop jobs
      local <const> astatus, av = pcall(loop.abort, loop)

      -- An error occurred while running the loop. v is a string
      -- describing the error
      gemdos.Cconws("run: error: " ..
        string.gsub(v, "\r?\n", "\r\n") .. "\r\n")

      if not astatus then
        -- Additionally, an error occurred while aborting the loop.
        -- av is a string describing the error
        gemdos.Cconws("run: abort: " ..
          string.gsub(av, "\r?\n", "\r\n") .. "\r\n")
      end

      aes:form_alert(1, "[3][error during Loop:run()][Exit]")
    else
      return_code = v
    end
  else
    -- An error occurred while calling jobinit chunk
    -- initial_job is a string describing the error
    gemdos.Cconws("jobinit: failed: " ..
      string.gsub(initial_job, "\r?\n", "\r\n") .. "\r\n")
    aes:form_alert(1, "[3][error calling jobinit chunk][Exit]")
  end

  -- If using a resource then unwrap it and free it
  if rsrc then
    -- Unwrap the resource
    rsrc:unwrap()
    -- Free the resource
    aes:rsrc_free()
  end

  -- appl_exit
  aes:appl_exit()

  return return_code
end

-- Load assets
function Launcher:load_assets_(aes, jobinit_fname, rsrc_fname, header_fname)
  -- Find the initial job
  local status, jobinit_location = aes:shel_find(jobinit_fname)
  local jobinit_found
  if status > 0 then
    -- Found initial job. Normalize the path.
    status, jobinit_location = k_Path.normalize_path(jobinit_location)
    -- status will be 0 if normalize was successful
    jobinit_found = status == 0
  end

  if not jobinit_found then
    return false,
      "[3][Could not find job|file " .. jobinit_fname .. "][Exit]"
  end

  -- Get directory containing the initial job
  self.jobinit_dir_ = k_Path.dir_from_path(jobinit_location)

  -- Load the initial job
  local jobinit_error_str
  self.jobinit_, jobinit_error_str = loadfile(jobinit_location)
  if not self.jobinit_ then
    -- jobinit could not be loaded
    -- jobinit_error_str is a string describing the error
    return false,
      "[3][Could not load job|file " .. jobinit_fname .. "][Exit]",
      jobinit_error_str
  end

  -- When using a resource both the resource filename and C header
  -- filename must be specified.
  if rsrc_fname and header_fname then
    -- Load cdefs for resource file
    local ec
    ec, self.cdefs_ =
      k_RCache.require("gembindl.utility.disk.text").load_cdefs(
        k_Path.join_path(self.jobinit_dir_, header_fname))
    if ec ~= 0 then
      -- Header file could not be loaded
      return false,
        "[3][Could not load header|file " .. header_fname .. "][Exit]"
    end

    -- Load resource file
    status = aes:rsrc_load(rsrc_fname)
    if status <= 0 then
      return false,
        "[3][Could not load resource|file " .. rsrc_fname .. "][Exit]"
    end
  end

  return true
end

return Launcher
