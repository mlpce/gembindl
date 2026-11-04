global assert, require, table, ipairs, tosbindl, type, gemdos

local <const> k_Path = require("gembindl.utility.disk.path")
local <const> k_DirCopy = require("gembindl.utility.disk.dircopy")
local <const> k_DirScan = require("gembindl.utility.disk.dirscan")
local <const> k_u16 = gemdos.const.Imode.u16

-- Check the test is being run from the correct directory by checking for
-- the existence of textcopy.lua. This test refers to items in the 'testdir'
-- subdirectory.
local <const> check_ec, check_fud <close> = gemdos.Fopen("testcopy.lua",
  gemdos.const.Fopen.readonly)
assert(check_ec == 0)
check_fud:close()

-- Get the current directory as an absolute path
local <const> path_ec, cwd = k_Path.get_path()
assert(path_ec == 0)

-- Source path
local <const> src_path = k_Path.join_path(cwd, "testdir\\src")
-- Destination path
local <const> dst_path = k_Path.join_path(cwd, "testdir\\dst")

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

-- Function to delete the destination directory
local function cleanup()
  -- Delete everything in the source directory
  k_DirScan.dir_scan(src_path, "*.*", true, ascending_del)
  gemdos.Ddelete(src_path)
  -- Delete everything in the destination directory
  k_DirScan.dir_scan(dst_path, "*.*", true, ascending_del)
  gemdos.Ddelete(dst_path)
end

-- Function to create the destination directory
local function prepare()
  -- Create the source path
  local ec = gemdos.Dcreate(src_path)
  assert(ec == 0)
  ec = gemdos.Dcreate(k_Path.join_path(src_path, "subdir"))
  assert(ec == 0)
  -- Create the destination path
  ec = gemdos.Dcreate(dst_path)
  assert(ec == 0)
end

cleanup()
prepare()

-- Create the test source files
gemdos.Cconws("Building table\r\n")
local big_table = table.create(32769)
for i = 1, 32769 do
  big_table[i] = i
end

-- Test sources
local <const> sources = {
  { "one.txt", "12345678", false },
  { "two.txt", "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\nabcdefghijklmnopqrstuvwxyz", false},
  { "empty.txt", "", false },
  { "subdir\\big.bin", big_table, false}
}

gemdos.Cconws("Writing source files\r\n")
-- Write out the test sources
for k,v in ipairs(sources) do
  local <const> filename, data = v[1], v[2]
  local <const> file_path = k_Path.join_path(src_path, filename)
  local ec, fud <close> = gemdos.Fcreate(file_path, 0)
  assert(ec == 0)
  if #data > 0 then
    if type(data) == "string" then
      ec = fud:writes(data)
    elseif type(data) == "table" then
      ec = fud:writet(k_u16, data)
    else
      assert(false)
    end
  end
  -- datime of the file. Used to check if timestamps are preserved.
  v[3] = table.pack(fud:datime())
  assert(ec >= 0)
end

gemdos.Cconws("Waiting for time to change...\r\n")
-- Busy wait for time to change
local <const> h, m, s = gemdos.Tgettime()
repeat
  local <const> new_h, new_m, new_s = gemdos.Tgettime()
until new_s ~= s 

-- Copy files from testdir to testdst, recursive and preserving
-- timestamps
gemdos.Cconws("Copying files (recursive, preservets)\r\n")
local ec = k_DirCopy.dir_copy(src_path, dst_path, "*.*", true, true)
assert(ec == 0)

-- Check copied files
gemdos.Cconws("Checking copied files\r\n")
for k,v in ipairs(sources) do
  local <const> filename, data, datime = v[1], v[2], v[3]
  local <const> file_path = k_Path.join_path(dst_path, filename)
  local ec, fud <close> = gemdos.Fopen(file_path, gemdos.const.Fopen.readonly)
  assert(ec == 0)

  -- Check timestamps are preserved
  local <const> file_datime = table.pack(fud:datime())
  for k,v in ipairs(datime) do
    assert(file_datime[k] == v)
  end
  gemdos.Cconws("Tstamp ok: " .. file_path .. "\r\n")

  -- Check contents are the same
  if type(data) == "string" then
    -- Read #data + 1 to make sure file size is correct.
    -- Actual number of bytes read should be #data.
    local <const> read_ec, read_str = fud:reads(#data + 1)
    assert(read_ec == #data)
    assert(read_str == data)
    gemdos.Cconws("Data string matched\r\n")
  elseif type(data) == "table" then
    -- Read #data + 1 to make sure file size is correct.
    -- Actual number of values read should be #data.
    local in_t = table.create(#data)
    local <const> read_ec, read_t =
      fud:readt(k_u16, #data + 1, in_t)
    assert(read_t == in_t)
    assert(read_ec == #data << 1)
    assert(#read_t == #data)
    local data_matched = true
    for i = 1, #data do
      if read_t[i] ~= data[i] then
        data_matched = false
        break
      end
    end
    assert(data_matched)
    gemdos.Cconws("Data table matched\r\n")
  end
end

-- Delete everything in the destination directory
k_DirScan.dir_scan(dst_path, "*.*", true, ascending_del)

-- Copy again, without recursion and without preserving timestamp
-- timestamps
gemdos.Cconws("Copying files (non-rec, no-preservets)\r\n")
ec = k_DirCopy.dir_copy(src_path, dst_path, "*.*", false, false)
assert(ec == 0)

-- File in subdirectory must not have been copied
-- Therefore searching for the directory must produce EFILNF.
ec = gemdos.Fsfirst(
  k_Path.join_path(dst_path, "subdir"), gemdos.const.Fattrib.dir)
assert(ec == gemdos.const.Error.EFILNF)

-- Check timestamps are different
gemdos.Cconws("Checking timestamps are different\r\n")
for k,v in ipairs(sources) do
  local <const> filename, data, datime = v[1], v[2], v[3]
  if filename ~= "subdir\\big.bin" then  -- subdir was not copied
    local <const> file_path = k_Path.join_path(dst_path, filename)
    local ec, fud <close> =
      gemdos.Fopen(file_path, gemdos.const.Fopen.readonly)
    local <const> file_datime = table.pack(fud:datime())
    local different = false
    for k,v in ipairs(datime) do
      if file_datime[k] ~= v then
        different = true
        break
      end
    end
    assert(different)
    gemdos.Cconws("Tstamp diff: " .. file_path .. "\r\n")
  end
end

-- Delete everything in the destination directory
k_DirScan.dir_scan(dst_path, "*.*", true, ascending_del)

-- Copy again, using wildcard *.BIN, with recursion and preserving timestamp
gemdos.Cconws("Copying files (*.BIN, recursive, preservets)\r\n")
ec = k_DirCopy.dir_copy(src_path, dst_path, "*.BIN", true, true)
assert(ec == 0)

-- Only BIG.BIN must have been copied so check there is only one file
local nfiles = 0
ec = k_DirScan.dir_scan(dst_path, "*.*", true,
  function (path, descending, dirs, files)
    if descending then nfiles = nfiles + #files end
    return 0
  end)

gemdos.Cconws("Copied " .. nfiles .. " files\r\n")
assert(nfiles == 1)

-- Check the copied file was BIG.BIN
assert(gemdos.Fattrib(k_Path.join_path(dst_path, "subdir\\big.bin"), 0) == 0)

cleanup()
