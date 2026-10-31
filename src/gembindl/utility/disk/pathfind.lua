global assert, ipairs, require, type, string, gemdos

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_Path = k_RCache.require("gembindl.utility.disk.path")

local <const> k_getenv = gemdos.utility.getenv
local <const> k_Fopen = gemdos.Fopen
local <const> k_o_readonly = gemdos.const.Fopen.readonly
local <const> k_validate_path = k_Path.validate_path
local <const> k_normalize_path = k_Path.normalize_path
local <const> k_fname_from_path = k_Path.fname_from_path
local <const> k_fname_split = k_Path.fname_split

local <const> PathFind = {}

-- search_path.
-- Search for rel_path against alt_paths, trying alt_exts if necessary
-- for each alternative path.
-- Input:
--   1) string: rel_path: the relative path to be searched for
--   2) option string: alt_paths: the ';' delimited alt paths to be checked
--   3) optional table: alt_exts: alternate extensions e.g. { "TXT", "DOC" }
-- Returns:
--   1) string: the absolute path, otherwise nil if not found
local <const> empty_tbl = {}
function PathFind.search_path(rel_path, alt_paths, alt_exts)
  alt_paths = alt_paths or ".;"
  alt_exts = alt_exts or empty_tbl
  assert(type(rel_path) == "string" and
    type(alt_paths) == "string" and
    type(alt_exts == "table"))

  -- Validate the relative path
  if not k_validate_path(rel_path) then
    return nil
  end

  -- Get the fname from the relative path
  local <const> rel_path_fname = k_fname_from_path(rel_path)
  -- Get the filename leading before the dot and extension
  local <const> leading = k_fname_split(rel_path_fname)
  -- The relative path containing the file
  local <const> rel_path_dir =
    string.sub(rel_path, 1, #rel_path - #rel_path_fname)

  -- Loop through each alternate path component separated by ';'
  local resolved_path
  for component in string.gmatch(alt_paths, "([^;]+);*") do
    -- Try open it directly
    local <const> norm_ec, direct_path =
      k_normalize_path(component .. "\\" .. rel_path)
    if norm_ec == 0 then
      local <const> open_ec, fud <close> = k_Fopen(direct_path, k_o_readonly)
      if open_ec == 0 then
        -- Found it directly
        resolved_path = direct_path
        break
      end
    end

    -- Did not find it directly. Try alt_extensions.
    for _, ext in ipairs(alt_exts) do
      local <const> norm_ec, try_path =
        k_normalize_path(component .. "\\" ..
          rel_path_dir .. leading .. "." .. ext)
      if norm_ec == 0 then
        local <const> open_ec2, fud2 <close> = k_Fopen(try_path, k_o_readonly)
        if open_ec2 == 0 then
          -- Found a match
          resolved_path = try_path
          break;
        end
      end
    end
  end

  return resolved_path
end

-- cwd_env_path
-- Returns a string containing '.;' followed by the GEMDOS PATH environment
-- variable value. cwd in the function name means current working directory.
-- Returns:
--   1) string: '.;' concatentated with "PATH" environment variable
function PathFind.cwd_env_path()
  local <const> gemdos_path = k_getenv("PATH")
  return ".;" .. (gemdos_path ~= nil and gemdos_path or "")
end

return PathFind
