global assert, pairs, type, gemdos

local <const> k_a_readonly = gemdos.const.Fattrib.readonly
local <const> k_a_volume = gemdos.const.Fattrib.volume
local <const> k_a_dir = gemdos.const.Fattrib.dir
local <const> k_o_readonly = gemdos.const.Fopen.readonly
local <const> k_EFILNF = gemdos.const.Error.EFILNF
local <const> k_Fattrib = gemdos.Fattrib
local <const> k_Fopen = gemdos.Fopen
local <const> k_Fcreate = gemdos.Fcreate
local <const> k_Fdelete = gemdos.Fdelete
local <const> k_Fsfirst = gemdos.Fsfirst
local <const> k_Fdatime = gemdos.Fdatime
local <const> k_allocm = gemdos.utility.allocm
local <const> k_max_alloc_size = 4096

local <const> FileCopy = {}

-- Mask of all valid attributes
local all_attr = 0
for k,v in pairs(gemdos.const.Fattrib) do
  all_attr = all_attr | v
end

-- Check attributes are allowed
local function check_attr(path, allowed_attr_mask)
  local ec_attr = k_Fattrib(path, 0, 0)
  if ec_attr > 0 and ec_attr & allowed_attr_mask ~= ec_attr then
    ec_attr = -1
  end
  return ec_attr
end

-- default_fn. Called by the copy function if the supplied fn was nil
-- Inputs:
--   1) integer: file_size: The size of the file being copied
--   2) integer: bytes_read: The total bytes read so far
--   3) integer: bytes_written: The total bytes written so far
-- Returns:
--   1) integer: 0 to continue copying, non-zero to terminate the copy
local function default_fn(file_size, bytes_read, bytes_written)
  gemdos.Cconws("file_size " .. file_size .. " bytes_read " .. bytes_read ..
    " bytes_written " .. bytes_written .. "\r\n")
  return 0
end

-- file_copy. Copy a single file from a source path to a destination path,
-- optionally preserving the timestamp. It will not copy wildcards,
-- directories or volume names. If the destination file already exists,
-- it will be replaced unless the existing file has its readonly attribute
-- set, in which case the copy will fail.
-- Inputs:
--   1) string: src_path: The path of the source file
--   2) string: dst_path: The path of the distination file
--   3) boolean: preserve_ts: When true the file timestamp will be preserved
--   4) function: fn: Function to call as each datum is copied
--   5) optional userdata: premud: Data transfer buffer
-- Returns:
--   1) integer: 0 on success, non-zero on failure
--   2) optional string: on failure, further failure info
function FileCopy.file_copy(src_file, dst_file, preserve_ts, fn, premud)
  -- Set default for nil parameters
  if preserve_ts == nil then
    preserve_ts = true
  end
  fn = fn or default_fn

  assert(type(src_file) == "string")
  assert(type(dst_file) == "string")
  assert(type(preserve_ts) == "boolean")
  assert(type(fn) == "function")
  assert(premud == nil or type(premud) == "userdata")

  -- Do not allow copying from volume or directory items
  local ec_src_attr <const> =
    check_attr(src_file, all_attr ~ (k_a_volume | k_a_dir))
  if ec_src_attr < 0 then
    return ec_src_attr, "src_attr"
  end

  -- Do not allow copying to volume, directory or readonly items
  local ec_dst_attr <const> =
    check_attr(dst_file, all_attr ~ (k_a_volume | k_a_dir | k_a_readonly))
  if ec_dst_attr < 0 and ec_dst_attr ~= k_EFILNF then  -- file not found is ok
    return ec_dst_attr, "dst_attr"
  end

  -- Get the DTA of the file
  local <const> ec_sfirst, dta_sfirst = k_Fsfirst(src_file, ec_src_attr)
  if ec_sfirst < 0 then
    return ec_sfirst, "src_notfound"
  end

  -- Open the destination file
  local <const> ec_open_dst, dst_fud <close> = k_Fcreate(dst_file, ec_src_attr)
  if ec_open_dst < 0 then
    return ec_open_dst, "dst_create"
  end

  -- Size of file being copied
  local <const> file_size = dta_sfirst:length()

  -- If file_size is zero then nothing needs to be copied
  if file_size == 0 then
    return 0, ""
  end

  -- Allocate memory for the data copy if premud was nil
  local alloc_mud
  if not premud then
     -- Work out alloc size
    local alloc_size = file_size
    if alloc_size > k_max_alloc_size then
      alloc_size = k_max_alloc_size
    end

    local ec_alloc_bytes
    ec_alloc_bytes, alloc_mud = k_allocm(alloc_size)
    if ec_alloc_bytes < 0 then
      return ec_alloc_bytes, "alloc"
    end
  end

  -- Closer for the alloc_mud
  local <close> alloc_mud_closer = alloc_mud

  -- Use the actual mud
  local <const> mud = alloc_mud or premud

  -- Open the src file
  local <const> ec_open_src, src_fud <close> = k_Fopen(src_file, k_o_readonly)
  if ec_open_src < 0 then
    return ec_open_src, "src_open"
  end

  -- Perform the copy
  local total_bytes_read = 0
  local total_bytes_written = 0
  local result = 0
  local error_msg
  repeat
    -- Read data
    local <const> bytes_read = src_fud:readm(mud, 0, mud:size())
    if bytes_read < 0 then
      result = bytes_read
      error_msg = "src_read"
      break
    elseif bytes_read > 0 then
      -- Call fn with read progress
      total_bytes_read = total_bytes_read + bytes_read
      result = fn(file_size, total_bytes_read, total_bytes_written)
      if result ~= 0 then
        error_msg = "fn_read"
        break
      end
    end

    -- Write data
    local <const> bytes_written = dst_fud:writem(mud, 0, bytes_read)
    if bytes_written < 0 then
      result = bytes_written
      error_msg = "src_write"
      break
    elseif bytes_written > 0 then
      -- Call fn with write progress
      total_bytes_written = total_bytes_written + bytes_written
      result = fn(file_size, total_bytes_read, total_bytes_written)
      if result ~= 0 then
        error_msg = "fn_write"
        break
      end
    end

    -- Check if write was short
    if bytes_written < bytes_read then
      result = -1
      error_msg = "dst_full"

      -- Delete the partial destination file
      dst_fud:close()
      k_Fdelete(dst_file)
      break
    end
  until bytes_read == 0

  -- Optionally preserve the timestamp
  if result == 0 and preserve_ts then
    -- Set the date and time
    result = k_Fdatime(dst_fud, dta_sfirst:datime())
    if result < 0 then
      error_msg = "dst_timestamp"
    end
  end

  return result, error_msg or ""
end

return FileCopy
