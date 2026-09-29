global assert, ipairs, require, setmetatable, string, table, tostring, warn

local <const> k_RCache = require("gembindl.utility.rcache")

local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_evmu_mesag = aesdefs.evmu_mesag
aesdefs = nil

local <const> JLogger = {
}

-- new. Create a new JLogger instance
-- Inputs:
--   1) table: o: optional table to use as instance
function JLogger:new(o)
  o = o or {}
  o.evmu_mask = -1
  o.buffer_ = table.create(25)
  -- Default to 100 max lines
  o.max_lines_ = 100
  o.log_count_ = 0
  self.__index = self
  return setmetatable(o, self)
end

-- set_max_lines. Sets the maximum number of lines in the log
-- Inputs:
--   1) integer: max_lines: the maximum number of lines
function JLogger:set_max_lines(max_lines)
  self.max_lines_ = max_lines
  if self.jtxtview_ then
    return self.jtxtview_:set_max_lines(self.max_lines_)
  end
end

-- init_job. Initialises the job
-- Returns:
--   1) boolean: true if job initialised successfully
function JLogger:init_job()
  return true
end

-- term_job. Terminates the job
-- Returns:
--   1) boolean: true if job terminated successfully
function JLogger:term_job()
  if self.old_warn_ then
    -- Disable warn using this logger
    self:set_warn(false)
  end

  if self.jtxtview_ then
    self.loop:del_job(self.jtxtview_)
  end
  return true
end

-- dispatch. Dispatch to the JLogger
-- Inputs:
--   1) integer: happened: the events that happened
--   2) integer: mx: mouse x position
--   3) integer: my: mouse y position
--   4) integer: button: buttons pressed
--   5) integer: keycode: the keycode
--   6) integer: clicks: the number of clicks
--   7) table: mesag: the mesag
function JLogger:dispatch(
    happened, mx, my, button, shiftkey, keycode, clicked, mesag)
  return self:send_buffer_(self.jtxtview_, self.buffer_)
end

-- log. Logs a message
-- Inputs:
--   1) string: message: the string to log
--   2) vararg: subsequent strings to concatenate
function JLogger:log(msg1, ...vararg)
  for k = 1, vararg.n do
    msg1 = msg1 .. tostring(vararg[k])
  end

  local <const> buff = self.buffer_
  self.log_count_ = self.log_count_ + 1
  buff[#buff + 1] = string.format("%d: %s", self.log_count_, msg1)
  return self:constrain_max_lines_(self.max_lines_)
end

-- set_warn. Enables/disables warn using this logger
-- Warnings going to multiple loggers is not handled therefore
-- only enable one JLogger for warn at a time.
-- Input:
--   1) boolean: enable: true to enable logger, false to disable
function JLogger:set_warn(enable)
  if enable then
    assert(not self.old_warn_)
    self.old_warn_ = warn
    warn = function(msg1, ...) return self:warn_(msg1, ...) end
    warn("@on")
  else
    assert(self.old_warn_)
    warn("@off")
    warn = self.old_warn_
  end
end

-- Outputs warning to this logger
function JLogger:warn_(msg1, ...)
  if msg1 == "@on" then
    self.warn_on_ = true
  elseif msg1 == "@off" then
    self.warn_on_ = false
  elseif self.warn_on_ then
    local message = "warn: " .. msg1
    return self:log(message, ...)
  end
end

-- open_window. Opens the logger window
function JLogger:open_window()
  if not self.jtxtview_ then
    -- Create the JTxtView
    local <const> JTxtView =
      k_RCache.require("gembindl.utility.jobs.jtxtview")
    local <const> jtxtview = JTxtView:new()
    jtxtview:set_name("Logger")
    jtxtview:set_max_lines(self.max_lines_)
    jtxtview:set_small_text(true)
    -- Add the initial lines
    self:send_buffer_(jtxtview, self.buffer_)

    self.loop:add_job(jtxtview, "logger txtview", self.bias + 1,
      function(job, update_type, result)
        if not result then
          return
        elseif update_type == "init" then
          -- JTxtView initialised successfully
          self.jtxtview_ = job
        elseif update_type == "term" then
          -- JTxtView terminated successfully
          return self:txtview_stopped_()
        end
      end)
  else
    -- Top the existing JTxtView
    return self.jtxtview_:set_top()
  end
end

-- txtview_stopped_. keep the lines.
function JLogger:txtview_stopped_()
  local <const> lines = self.jtxtview_:get_lines()
  for k,v in ipairs(self.buffer_) do
    lines[lines.n + k] = v
  end
  lines.n = nil -- buffer_ doesn't use .n
  self.buffer_ = lines
  self.jtxtview_ = nil
end

-- Constrain the maximum lines
function JLogger:constrain_max_lines_(max_lines)
  local <const> buff = self.buffer_
  local <const> n = #buff
  if n > max_lines then
    local <const> n_remove = n - max_lines
    table.move(buff, n_remove + 1, n, 1)
    for k = n, max_lines + 1, -1 do
      buff[k] = nil
    end
  end
end

-- send_buffer_. Sends lines to jtxtview
function JLogger:send_buffer_(jtxtview, buff)
  if jtxtview and #buff > 0 then
    -- Append messages to JTxtView
    jtxtview:append_array(buff)
    for k, v in ipairs(buff) do
      buff[k] = nil
    end
  end
end

return JLogger
