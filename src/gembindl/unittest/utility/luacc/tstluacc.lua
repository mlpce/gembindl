global assert, ipairs, require, string, gemdos

local <const> k_Luacc = require("gembindl.utility.luacc")
local <const> k_Path = require("gembindl.utility.disk.path")
local <const> k_DirScan = require("gembindl.utility.disk.dirscan")
local <const> k_PathFind = require("gembindl.utility.disk.pathfind")
local <const> k_Pexec0 = gemdos.Pexec0
local <const> k_dir_attribute = gemdos.const.Fattrib.dir
local <const> k_Fsfirst = gemdos.Fsfirst
local <const> k_EFILNF = gemdos.const.Error.EFILNF
local <const> k_Fopen = gemdos.Fopen
local <const> k_readonly = gemdos.const.Fopen.readonly

-- Check the test is being run from the correct directory by checking for
-- the existence of testfind.lua. This test refers to items in the 'files'
-- subdirectory.
local <const> check_ec, check_fud <close> = gemdos.Fopen("tstluacc.lua",
  gemdos.const.Fopen.readonly)
assert(check_ec == 0)
check_fud:close()

-- Get the current directory as an absolute path
local <const> path_ec, cwd = k_Path.get_path()
assert(path_ec == 0)

-- Determine source and destination paths

-- Good source path
local <const> goodsrc_path = k_Path.join_path(cwd, "testsrc\\goodsrc")
-- Good destination path
local <const> gooddst_path = k_Path.join_path(cwd, "testdst\\gooddst")

-- Bad source path
local <const> badsrc_path = k_Path.join_path(cwd, "testsrc\\badsrc")
-- Bad destination path
local <const> baddst_path = k_Path.join_path(cwd, "testdst\\baddst")

-- Function to delete the destination directories
local function cleanup()
  -- dir_scan function to delete all items in a directory when ascending
  -- the directory tree.
  local function ascending_del(path, descending, dirs, files)
    if not descending then
      local del_ec
      -- Delete all the files in the directory
      for k,v in ipairs(files) do
        del_ec = gemdos.Fdelete(k_Path.join_path(path, v:name()))
        assert(del_ec == 0)
      end
      -- Delete all the directories in the directory
      for k,v in ipairs(dirs) do
        del_ec = gemdos.Ddelete(k_Path.join_path(path, v:name()))
        assert(del_ec == 0)
      end
    end
    return 0
  end

  -- Delete everything in the destination directories
  k_DirScan.dir_scan(gooddst_path, "*.*", true, ascending_del)
  gemdos.Ddelete(gooddst_path)
  k_DirScan.dir_scan(baddst_path, "*.*", true, ascending_del)
  gemdos.Ddelete(baddst_path)
end

-- Function to create the destination directories
local function prepare()
  -- Create the good destination path
  local ec = gemdos.Dcreate(gooddst_path)
  assert(ec == 0)

  -- Create the bad destination path
  ec = gemdos.Dcreate(baddst_path)
  assert(ec == 0)
end

-- delete and re-create destination directories
cleanup()
prepare()

-- Compile goodsrc_path to gooddst_path without recursion or stripping
local ec = k_Luacc.compile(goodsrc_path, gooddst_path, false, false)
assert(ec == 0)

-- Without recursion, the sub directory must not have been created in
-- the destination directory
ec = k_Fsfirst(k_Path.join_path(gooddst_path, "subdir"), k_dir_attribute)
assert(ec == k_EFILNF)

-- delete and re-create destination directories
cleanup()
prepare()

-- Compile goodsrc_path to gooddst_path with resursion and no stripping
ec = k_Luacc.compile(goodsrc_path, gooddst_path, true, false)

-- With recursion, the sub directory must have been created in the
-- destination directory
ec = k_Fsfirst(k_Path.join_path(gooddst_path, "subdir"), k_dir_attribute)
assert(ec == 0)

-- Find the compiler path. Search for LUAC.TTP in the current working
-- directory and in the directories specified by the GEMDOS environment
-- PATH value.
local <const> luac_path =
  k_PathFind.search_path("LUAC.TTP", k_PathFind.cwd_env_path())
assert(luac_path)

-- Check the compiled files can be loaded
local check = { "file1.lua", "file2.lua", "subdir\\file3.lua" }
for k,v in ipairs(check) do
  ec = k_Pexec0(luac_path, {"-p", k_Path.join_path(gooddst_path, v)})
  assert(ec == 0)
  gemdos.Cconws("load ok: " .. v .. "\r\n")
end

-- Additionally FILE1.LUA must contain the string test_name because the
-- bytecode was not stripped.
local function check_test_name(full_path)
  gemdos.Cconws("Checking for test_name: " .. full_path .. "\r\n")
  local ec, fud <close> = k_Fopen(full_path, k_readonly)
  assert(ec == 0)
  local data
  ec, data = fud:reads(1024)
  assert(ec > 0)
  fud:close()
  return string.find(data, "test_name")
end
assert(check_test_name(k_Path.join_path(gooddst_path, "file1.lua")))
gemdos.Cconws("test_name exists\r\n")

-- delete and re-create destination directories
cleanup()
prepare()

-- Now using the badsrc path. badsrc/subdir/filebad.lua contains an undeclared
-- variable and will fail to compile.
-- Compile badsrc_path to baddst_path with recursion and stripping enabled
gemdos.Cconws("The following compilation must fail for filebad.lua:\r\n")
local ec = k_Luacc.compile(badsrc_path, baddst_path, true, true)
-- Compile must return a failure code because of filebad.lua
assert(ec ~= 0)

-- The files at file1.lua and file2.lua will have compiled
local check = { "file1.lua", "file2.lua" }
for k,v in ipairs(check) do
  ec = k_Pexec0(luac_path, {"-p", k_Path.join_path(baddst_path, v)})
  assert(ec == 0)
  gemdos.Cconws("load ok: " .. v .. "\r\n")
end

-- The destination filebad.lua must not have been generated
ec = k_Pexec0(luac_path,
  {"-p", k_Path.join_path(baddst_path, "subdir\\filebad.lua")})
assert(ec ~= 0)
gemdos.Cconws("load not ok (expected): subdir\\filebad.lua\r\n")

-- Additionally FILE1.LUA must not contain the string test_name because the
-- bytecode was stripped.
assert(not check_test_name(k_Path.join_path(baddst_path, "file1.lua")))
gemdos.Cconws("test_name did not exist (expected)\r\n")

-- delete the destination directories
cleanup()
