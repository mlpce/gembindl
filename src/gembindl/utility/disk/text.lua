global ipairs, tonumber, string, gemdos

local <const> k_Fopen = gemdos.Fopen
local <const> k_o_readonly = gemdos.const.Fopen.readonly

local <const> Text = {}

-- load_lines
-- loads a text file into an array of lines
-- Input:
--   1) string: path to the text file
-- Returns:
--   1) integer: negative gemdos error code on failure, otherwise zero
--   2) table: array of lines
function Text.load_lines(path)
  local tbl = {}
  local ec, fud <close> = k_Fopen(path, k_o_readonly)
  if ec < 0 then
    return ec, tbl
  end

  local init = 1
  local str = ""
  local read_size = 80
  ec = 1
  while ec > 0 do
    -- Scan the string for newline
    -- First look for \r\n
    local rn_index, rn_index_end = string.find(str, "\r\n", init)
    -- Next look for \n
    local n_index, n_index_end = string.find(str, "\n", init)
    -- Use the closest if any
    local index, index_end
    if rn_index and n_index then
      if rn_index < n_index then
        index, index_end = rn_index, rn_index_end
      else
        index, index_end = n_index, n_index_end
      end
    elseif rn_index then
      index, index_end = rn_index, rn_index_end
    elseif n_index then
      index, index_end = n_index, n_index_end
    end
    if index then
      -- Found a line ending, output the string before it
      tbl[#tbl + 1] = string.sub(str, init, index - 1)
      init = index_end + 1
    else
      -- Line ending wasn't found - read more characters
      local <const> last = string.sub(str, init)
      ec, str = fud:reads(read_size)
      if ec > 0 then
        -- Append the characters read to the last string
        str = last .. str
        init = 1
        ec = #str
      elseif ec == 0 then
        -- End of file
        if #last > 0 then
          tbl[#tbl + 1] = last
        end
      end
    end
  end

  return ec, tbl
end

-- load_cdefs
-- loads simple C definitions from a file in line format '#define def number'
-- Used for loading e.g. rsrc header for object names and values
-- Input:
--   1) string: file path
-- Returns:
--   1) integer: negative gemdos error code on failure, othewise zero
--   2) table: define names as keys, define values as values
function Text.load_cdefs(path)
  local ec, lines_tbl = Text.load_lines(path)
  if ec < 0 then
    return ec, lines_tbl
  end

  local defs_tbl = {}
  for k,v in ipairs(lines_tbl) do
    for define, value in string.gmatch(v,  "#define%s+(%g+)%s+(%d+)") do
      defs_tbl[define] = tonumber(value)
    end
  end
  return 0, defs_tbl
end

return Text
