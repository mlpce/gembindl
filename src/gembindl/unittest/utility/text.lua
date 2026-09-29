local Text = require("gembindl.utility.disk.text")

gemdos.Cconws("Testing load_lines\r\n")

-- Create test data file
local ec, fud_out <close> =
  gemdos.Fcreate("TESTFILE.TXT", gemdos.const.Fattrib.none)
assert(ec == 0)
local <const> test_file_data = "one\ntwo\r\nthree\nfour 01234567890123456789\z
  012345678901234567890123456789012345678901234567890123456789\r\n\z
  five\r\nsix"
ec = fud_out:writes(test_file_data)
assert(ec == #test_file_data)
fud_out:close()

-- Load the test data file
local tbl
ec, tbl = Text.load_lines("TESTFILE.TXT")
assert(ec == 0)

-- Check each line was loaded into the table
assert(#tbl == 6)
assert(tbl[1] == "one")
assert(tbl[2] == "two")
assert(tbl[3] == "three")
assert(tbl[4] == "four 01234567890123456789\z
  012345678901234567890123456789012345678901234567890123456789")
assert(tbl[5] == "five")
assert(tbl[6] == "six")

ec = gemdos.Fdelete("TESTFILE.TXT")
assert(ec == 0)

gemdos.Cconws("Testing load_cdefs\r\n")

local ec, fud_out <close> =
  gemdos.Fcreate( "TESTFILE.H", gemdos.const.Fattrib.none)
assert(ec == 0)
local <const> test_header_data =
  "#define a 1\n    #define    b    2  \r\n\t#define\tc\t3"
ec = fud_out:writes(test_header_data)
assert(ec == #test_header_data)
fud_out:close()

local defs_tbl
ec, defs_tbl = Text.load_cdefs("TESTFILE.H")
assert(ec == 0)
-- Check each simple define was loaded into the table
assert(defs_tbl.a == 1)
assert(defs_tbl.b == 2)
assert(defs_tbl.c == 3)

ec = gemdos.Fdelete("TESTFILE.H")
assert(ec == 0)
