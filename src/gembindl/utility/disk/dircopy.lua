global assert, ipairs, require, string, type, gemdos

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_Path = k_RCache.require("gembindl.utility.disk.path")
local <const> k_FileCopy = k_RCache.require("gembindl.utility.disk.filecopy")
local <const> k_DirScan = k_RCache.require("gembindl.utility.disk.dirscan")

local <const> k_normalize_path = k_Path.normalize_path
local <const> k_join_path = k_Path.join_path
local <const> k_file_copy = k_FileCopy.file_copy
local <const> k_Fsfirst = gemdos.Fsfirst
local <const> k_Dcreate = gemdos.Dcreate
local <const> k_dir_attribute = gemdos.const.Fattrib.dir
local <const> k_volume_attribute = gemdos.const.Fattrib.volume
local <const> k_esc = gemdos.utility.esc
local <const> k_EFILNF = gemdos.const.Error.EFILNF

local <const> DirCopy = {}

-- default_fn. Called by the copy function if the supplied fn was nil
-- Inputs:
--   1) string: Operation being performed
--   2) string: The source path (either a directory or a file)
--   3) string: The destination path (either a directory or a file)
-- NOTE: operations are:
--    "dfound": The destination directory was found
--   "dcreate": The destination directory will be created
--      "copy": The destination file will be copied
--      "data": Some data was copied to the destination file
-- Returns:
--   1) integer: 0 to continue copying, non-zero to terminate the copy
local function default_fn(operation, src_path, dst_path,
    file_size, bytes_read, bytes_written)
  gemdos.Cconws(operation .. " " .. src_path .. " -> " .. dst_path .. " sz " ..
    file_size .. " br " .. bytes_read .. " bw " .. bytes_written .. "\r\n")
  k_esc()
  return 0
end

-- dir_copy. Copies a source directory to a destination directory.
-- If fn parameter is not nil, the function is called before each destination
-- directory is created or file is copied.
-- Inputs:
--   1) string: src path
--   2) string: dst path
--   3) string: wildcard e.g. "*.TXT"
--   4) boolean: true to enable recursion
--   5) boolean: true to preserve timestamp
--   6) function: function to call before each file is copied
--   7) optional userdata: premud: Data transfer buffer
--   NOTE: See default_fn for an example function for fn parameter.
-- Returns
--   1) integer: 0 on success, non-zero on failure
function DirCopy.dir_copy(src_path, dst_path, wildcard, recursive, 
    preserve_ts, fn, premud)
  src_path = src_path or "."
  dst_path = dst_path or "."
  wildcard = wildcard or "*.*"
  recursive = recursive or false
  if preserve_ts == nil then
    preserve_ts = true
  end
  fn = fn or default_fn

  assert(type(src_path) == "string")
  assert(type(dst_path) == "string")
  assert(type(wildcard) == "string")
  assert(type(recursive) == "boolean")
  assert(type(preserve_ts) == "boolean")
  assert(type(fn) == "function")
  assert(premud == nil or type(premud) == "userdata")

  -- Replace empty path with current directory
  if src_path == "" then
    src_path = "."
  end
  if dst_path == "" then
    dst_path = "."
  end

  -- Normalize the source and destination path
  local ec
  ec, src_path = k_normalize_path(src_path)
  if ec ~= 0 then
    return ec
  end
  ec, dst_path = k_normalize_path(dst_path)
  if ec ~= 0 then
    return ec
  end

  -- Source path and destination path must be different
  if src_path == dst_path then
    return -1
  end

  -- Check the destination path is a directory
  local <const> dst_ec, dst_dta = k_Fsfirst(dst_path, k_dir_attribute)
  if dst_ec == k_EFILNF then
    -- NOTE(mlpce): searching for root directory gives EFILNF
  elseif dst_ec < 0 then
    return dst_ec
  else
    assert(dst_dta:attr() & k_dir_attribute ~= 0)
  end

  local function proc_dir(path, descending, dirs, files)
    if not descending then
      return 0
    end

    local src_rel_path = string.sub(path, #src_path + 1)
    local dst_rel_path = k_join_path(dst_path, src_rel_path)
    local ec = 0
    for _, dta in ipairs(dirs) do
      local <const> src_sub_path = k_join_path(path, dta:name())
      local <const> dst_sub_path = k_join_path(dst_rel_path, dta:name())

      -- Make the destination directory if it doesn't exists
      ec = k_Fsfirst(dst_sub_path, k_dir_attribute)
      if ec == 0 then
        ec = fn("dfound", src_sub_path, dst_sub_path, 0, 0, 0)
        assert(type(ec) == "number")
        if ec ~= 0 then
          break
        end
      elseif ec == k_EFILNF then
        ec = fn("dcreate", src_sub_path, dst_sub_path, 0, 0, 0)
        assert(type(ec) == "number")
        if ec ~= 0 then
          break
        end
        ec = k_Dcreate(dst_sub_path)
        if ec < 0 then
          -- Failed to create directory
          break
        end
      end
    end

    if ec ~= 0 then
      -- Error while creating destination directories
      return ec
    end

    -- Copy the files to the destination directory
    for _,dta in ipairs(files) do
      local entry_attr <const> = dta:attr()
      -- volume labels are not copied
      if entry_attr & k_volume_attribute == 0 then
        local <const> src_path_name =
          k_join_path(path, dta:name())
        local <const> dst_path_name =
          k_join_path(dst_rel_path, dta:name())
        ec = fn("copy", src_path_name, dst_path_name, dta:length(), 0, 0)
        assert(type(ec) == "number")
        if ec ~= 0 then
          break
        end
        ec = k_file_copy(src_path_name, dst_path_name, preserve_ts,
          function(file_size, bytes_read, bytes_written)
            return fn("data", src_path_name, dst_path_name,
              file_size, bytes_read, bytes_written)
            end, premud)
        if ec < 0 then
          break
        end
      end
    end

    return ec
  end

  return k_DirScan.dir_scan(src_path, wildcard, recursive, proc_dir)
end

return DirCopy
