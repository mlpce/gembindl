global assert, ipairs, require, string, type, gemdos

local <const> k_RCache = require("gembindl.utility.rcache")
local <const> k_Path = k_RCache.require("gembindl.utility.disk.path")
local <const> k_PathFind = k_RCache.require("gembindl.utility.disk.pathfind")
local <const> k_DirScan = k_RCache.require("gembindl.utility.disk.DirScan")

local <const> k_Fsfirst = gemdos.Fsfirst
local <const> k_Dcreate = gemdos.Dcreate
local <const> k_Cconws = gemdos.Cconws
local <const> k_Pexec0 = gemdos.Pexec0
local <const> k_dir_attribute = gemdos.const.Fattrib.dir
local <const> k_esc = gemdos.utility.esc
local <const> k_EFILNF = gemdos.const.Error.EFILNF

local <const> Luacc = {}

-- default_fn. Called by the compile function if the supplied fn was nil
-- Inputs:
--   1) string: Operation about to be performed, either "dcreate" or "compile"
--   2) string: The source path (either a directory or a Lua file)
--   3) string: The destination path (either a directory or a Lua file)
-- Returns:
--   1) integer: 0 to continue compiling, non-zero to terminate the compile
local function default_fn(operation, src_path, dst_path)
  k_Cconws(operation .. " " .. src_path .. " -> " .. dst_path .. "\r\n")
  k_esc()
  return 0
end

-- compile. Compiles Lua source code in the source directory tree, storing
-- bytecode in the directory directory tree, optionally recursive. If fn
-- parameter is not nil, the function is called before each destination
-- directory is created or source file is compiled.
-- Inputs:
--   1) string: src path
--   2) string: dst path
--   3) boolean: true to enable recursion
--   4) boolean: true to enable stripping
--   5) function: function to call before each file is compiled
--   NOTE: See default_fn for an example function for fn parameter.
-- Returns
--   1) integer: 0 on success, non-zero on failure
function Luacc.compile(src_path, dst_path, recursive, strip, fn)
  src_path = src_path or "."
  dst_path = dst_path or "."
  recursive = recursive or false
  if strip == nil then strip = true end
  fn = fn or default_fn

  local <const> params = strip and { "-s", "-o", false, false } or
    { "-o", false, false }

  -- Replace empty path with current directory
  if src_path == "" then
    src_path = "."
  end
  if dst_path == "" then
    dst_path = "."
  end

  assert(type(src_path) == "string")
  assert(type(dst_path) == "string")
  assert(type(recursive) == "boolean")
  assert(type(strip) == "boolean")
  assert(type(fn) == "function")

  -- Normalize the source path
  local ec
  ec, src_path = k_Path.normalize_path(src_path)
  if ec ~= 0 then
    return ec
  end

  -- Normalize the destination path
  ec, dst_path = k_Path.normalize_path(dst_path)
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

  -- Find the compiler path
  local luac_path = k_PathFind.find_program("LUAC.TTP")
  if luac_path == nil then
    return -1
  end

  local function proc_dir(path, descending, dirs, files)
    if not descending then
      return 0
    end

    local src_rel_path = string.sub(path, #src_path + 1)
    local dst_rel_path = k_Path.join_path(dst_path, src_rel_path)
    local ec = 0

    -- Create destination directories if they do not exist
    for _, dta in ipairs(dirs) do
      local <const> src_sub_path = k_Path.join_path(path, dta:name())
      local <const> dst_sub_path = k_Path.join_path(dst_rel_path, dta:name())

      -- Make the destination directory if it doesn't exists
      ec = k_Fsfirst(dst_sub_path, k_dir_attribute)
      if ec == k_EFILNF then
        ec = fn("dcreate", src_sub_path, dst_sub_path)
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

    -- Compile the Lua code to the destination directory
    for _,dta in ipairs(files) do
      local <const> src_path_name =
        k_Path.join_path(path, dta:name())
      local <const> dst_path_name =
        k_Path.join_path(dst_rel_path, dta:name())
      ec = fn("compile", src_path_name, dst_path_name)
      assert(type(ec) == "number")
      if ec ~= 0 then
        break
      end

      -- Update the parameters with dst path and src path
      params[#params - 1] = dst_path_name
      params[#params] = src_path_name

      ec = k_Pexec0(luac_path, params)
      if ec ~= 0 then
        break
      end
    end

    return ec
  end

  return k_DirScan.dir_scan(src_path, "*.LUA", recursive, proc_dir)
end

return Luacc
