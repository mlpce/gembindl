local <const> Path = require("gembindl.utility.disk.path")

local <const> k_EPTHNF = gemdos.const.Error.EPTHNF
local <const> k_EDRIVE = gemdos.const.Error.EDRIVE

warn("@off")

local ec, path
ec, path = Path.normalize_path("A:\\")
assert(ec == 0 and path == "A:\\")

warn("@on")

-- Valid path characters
local val_path_chars <const> =
  "A:\\abcdef\\\z" ..
  "ghijkl\\\z" ..
  "mnopqr\\\z" ..
  "stuvwx\\\z" ..
  "yz\\\z" ..
  "ABCDEF\\\z" ..
  "GHIJKL\\\z" ..
  "MNOPQR\\\z" ..
  "STUVWX\\\z" ..
  "YZ\\\z" ..
  "01234567\\89\\\z" ..
  "!@#$%^&(\\\z" ..
  ")+-=~`;'\\\z" ..
  ",<>|[]()\\_"

-- Normalize a path containing all valid characters
ec, path = Path.normalize_path(val_path_chars)

assert(ec == 0)
assert(path == val_path_chars)

-- Check \.\ is removed
ec, path = Path.normalize_path("A:\\one\\two\\.\\.\\.\\three\\four\\.\\.\\.")
assert(ec == 0)
assert(path == "A:\\one\\two\\three\\four")

-- Elision of ..
ec, path = Path.normalize_path(
  "A:\\one\\two\\three\\four\\..\\five\\six\\seven\\..\\..")
assert(ec == 0)
assert(path == "A:\\one\\two\\three\\five")

-- More elision of ..
ec, path = Path.normalize_path(
  "A:\\one\\two\\three\\four\\..\\five\\six\\seven\\..\\..\\..\\..")
assert(ec == 0)
assert(path == "A:\\one\\two")

-- A combination of \.\ \..\ and \.
ec, path = Path.normalize_path("A:\\one\\.\\two\\..\\.\\..\\.\\three\\.")
assert(ec == 0)
assert(path == "A:\\three")

-- Trailing backslash is removed
ec, path = Path.normalize_path("A:\\one\\")
assert(ec == 0)
assert(path == "A:\\one")

-- Elision of .. above top must fail
ec, path = Path.normalize_path("A:\\..")
assert(ec == k_EPTHNF)

-- Invalid drive letter must fail
ec, path = Path.normalize_path("@:\\")
assert(ec == k_EDRIVE)

-- Invalid character must fail
ec, path = Path.normalize_path("A:\\one\\two\\thr:ee")
assert(ec == k_EPTHNF)

-- Test validate_path
assert(Path.validate_path("A:\\"))
assert(Path.validate_path("£:\\") == false)
assert(Path.validate_path("123456789.XXX") == false)
assert(Path.validate_path("12345678.XXXX") == false)
assert(Path.validate_path("123..456") == false)
assert(Path.validate_path("..\\:") == false)

-- Test join_path
assert(Path.join_path("one", "two") == "one\\two")
assert(Path.join_path("one\\", "two") == "one\\two")
assert(Path.join_path("one", "\\two") == "one\\two")
assert(Path.join_path("one\\", "\\two") == "one\\two")
-- join_path only checks last/first backslashes so it doesn't
-- help with duplicates on either side.
assert(Path.join_path("one\\\\", "\\\\two") == "one\\\\\\two")

-- Test is_abs_path
assert(Path.is_abs_path("\\one") == true)
assert(Path.is_abs_path("one") == false)
assert(Path.is_abs_path("A:\\one") == true)
assert(Path.is_abs_path("A:one") == false)

-- Test fname_from_path
assert(Path.fname_from_path("\\one\\two\\three\\12345678.123") ==
  "12345678.123")
assert(Path.fname_from_path("12345678.123") == "12345678.123")

-- Test dir_from_path
assert(Path.dir_from_path("\\one\\two\\three\\12345678.123") ==
  "\\one\\two\\three\\")
assert(Path.dir_from_path("\\one\\two\\three\\") ==
  "\\one\\two\\three\\")

--  Test fname_split
local a, b = Path.fname_split("\\one\\two\\three\\12345678.123")
assert(a == "12345678")
assert(b == "123")

-- Test get_path
ec, path = Path.get_path()
assert(ec == 0)
assert(Path.is_abs_path(path))

-- Test set path
local new_path = string.sub(path, 1, 3)
ec = Path.set_path(new_path)
assert(ec == 0)

-- Check new path
local path2
ec, path2 = Path.get_path()
assert(ec == 0)
assert(path2 == new_path)

-- Test set_path with original path
ec = Path.set_path(path)
assert(ec == 0)

-- Check path is now original path
ec, path2 = Path.get_path()
assert(ec == 0)
assert(path2 == path)
