global assert, ipairs, pairs, require, string, type, gemdos

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_Path = k_RCache.require("gembindl.utility.disk.path")

local <const> k_ENMFIL = gemdos.const.Error.ENMFIL
local <const> k_EFILNF = gemdos.const.Error.EFILNF
local <const> k_dir_attribute = gemdos.const.Fattrib.dir
local <const> k_Fsfirst = gemdos.Fsfirst
local <const> k_esc = gemdos.utility.esc

local <const> DirScan = {}

-- Mask of all file attributes
local all_attr = 0
for _, v in pairs(gemdos.const.Fattrib) do
  all_attr = all_attr | v
end

local function filter_search_ec(ec)
  -- Fsfirst and Fsnext return ENMFIL and EFILNF during normal operation
  return ec < 0 and ec ~= k_ENMFIL and ec ~= k_EFILNF and ec or 0
end

-- default_fn. Called by the directory scanner if the supplied fn was nil
-- Inputs:
--   1) path: The directory that has been scanned
--   2) boolean: True when descending the tree, false when ascending
--   3) table: Array of directory DTAs contained in the directory
--   4) table: Array of file DTAs contained in the directory
-- Returns:
--   1) integer: 0 to continue scanning, non-zero to terminate the scan
local function default_fn(path, descending, dirs, files)
  if descending then
    for k,v in ipairs(files) do
      gemdos.Cconws(string.format("%s%s%s\r\n",
        path, #path == 3 and "" or "\\", v:name()))
    end
  end
  k_esc()
  return 0
end

-- dir_scan. Scans a directory path using a wildcard, optionally recursive.
-- Calls the supplied function twice for each directory scanned, once in
-- the descending directory and once in the ascending direction - this
-- applies even if recursion is disabled.
-- Inputs:
--   1) string: The directory path to scan
--   2) string: The wildcard, e.g. "*.LUA", "FILE.TXT"
--   3) boolean: true to enable recursion
--   4) function: The function to call for each directory scanned
--   NOTE: See default_fn for an example function for fn parameter.
-- Returns:
--   1) integer: 0 on success, non-zero on failure
function DirScan.dir_scan(path, wildcard, recursive, fn)
  path = path or "."
  wildcard = wildcard or "*.*"
  recursive = recursive or false
  fn = fn or default_fn

  -- Replace empty path with current directory
  if path == "" then
    path = "."
  end

  assert(type(path) == "string")
  assert(type(fn) == "function")
  assert(type(recursive) == "boolean")
  assert(type(wildcard) == "string")

  -- Normalize the path
  local ec
  ec, path = k_Path.normalize_path(path)
  if ec ~= 0 then
    return ec
  end

  local i
  i = function(path)
    local dirs = {}   -- Directory DTAs
    local files = {}  -- File DTAs

    -- Obtain the DTAs of all directories in this directory
    -- Use *.* wildcard as all directories are checked
    local <const> dir_wild = #path == 3 and
      (path .. "*.*") or (path .. "\\" .. "*.*")

    local dta
    ec, dta = k_Fsfirst(dir_wild, k_dir_attribute)
    while (ec == 0) do
      local <const> entry_attr = dta:attr()
      if entry_attr & k_dir_attribute ~= 0 then
        local <const> entry_name = dta:name()
        if entry_name ~= "." and entry_name ~= ".." then
          dirs[#dirs + 1] = dta:copydta()
        end
      end
      ec = dta:snext()
    end

    -- Did an unwanted error occur while obtaining directory DTAs?
    ec = filter_search_ec(ec)
    if ec ~= 0 then
      return ec
    end

    -- Obtain the DTAs of all wildcarded files in this directory
    local <const> file_wild = #path == 3 and
      (path .. wildcard) or (path .. "\\" .. wildcard)

    -- Find files excluding directories
    ec, dta = k_Fsfirst(file_wild, all_attr ~ k_dir_attribute)
    while (ec == 0) do
      local <const> entry_attr = dta:attr()
      if entry_attr & k_dir_attribute == 0 then
        files[#files + 1] = dta:copydta()
      end
      ec = dta:snext()
    end

    -- Did an unwanted error occur while obtaining the file DTAs?
    ec = filter_search_ec(ec)
    if ec ~= 0 then
      return ec
    end

    -- Descending callback
    ec = fn(path, true, dirs, files)
    assert(type(ec) == "number")

    -- Did function return error?
    if ec ~= 0 then
      return ec
    end

    if recursive then
      for _, dta in ipairs(dirs) do
        local <const> sub_path = #path == 3 and
          (path .. dta:name()) or (path .. "\\" .. dta:name())

        -- Process the directory
        ec = i(sub_path)
        if ec ~= 0 then
          break
        end
      end
    end

    -- Check error
    if ec ~= 0 then
      return ec
    end

    -- Ascending callback
    ec = fn(path, false, dirs, files)
    assert(type(ec) == "number")

    return ec
  end

  return i(path)
end

return DirScan
