global assert, ipairs, require, setmetatable, table, gemdos, gempb

local <const> k_aes_global = gempb.const.Pbid.aes_global
local <const> k_wrapm = gemdos.utility.wrapm
local <const> k_s16 = gemdos.const.Imode.s16
local <const> k_u16 = gemdos.const.Imode.u16
local <const> k_s32 = gemdos.const.Imode.s32
local <const> k_obj_size = 24

local <const> k_RCache = require("gembindl.utility.rcache")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
local <const> k_text = aesdefs.obty_text
local <const> k_boxtext = aesdefs.obty_boxtext
local <const> k_ftext = aesdefs.obty_ftext
local <const> k_fboxtext = aesdefs.obty_fboxtext
local <const> k_indirect = aesdefs.obfl_indirect
aesdefs = nil

local <const> Rsrc = {}

-- Rsrc.new. Create Rsrc table using passed GEM parameter block.
-- Input:
--   1) userdata: pb the GEMPB userdata
--   2) table: table to use or nil for a new table
-- Result:
--   1) table: the Rsrc table
function Rsrc:new(pb, o)
  o = o or {}
  o.pb_ = pb
  self.__index = self
  return setmetatable(o, self )
end

-- wrap_rsrc_. Wraps the resource into memory.
function Rsrc:wrap_rsrc_()
  local <const> pb = self.pb_

  -- Get address of loaded resource
  local high, low = pb:peek(k_aes_global, 7, 2)
  local <const> load_addr = (high & 0xFFFF) << 16 | (low & 0xFFFF)
  assert(load_addr ~= 0)

  -- Wrap 36 byte header into a memory userdata and read 18 words
  local <const> word_t = k_wrapm(load_addr, 36):readt(k_u16, 0)
  -- Assert on header version
  assert(word_t[1] == 1)

  -- Convert hdr words into named key-values
  local <const> header = {
    vrsn = word_t[1], object = word_t[2],
    tedinfo = word_t[3], iconblk = word_t[4],
    bitblk = word_t[5], frstr = word_t[6],
    string = word_t[7], imdata = word_t[8],
    frimg = word_t[9], trindex = word_t[10],
    nobs = word_t[11], ntree = word_t[12],
    nted = word_t[13], nib = word_t[14],
    nbb = word_t[15], nstring = word_t[16],
    nimages = word_t[17], rssize = word_t[18]
  }

  -- Store header table
  self.rsrc_hdr_ = header

  -- Wrap the loaded rsrc into a memory userdata
  local <const> rsrc_mud = k_wrapm(load_addr, header.rssize)
  self.rsrc_mud_ = rsrc_mud
  self.rsrc_addr_ = load_addr
  self.rsrc_size_ = header.rssize

  -- Obtain tree addresses into a table
  high, low = pb:peek(k_aes_global, 5, 2)
  local <const> aptree_addr = (high & 0xFFFF) << 16 | (low & 0xFFFF)
  assert(aptree_addr ~= 0)
  self.tree_addr_ = k_wrapm(aptree_addr, header.ntree << 2):readt(k_s32, 0)

  -- Obtain tree offsets in the wrapped resource
  local <const> rsrc_mud_address = rsrc_mud:address()
  local <const> tree_offs = table.create(#self.tree_addr_)
  for k,v in ipairs(self.tree_addr_) do
    tree_offs[k] = v - rsrc_mud_address
  end
  self.tree_offs_ = tree_offs

  return true
end

-- address. Returns the address of the resource
-- Result:
--   1) integer: address of the resource
function Rsrc:address()
  return self.rsrc_addr_
end

-- size: Returns the size of the resource
-- Result:
--   1) integer: size of the resource
function Rsrc:size()
  return self.rsrc_size_
end

-- header. Returns resource header as a table.
-- Result:
--   1) table: the Rsrc header table
function Rsrc:header()
  return self.rsrc_hdr_
end

-- tree_addr. Returns address of tree given a tree number
-- Input:
--   1) integer: tree number
-- Returns:
--   1) integer: tree address
function Rsrc:tree_addr(tree_objn)
  return self.tree_addr_[tree_objn + 1]
end

-- tree_obj_offset. Returns rsrc offset of an object in a tree.
-- Input:
--   1) integer: tree_objn: tree number
--   2) integer: objn: object number in tree
-- Returns:
--   1) integer: resource offset
function Rsrc:tree_obj_offset(tree_objn, objn)
  return self.tree_offs_[tree_objn + 1] + objn * k_obj_size
end

-- peek. Returns resource data as values.
-- Input:
--   1) integer: imode: Imode for reading values
--   2) integer: rsrc_offset: offset relative to resource start
--   3) optional integer: n: number of values to read, default 1 maximum 24
-- Returns:
--   1) integer: resource data value(s)
function Rsrc:peek(imode, rsrc_offset, n)
  return self.rsrc_mud_:peek(imode, rsrc_offset, n)
end

-- poke. Pokes resource data
-- Input:
--   1): integer: imode: Imode for poking values
--   2): integer: rsrc_offset: offset relative to resource start
--   n): integer: values
function Rsrc:poke(imode, rsrc_offset, ...)
  return self.rsrc_mud_:poke(imode, rsrc_offset, ...)
end

-- reads. Reads resource string
-- Input:
--   1): integer: rsrc_offset: offset relative to resource start
--   2): integer: numbytes: number of bytes to read
--   3): integer: termbyte: early termination byte
-- Return:
--   1): string: resource data string
function Rsrc:reads(rsrc_offset, numbytes, termbyte)
  return self.rsrc_mud_:reads(rsrc_offset, numbytes, termbyte)
end

-- obj_peek_type. Returns resource object type
-- Input:
--   1) integer: rsrc_offset: object offset relative to resource start
-- Returns:
--   1) integer: object type
function Rsrc:obj_peek_type(rsrc_offset)
  return self.rsrc_mud_:peek(k_u16, rsrc_offset + 6)
end

-- obj_peek_flags. Returns resource object flags
-- Input:
--   1) integer: rsrc_offset: object offset relative to resource start
-- Returns:
--   1) integer: object flags
function Rsrc:obj_peek_flags(rsrc_offset)
  return self.rsrc_mud_:peek(k_u16, rsrc_offset + 8)
end

-- obj_poke_flags. Pokes resource object flags
-- Input:
--   1) integer: rsrc_offset: object offset releative to resource state
--   2) integer: new_flags: new flags for object
function Rsrc:obj_poke_flags(rsrc_offset, new_flags)
  return self.rsrc_mud_:poke(k_u16, rsrc_offset + 8, new_flags)
end

-- obj_peek_state. Returns resource object state
-- Input:
--   1) integer: rsrc_offset: object offset relative to resource start
-- Returns:
--   1) integer: object state
function Rsrc:obj_peek_state(rsrc_offset)
  return self.rsrc_mud_:peek(k_u16, rsrc_offset + 10)
end

-- obj_poke_state. Pokes resource object state
-- Input:
--   1) integer: rsrc_offset: object offset releative to resource state
--   2) integer: new_state: new state for object
function Rsrc:obj_poke_state(rsrc_offset, new_state)
  return self.rsrc_mud_:poke(k_u16, rsrc_offset + 10, new_state)
end

-- obj_peek_spec. Returns resource object spec
-- Input:
--   1) integer: rsrc_offset: object offset relative to resource start
-- Returns:
--   1) integer: object spec
function Rsrc:obj_peek_spec(rsrc_offset)
  return self.rsrc_mud_:peek(k_s32, rsrc_offset + 12)
end

-- obj_poke_spec. Pokes resource object spec
-- Input:
--   1) integer: rsrc_offset: object offset releative to resource state
--   2) integer: new_spec: new spec for object
function Rsrc:obj_poke_spec(rsrc_offset, new_spec)
  return self.rsrc_mud_:poke(k_s32, rsrc_offset + 12, new_spec)
end

-- obj_peek_pos. Peeks resource object position
-- Input:
--   1) integer: rsrc_offset: tree object resource offset
-- Returns:
--   1) integer: x
--   2) integer: y
--   3) integer: w
--   4) integer: h
function Rsrc:obj_peek_pos(rsrc_offset)
  return self.rsrc_mud_:peek(k_s16, rsrc_offset + 16, 4)
end

-- obj_poke_pos. Pokes resource object position
-- Input:
--   1) integer: rsrc_offset: tree object resource offset
--   2) integer: x: x position
--   3) integer: y: y position 
--   3) integer: w: width
--   4) integer: h: height
function Rsrc:obj_poke_pos(rsrc_offset, x, y, w, h)
  return self.rsrc_mud_:poke(k_s16, rsrc_offset + 16, x, y, w, h)
end

-- tedinfo_offset. Returns rsrc offset of a tedinfo in the resource
-- Input:
--   1) integer: rsrc_offset: text object resource offset
-- Returns:
--   1) integer: tedinfo resource offset
function Rsrc:obj_tedinfo_offset(rsrc_offset)
  local <const> type, flags, spec =
    self:obj_peek_type(rsrc_offset), self:obj_peek_flags(rsrc_offset),
    self:obj_peek_spec(rsrc_offset) -- spec is a pointer to tedinfo.
  assert(flags & k_indirect == 0 and -- indirect flag not supported
    (type == k_text or type == k_boxtext or -- only these types have tedinfo
    type == k_ftext or type == k_fboxtext))
  -- Return the offset of the tedinfo in the resource
  return spec - self.rsrc_addr_
end

-- tedinfo_read_text. Returns resource tedinfo text
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) string: the text
--   2) integer: the txtlen value for the text
function Rsrc:tedinfo_read_text(rsrc_offset)
  local <const> rsrc_mud = self.rsrc_mud_
  local <const> ptext = rsrc_mud:peek(k_s32, rsrc_offset)
  local <const> txtlen = rsrc_mud:peek(k_s16, rsrc_offset + 24)
  return rsrc_mud:reads(ptext - self.rsrc_addr_, txtlen, 0), txtlen
end

-- tedinfo_write_text. Writes resource tedinfo text
-- Input:
--   1) integer: rsrc_offset: offset relative to resource state
--   2) string: text to write
function Rsrc:tedinfo_write_text(rsrc_offset, text)
  local <const> rsrc_mud = self.rsrc_mud_
  local <const> ptext = rsrc_mud:peek(k_s32, rsrc_offset)
  local <const> txtlen = rsrc_mud:peek(k_s16, rsrc_offset + 24)
  text = text .. "\0"
  assert(#text <= txtlen)
  return rsrc_mud:writes(ptext - self.rsrc_addr_, text)
end

-- tedinfo_read_tmplt. Returns resource tedinfo tmplt
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) string: the tmplt
--   2) integer: the tmplen value for the tmplt
function Rsrc:tedinfo_read_tmplt(rsrc_offset)
  local <const> rsrc_mud = self.rsrc_mud_
  local <const> ptmplt = rsrc_mud:peek(k_s32, rsrc_offset + 4)
  local <const> tmplen = rsrc_mud:peek(k_s16, rsrc_offset + 26)
  return rsrc_mud:reads(ptmplt - self.rsrc_addr_, tmplen, 0), tmplen
end

-- tedinfo_read_valid. Returns resource tedinfo valid
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) string: the valid
function Rsrc:tedinfo_read_valid(rsrc_offset)
  local <const> rsrc_mud = self.rsrc_mud_
  local <const> pvalid = rsrc_mud:peek(k_s32, rsrc_offset + 8)
  return rsrc_mud:reads(pvalid - self.rsrc_addr_, nil, 0)
end

-- frstr_offset. Returns address of a free string in the resource
-- Input:
--   1) integer: free string number
-- Returns:
--   1) integer: free string address
function Rsrc:frstr_addr(frstr_objn)
  return self.rsrc_mud_:peek(k_s32, self.rsrc_hdr_.frstr + (frstr_objn << 2))
end

-- frstr_offset. Returns rsrc offset of a free string in the resource
-- Input:
--   1) integer: free string number
-- Returns:
--   1) integer: resource offset
function Rsrc:frstr_offset(frstr_objn)
  return self:frstr_addr(frstr_objn) - self.rsrc_addr_
end

-- frimg_offset. Returns address of a free image in the resource
-- Input:
--   1) integer: free image number
-- Returns:
--   1) integer: free image address
function Rsrc:frimg_addr(frimg_objn)
  return self.rsrc_mud_:peek(k_s32, self.rsrc_hdr_.frimg + (frimg_objn << 2))
end

-- frimg_offset. Returns rsrc offset of a free image in the resource
-- Input:
--   1) integer: free image number
-- Returns:
--   1) integer: resource offset
function Rsrc:frimg_offset(frimg_objn)
  return self:frimg_addr(frimg_objn) - self.rsrc_addr_
end

-- objects. Form object iterator factory
-- Input:
--   1) integer: tree_objn: tree number
--   2) integer: objn: object number for start of iteration
-- Returns:
--   1) function: object iterator function
function Rsrc:objects(tree_objn, objn)
  -- Offset of tree relative to start of resource memory
  local <const> tree_offset = self.tree_offs_[tree_objn + 1]
  local <const> rsrc_mud = self.rsrc_mud_
  local prev

  return function()
    if objn == -1 then
      return
    elseif prev == nil then
      prev = objn
    end

    repeat
      local <const> offset = tree_offset + objn * k_obj_size
      local <const> next, head, tail = rsrc_mud:peek(k_s16, offset, 3)
      if tail == prev then
        -- Just gone up, so go next
        prev = objn
        objn = next
      else
        prev = objn
        if head == -1 then
          -- Can't go down so go next
          objn = next
        else
          -- Going down
          objn = head
        end
        return prev, offset
      end
    until objn == -1
  end
end

-- wrap. Wraps the resource
function Rsrc:wrap()
  -- Wrap the resource
  return self:wrap_rsrc_()
end

-- unwrap. Unwraps the resource
function Rsrc:unwrap()
  self.rsrc_hdr_ = nil
  self.rsrc_mud_:free()
  self.rsrc_mud_ = nil
  self.rsrc_addr_ = nil
  self.rsrc_size_ = nil
  self.tree_addr_ = nil
  self.tree_offs_ = nil
end

return Rsrc
