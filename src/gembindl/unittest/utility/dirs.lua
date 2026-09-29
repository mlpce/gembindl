local <const> Path = require("gembindl.utility.disk.path")
local <const> DirCopy = require("gembindl.utility.disk.dircopy")
local <const> DirScan = require("gembindl.utility.disk.dirscan")
local <const> PathFind = require("gembindl.utility.disk.pathfind")

-- Copy files from utility\testdir to utility\testdst
local ec =
  DirCopy.dir_copy("utility\\testdir", "utility\\testdst", "*.*", true, true)
assert(ec == 0)

local scanned = {}

local function fn(path, descending, dirs, files)
  if descending then
    for k,v in ipairs(files) do
      scanned[#scanned + 1] = Path.join_path(path, v:name())
    end
  end
  return 0
end

-- What got copied?
ec = DirScan.dir_scan("utility\\testdst", "*.*", true, fn)

-- Check the expected copied files
local nchecked = 0
for k,v in ipairs(scanned) do
  local fname = Path.fname_from_path(v)
  if fname == "ONE.TXT" then
    local ec, fud <close> = gemdos.Fopen(v, gemdos.const.Fopen.readonly)
    ec, s = fud:reads(80)
    assert(s == "one\r\n")
    nchecked = nchecked + 1
  elseif fname == "TWO.ASC" then
    local ec, fud <close> = gemdos.Fopen(v, gemdos.const.Fopen.readonly)
    ec, s = fud:reads(80)
    assert(s == "two\r\n")
    nchecked = nchecked + 1
  elseif fname == "THREE.TXT" then
    local ec, fud <close> = gemdos.Fopen(v, gemdos.const.Fopen.readonly)
    ec, s = fud:reads(80)
    assert(s == "three\r\n")
    nchecked = nchecked + 1
  elseif fname == "FOUR.TXT" then
    local ec, fud <close> = gemdos.Fopen(v, gemdos.const.Fopen.readonly)
    ec, s = fud:reads(80)
    assert(s == "four\r\n")
    nchecked = nchecked + 1
  end
end

assert(nchecked == 4)

-- Find the .ASC file
local found = PathFind.find_file("TWO.ASC", "utility\\testdst")
assert(found)
gemdos.Cconws("found: " .. found .. "\r\n")
found = PathFind.find_file("TWO", "utility\\testdst", { "ASC" } )
assert(found)
gemdos.Cconws("found: " .. found .. "\r\n")
found = PathFind.find_file("utility\\testdst\\two", nil, { "ASC" } )
assert(found)
gemdos.Cconws("found: " .. found .. "\r\n")

-- Delete what was copied
for k,v in ipairs(scanned) do
  ec = gemdos.Fdelete(v)
  assert(ec == 0)
  gemdos.Cconws("Deleted: " .. v .. "\r\n")
end
