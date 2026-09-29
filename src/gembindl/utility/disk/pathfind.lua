global assert, ipairs, require, type, string, gemdos

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_Path = k_RCache.require("gembindl.utility.disk.path")

local <const> k_getenv = gemdos.utility.getenv
local <const> k_Fopen = gemdos.Fopen
local <const> k_o_readonly = gemdos.const.Fopen.readonly
local <const> k_validate_path = k_Path.validate_path
local <const> k_normalize_path = k_Path.normalize_path
local <const> k_dir_from_path = k_Path.dir_from_path
local <const> k_fname_from_path = k_Path.fname_from_path
local <const> k_fname_split = k_Path.fname_split

local <const> PathFind = {}

-- search_path.
-- Search for rel_path against paths, trying alt_exts if necessary
-- Input:
--   1) string: rel_path: the relative path to be searched for
--   2) option string: paths: the ';' delimited paths to be checked
--   3) optional table: alt_exts: alternate extensions e.g. { "TXT", "DOC" }
-- Returns:
--   1) string: the absolute path, otherwise nil if not found
local <const> empty_tbl = {}
function PathFind.search_path(rel_path, paths, alt_exts)
  paths = paths or ".;"
  alt_exts = alt_exts or empty_tbl
  assert(type(rel_path) == "string" and
    type(paths) == "string" and
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

  -- Loop through each path component separated by ';'
  local resolved_path
  for component in string.gmatch(paths, "([^;]+);*") do
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

-- find_file
-- Input:
--   1) string: srch_path: absolute or relative search path
--   2) optional string: alt_paths: semicolon seperated alt paths
--   3) optional table: alt_exts: alternate extensions e.g. { "TXT", "DOC" }
--   NOTE: alt_paths is only used if srch_path is relative
-- Returns:
--   1) string: the absolute path, otherwise nil if not found
function PathFind.find_file(srch_path, alt_paths, alt_exts)
  alt_paths = alt_paths or ".;"
  alt_exts = alt_exts or empty_tbl

  assert(type(srch_path) == "string" and
    type(alt_paths) == "string" and
    type(alt_exts) == "table")

  local paths
  local rel_path
  if k_Path.is_abs_path(srch_path) then
    -- paths is the absolute directory
    paths = k_dir_from_path(srch_path)
    -- Relative path is the filename
    rel_path = k_fname_from_path(srch_path)
  else
    -- paths is the alt_paths
    paths = alt_paths
    -- Rel path is the srch_path
    rel_path = srch_path
  end

  -- Search for rel_path in paths, if necessary trying alt_exts
  return PathFind.search_path(rel_path, paths, alt_exts)
end

-- alt_paths
-- Gets semicolon separated alternate paths using GEMDOS PATH
-- Returns:
--   1) string: semicolon delimited alternate paths
function PathFind.alt_paths()
  local <const> gemdos_path = k_getenv("PATH")
  local <const> alt_paths = ".;" .. (gemdos_path ~= nil and gemdos_path or "")
  return alt_paths
end

-- find_program
-- Finds a program, trying GEMDOS PATH and alternate extensions
-- Input:
--   1) string: the absolute or relative path
-- Returns:
--   1) string: the absolute path, otherwise nil if not found
function PathFind.find_program(path)
  return PathFind.find_file(path, PathFind.alt_paths(),
    { "TTP", "TOS", "PRG" })
end

return PathFind
