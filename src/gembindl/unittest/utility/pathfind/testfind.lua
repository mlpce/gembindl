global assert, require, gemdos

local <const> k_Path = require("gembindl.utility.disk.path")
local <const> k_PathFind = require("gembindl.utility.disk.pathfind")

gemdos.Cconws("Testing pathfind\r\n")

-- Check the test is being run from the correct directory by checking for
-- the existence of testfind.lua. This test refers to items in the 'files'
-- subdirectory.
local <const> check_ec, check_fud <close> = gemdos.Fopen("testfind.lua",
  gemdos.const.Fopen.readonly)
assert(check_ec == 0)
check_fud:close()

-- Get absolute path to files directory holding the test files
local <const> path_ec, cwd = k_Path.get_path()
assert(path_ec == 0)
local <const> abs_files_path = k_Path.join_path(cwd, "files")

-- search for "find.txt" in the "files" subdirectory. This will be matched
-- directly
local location = k_PathFind.search_path("find.txt", ".\\files")
assert(location == k_Path.join_path(abs_files_path, "find.txt"))

-- search for "find.it" in the "files" subdirectory. This will be matched
-- as "find.txt" using the alternate extension "txt".
location = k_PathFind.search_path("find.it", ".\\files", {"txt"})
assert(location == k_Path.join_path(abs_files_path, "find.txt"))

-- search for "find.it" in the "files" subdirectory. This will be matched
-- as "find.asc" using the alternate extension "asc".
location = k_PathFind.search_path("find.it", ".\\files", {"dat", "asc"})
assert(location == k_Path.join_path(abs_files_path, "find.asc"))

-- search for "sub1\\sub2\\find.me" in the "files" subdirectory. This
-- will be matched directly.
location = k_PathFind.search_path("sub1\\sub2\\find.me", ".\\files")
assert(location == k_Path.join_path(abs_files_path, "sub1\\sub2\\find.me"))

-- search for "sub2\\find.me" in the "files\\sub1" subdirectory. This
-- will be matched directly.
location = k_PathFind.search_path("sub2\\find.me", ".\\files\\sub1")
assert(location == k_Path.join_path(abs_files_path, "sub1\\sub2\\find.me"))

-- search for "sub2\\find.it" in "files\\sub1" subdirectory. This will be
-- matched using the alternate extension "dat".
location = k_PathFind.search_path("sub2\\find.it",
  ".\\files\\sub1", {"inf","dat"})
assert(location == k_Path.join_path(abs_files_path, "sub1\\sub2\\find.dat"))

-- search for "find.me" in various subdirectories. This will be matched
-- directly.
location = k_PathFind.search_path("find.me",
  ".;.\\files\\sub1;.\\files\\sub1\\sub2")
assert(location == k_Path.join_path(abs_files_path, "sub1\\sub2\\find.me"))

-- search for "find.who" in various subdirectories. This will be matched
-- using the alternate extension "me".
location = k_PathFind.search_path("find.who",
  ".;.\\files\\sub1;.\\files\\sub1\\sub2", {"me"})
assert(location == k_Path.join_path(abs_files_path, "sub1\\sub2\\find.me"))

-- search for "find.txt" in the absolute directory of "files". This will
-- be matched directly.
location = k_PathFind.search_path("find.txt", abs_files_path)
assert(location == k_Path.join_path(abs_files_path, "find.txt"))

-- search for "find.me" in the absolute directory of "files". This will
-- be matched using the alternate extension "asc"
location = k_PathFind.search_path("find.me", abs_files_path, {"asc"})
assert(location == k_Path.join_path(abs_files_path, "find.asc"))

-- search for "find.who" in the absolute directory of "files". This will
-- not be matched.
location = k_PathFind.search_path("find.who", abs_files_path)
assert(location == nil)

-- search for "find.txt" in a directory that uses "." and ".." which will
-- be normalised away during the search. "find.txt" will be matched directly.
location = k_PathFind.search_path("find.txt",
  k_Path.join_path(abs_files_path, "not\\down\\here\\.\\..\\..\\.."))
assert(location == k_Path.join_path(abs_files_path, "find.txt"))

-- search for "find.txt" in a directory that uses "." and ".." and a trailing
-- backslash which will be normalised away during the search. "find.txt" will
-- be matched directly.
location = k_PathFind.search_path("find.txt",
  k_Path.join_path(abs_files_path, "not\\down\\here\\..\\.\\..\\..\\"))
assert(location == k_Path.join_path(abs_files_path, "find.txt"))

-- search for "find.who" in a directory that uses "." and ".." and a trailing
-- backslash which will be normalised away during the search. "find.asc" will
-- be matched using the alternate extension "asc".
location = k_PathFind.search_path("find.who",
  k_Path.join_path(abs_files_path,
    "not\\down\\here\\..\\..\\.\\..\\"), {"asc"})
assert(location == k_Path.join_path(abs_files_path, "find.asc"))

-- Again search for "find.who", but this time "find.who" is prepended by
-- various redundant directories and ".." which are eliminated during the
-- search. Additionally, the search path also contains a redundant directory
-- and ".." which will be eliminated during the search.
-- "find.who" will be matched against "find.txt" in the "files" subdirectory
-- using the alternate extension "txt".
location = k_PathFind.search_path(
  ".\\not\\down\\here\\..\\..\\..\\find.who", ".\\down\\..\\files",
  {"not","txt"})
assert(location == k_Path.join_path(abs_files_path, "find.txt"))

-- Similar but search for "find" without the ".who" extension.
-- "find" will be matched against "find.txt" in the "files" subdirectory
-- using the alternate extension "txt".
location = k_PathFind.search_path(
  ".\\not\\down\\here\\..\\..\\..\\find", ".\\down\\..\\files",
  {"not","txt"})
assert(location == k_Path.join_path(abs_files_path, "find.txt"))

-- This one can't be found, "findo" is not there.
location = k_PathFind.search_path(
  ".\\not\\down\\here\\..\\..\\..\\findo",
  ".\\down\\..\\files", {"not","txt"})
assert(location == nil)

-- This one can't be found either, extensions "not" and "one" can't be
-- matched.
location = k_PathFind.search_path(
  ".\\not\\down\\here\\..\\..\\..\\find", ".\\down\\..\\files",
  {"not","one"})
assert(location == nil)

-- cwd_env_path() returns '.;' concatentated with PATH environment variable
-- value
local <const> path = k_PathFind.cwd_env_path()
local <const> path_value = gemdos.utility.getenv("PATH")
if path_value then
  assert(path == '.;' .. path_value)
else
  assert(path == '.;')
end

gemdos.Cconws("Tested pathfind\r\n")
