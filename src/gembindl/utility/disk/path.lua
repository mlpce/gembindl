global assert, error, string, type, warn, gemdos

local <const> k_Dsetpath = gemdos.Dsetpath
local <const> k_Dgetdrv = gemdos.Dgetdrv
local <const> k_Dsetdrv = gemdos.Dsetdrv
local <const> k_Dgetpath = gemdos.Dgetpath
local <const> k_EDRIVE = gemdos.const.Error.EDRIVE
local <const> k_EPTHNF = gemdos.const.Error.EPTHNF

local <const> k_colon_byte = string.byte(":")
local <const> k_backslash_byte = string.byte("\\");
-- Pattern for allowed chars in a path
local <const> k_allowed_path_char =
  "[]%%:\\[.a-zA-Z%d!@#$%^&()+=~`;'\",<>|()_-]+"
-- Pattern for allowed chars in a filename including '.' separator
local <const> k_allowed_fname_char =
  "[]%%[.a-zA-Z%d!@#$%^&()+=~`;'\",<>|()_-]+"
-- Capture for allowed chars in a filename including '.' separator
local <const> k_allowed_fname_char_capture =
  "(" .. k_allowed_fname_char .. ")"

local <const> Path = {}

-- drive_letter_to_num
-- Input:
--   1) string: letter: the drive letter (either lower or upper case)
-- Returns:
--   2) integer: drive number (A = 0, B = 1, C = 2, ...)
local <const> a_code, z_code = string.byte('a'), string.byte('z')
local <const> A_code, Z_code = string.byte('A'), string.byte('Z')
local function drive_letter_to_num(letter)
  local <const> letter_code = string.byte(letter)
  local drive_num
  if letter_code >= a_code and letter_code <= z_code then
    drive_num = letter_code - a_code
  elseif letter_code >= A_code and letter_code <= Z_code then
    drive_num = letter_code - A_code
  end
  assert(drive_num)
  return drive_num
end

-- normalize_path. Makes the path absolute. It does not check if the
-- path exists.
-- Input:
--   1) string: path: the path to normalize
-- Returns:
--   1) integer: 0 on success, otherwise error
--   2) string: the normalized path
function Path.normalize_path(path)
  -- Obtain the drive letter if there is one
  local <const> drive_letter = string.match(path, "^([a-zA-Z]):")
  if not drive_letter and string.byte(path, 2) == k_colon_byte then
    -- The drive letter was invalid
    warn("normalize_path: invalid drive letter")
    return k_EDRIVE
  end

  -- Validate the path
  if not Path.validate_path(path) then
    return k_EPTHNF
  end

  -- If the path is relative, the drive path needs prepending
  local ec
  if drive_letter and string.byte(path, 3) ~= k_backslash_byte then
    -- If there is a drive letter and no backslash, the path is relative
    -- to a specific drive's path.
    -- Prepend the drive's current path to the relative path.
    local <const> drive_number = drive_letter_to_num(drive_letter)
    local drive_path
    ec, drive_path = k_Dgetpath(drive_number + 1)
    if ec ~= 0 then
      -- Could not get the drive's path
      warn("normalize_path: Could not get drive's path")
      return ec
    end
    -- combine the drive letter, drive path and path.
    path = string.format("%s:%s\\%s", drive_letter, drive_path, string.sub(path, 3))
  elseif not Path.is_abs_path(path) then
    -- Path has no drive letter and is relative.
    -- Prepend current drive's current path to the relative path
    local drive_path
    ec, drive_path = Path.get_path()
    if ec ~= 0 then
      warn("normalize_path: Could not get current path")
      return ec
    end
    -- Combine the current drive's path and the path.
    path = string.format("%s\\%s", drive_path, path)
  end

  -- Replace \.\ with \ until all have been removed
  repeat
    local a
    path, a = string.gsub(path, "\\%.\\", "\\")
  until a == 0

  -- Remove \x\..\ by eliding parent
  repeat
    local a, b
    -- Replace \\ with \
    path, a = string.gsub(path, "\\\\+", "\\")

    -- If X:\.. then can't go any higher 
    if string.find(path, "^[a-zA-Z]:\\%.%.") then
      warn("normalize_path: eliding over top")
      return k_EPTHNF
    end

    -- Replace \x\..\ with \, one match at a time
    path, b = string.gsub(path,
      "\\" .. k_allowed_fname_char_capture .. "\\%.%.\\", "\\", 1)
  until a + b == 0

  -- Remove redundant trailing \.
  path = string.gsub(path, "\\%.$", "")

  -- Remove trailing \x\.. by eliding parent
  path = string.gsub(path,
    "\\" .. k_allowed_fname_char_capture .. "\\%.%.$", "\\")

  -- Remove redundant trailing \
  if #path > 3 then
    path = string.gsub(path, "\\$", "")
  end

  return 0, path
end

-- validate_path. Path may be relative or absolute.
-- Input:
--   1) string: path
--   2) integer: position in the string where checking starts
-- Returns:
--   1) boolean: true if path is validated, otherwise false
function Path.validate_path(path, starting_pos)
  starting_pos = starting_pos or 1
  local s, e = string.find(path, k_allowed_path_char, starting_pos)
  if s ~= 1 or e ~= #path then
    warn("validate_path: invalid path char")
    return false
  end

  if string.byte(path, starting_pos + 1) == k_colon_byte then
    if not string.find(path, "^[a-zA-Z]:", starting_pos) then
      -- Drive letter is not a letter
      warn("validate_path: drive letter not a letter")
      return false
    else
      -- Skip drive letter and colon
      starting_pos = starting_pos + 2
    end
  end

  -- Find start of first component
  local component_pos = string.find(path, "[^\\]", starting_pos)
  if not component_pos then
    return true
  end

  -- Check each component
  local last_e = component_pos
  for s, component, e in string.gmatch(path,
      "()" .. k_allowed_fname_char_capture .. "\\?()", starting_pos) do
--    gemdos.Cconws("s " .. s .. " e " .. e .. " last_e " .. last_e .. "\r\n")
    if #component > 12 then
      -- exceeded 8.3 maximum of 12 characters so invalid
      warn("validate_path: 8.3 exceeded")
      return false
    end
    local <const> dot_pos = string.find(component, ".", 1, true)
    if dot_pos then
      if component ~= ".." then
        -- Must only be one . in the component
        if string.find(component, ".", dot_pos + 1, true) then
          --  More than one dot so invalid
          warn("validate_path: too many dots")
          return false
        end
        -- Position of .
        if dot_pos > 9 or dot_pos < #component - 3 then
          -- dot position too far from component start or end
          warn("validate_path: dot position")
          return false
        end
      end
    end
    if s ~= last_e then
      -- Invalid character detected in component
      warn("validate_path: invalid char")
      return false
    end
    last_e = e
  end
  if #path ~= last_e - 1 then
    -- Invalid character detected in component
    warn("validate_path: invalid char ending")
    return false
  end
  return true
end

-- join_path. Joins two paths with a singular backslash
-- Input:
--   1) string: path 1
--   2) string: path 2
-- Returns:
--   1) string: the joined path
function Path.join_path(path1, path2)
  local <const> p1_last_byte, p2_first_byte =
    string.byte(path1, -1), string.byte(path2)

  if p1_last_byte == k_backslash_byte and
      p2_first_byte == k_backslash_byte then
    return path1 .. string.sub(path2, 2)
  elseif p1_last_byte ~= k_backslash_byte and
      p2_first_byte ~= k_backslash_byte then
    return path1 .. "\\" .. path2 
  end

  return path1 .. path2
end

-- is_abs_path
-- Return true if path is an absolute path
-- Input:
--   1) string: path
-- Returns:
--   1) boolean: true if path is absolute, otherwise false
function Path.is_abs_path(path)
  return string.byte(path) == k_backslash_byte or
    string.find(path, "^[a-zA-Z]:\\") and true or false
end

-- fname_from_path
-- Returns the filename at the end of a path (without directory)
-- Input:
--   1) string: path
-- Returns:
--   2) string: filename
function Path.fname_from_path(path)
  return string.match(path, "[^\\]*$")
end

-- dir_from_path
-- Returns the directory part of a path (without filename)
-- Input:
--   1) string: path
-- Returns:
--   2) string: directory
function Path.dir_from_path(path)
  -- Get the containing directory from the path
  return string.sub(path, 1, #path - #Path.fname_from_path(path))
end

-- fname_split
-- Splits filename into two, leading the dot and trailing (extension)
-- Input:
--  1) string: filename to split
-- Returns:
--  1) string: leading part
--  2) string: trailing part (extension)
function Path.fname_split(fname)
  -- First make sure any path is removed leaving just filename
  local <const> stripped_fname = Path.fname_from_path(fname)
  -- Split into leading and extension
  local <const> leading = string.match(stripped_fname, "^[^.]+")
  local <const> extension = string.sub(stripped_fname, #leading + 2)
  return leading, extension
end

-- set_path. Changes the current directory path
-- Input:
--   1) string: path (relative or absolute)
-- Returns:
--   1) integer: 0 on success, otherwise -ve error
function Path.set_path(path)
  assert(type(path) == "string")
  local <const> ec, path = Path.normalize_path(path)
  if ec ~= 0 then
    return ec
  end

  -- Path is normalized so must have a drive letter
  -- Get the drive letter
  local <const> drive_letter = string.match(path, "^([a-zA-Z]):\\")
  assert(drive_letter)

  -- Work out drive_number to set
  local <const> drive_number = drive_letter_to_num(drive_letter)

  -- Is drive different to current drive?
  local <const> current_drive = k_Dgetdrv()
  if drive_number ~= current_drive then
    -- Check drive is recognised
    local <const> drive_bits = k_Dsetdrv(current_drive)
    local <const> drive_number_bit = 1 << drive_number

    -- Is the drive not valid?
    if drive_bits & drive_number_bit == 0 then
      -- Drive is not valid
      return k_EDRIVE
    end

    -- Set the drive
    k_Dsetdrv(drive_number)
    -- Check the drive changed
    if k_Dgetdrv() ~= drive_number then
      return k_EDRIVE
    end
  end

  -- Directory to set
  local <const> directory = string.sub(path, 3)
  assert(#directory > 0)

  -- Set the path
  return k_Dsetpath(directory)
end

-- get_path. Gets the current directory path
-- Returns
--   1) string: path
function Path.get_path()
  -- Get the current drive
  local <const> drive = k_Dgetdrv()

  -- Get the current path
  local ec <const>, path = k_Dgetpath(0)
  if ec < 0 then
    return ec
  end

  if path == "" then
    path = "\\"
  end

  -- Convert drive number to drive letter
  local <const> drive_letter = string.char(drive + A_code)

  -- Return the directory
  return 0, drive_letter .. ":" .. path
end

return Path
