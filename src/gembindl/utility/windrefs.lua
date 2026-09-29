global assert, pairs, setmetatable, table

local <const> WindRefs = {
  refs_ = {}
}

setmetatable(WindRefs.refs_, {__mode = "kv"})

-- add_wind. Adds a Wind.
-- Inputs:
--   1) table: wind: the Wind
function WindRefs:add_wind(wind)
  self.refs_[wind:handle()] = wind
end

-- remove_wind. Removes a Wind.
-- Inputs:
--   1) table: wind: the Wind
function WindRefs:remove_wind(wind)
  self.refs_[wind:handle()] = nil
end

-- get_wind. Gets the wind from the window handle
-- Returns:
--   1) table: the Wind table
function WindRefs:get_wind(wi_handle)
  return self.refs_[wi_handle]
end

-- pairs. Returns pairs for Wind reference table
-- Returns:
--   1) function: Winds iterator function
function WindRefs:pairs()
  return pairs(self.refs_)
end

-- call_modal. Call a modal dialog
-- Inputs:
--   1) function: dialog_f: function to display the modal dialog
-- Returns:
--   Values from dialog_f
function WindRefs:call_modal(dialog_f)
  -- Inform each view that a modal dialog is about to be displayed
  for k,v in self:pairs() do
    v:view():view_modal_override(true)
  end

  -- Display the modal dialog, storing the results in modal_pack_t
  local <const> modal_pack_t = table.pack(dialog_f())

  -- Inform each view that the modal dialog has been removed
  for k,v in self:pairs() do
    v:view():view_modal_override(false)
  end

  -- Return the results
  return table.unpack(modal_pack_t, 1, modal_pack_t.n)
end

return WindRefs
