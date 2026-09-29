global setmetatable, gemdos

local <const> k_s16 = gemdos.const.Imode.s16

local <const> Structs = {}

-- Create a new Structs
function Structs:new(rsrc, o)
  o = o or {}
  o.rsrc_ = rsrc
  self.__index = self
  return setmetatable(o, self )
end

-- obj_peek. Returns resource object as values
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) integer: ob_next
--   2) integer: ob_head
--   3) integer: ob_tail
--   4) integer: ob_type
--   5) integer: ob_flags
--   6) integer: ob_state
--   7) integer: ob_spec
--   8) integer: ob_x
--   9) integer: ob_y
--   10) integer: ob_width
--   11) integer: ob_height
function Structs:obj_peek(rsrc_offset)
  local <const> ob_next, ob_head, ob_tail, ob_type,
    ob_flags, ob_state, ob_spec_hi, ob_spec_lo,
    ob_x, ob_y, ob_width, ob_height =
      self.rsrc_:peek(k_s16, rsrc_offset, 12)

  return ob_next, ob_head, ob_tail, ob_type & 0xFFFF,
    ob_flags & 0xFFFF, ob_state & 0xFFFF,
    (ob_spec_hi & 0xFFFF) << 16 | (ob_spec_lo & 0xFFFF),
    ob_x, ob_y, ob_width, ob_height
end

-- obj_readt. Returns resource object as a table
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) table: table containing object values
function Structs:obj_readt(rsrc_offset)
  local <const> ob_next, ob_head, ob_tail, ob_type,
    ob_flags, ob_state, ob_spec,
    ob_x, ob_y, ob_width, ob_height = self:obj_peek(rsrc_offset)

  return {
    ob_next = ob_next, ob_head = ob_head, ob_tail = ob_tail,
    ob_type = ob_type, ob_flags = ob_flags, ob_state = ob_state,
    ob_spec = ob_spec, ob_x = ob_x, ob_y = ob_y, ob_width = ob_width,
    ob_height = ob_height
  }
end

-- tedinfo_peek. Returns resource tedinfo as values
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) integer: ptext
--   2) integer: ptmplt
--   3) integer: pvalid
--   4) integer: font
--   5) integer: fontid
--   6) integer: just
--   7) integer: color
--   8) integer: fontsize
--   9) integer: thickness
--   10) integer: txtlen
--   11) integer: tmplen
function Structs:tedinfo_peek(rsrc_offset)
  local <const> te_ptext_hi, te_ptext_lo,
    te_ptmplt_hi, te_ptmplt_lo,
    te_pvalid_hi, te_pvalid_lo,
    te_font, te_fontid, te_just,
    te_color, te_fontsize, te_thickness,
    te_txtlen, te_tmplen =
      self.rsrc_:peek(k_s16, rsrc_offset, 14)

  return (te_ptext_hi & 0xFFFF) << 16 | (te_ptext_lo & 0xFFFF),
    (te_ptmplt_hi & 0xFFFF) << 16 | (te_ptmplt_lo & 0xFFFF),
    (te_pvalid_hi & 0xFFFF) << 16 | (te_pvalid_lo & 0xFFFF),
    te_font, te_fontid, te_just, te_color, te_fontsize, te_thickness,
    te_txtlen, te_tmplen
end

-- tedinfo_readt. Returns resource tedinfo as a table
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) table: table containing tedinfo values
function Structs:tedinfo_readt(rsrc_offset)
  local <const> te_ptext, te_ptmplt, te_pvalid,
    te_font, te_fontid, te_just,
    te_color, te_fontsize, te_thickness,
    te_txtlen, te_tmplen = self:tedinfo_peek(rsrc_offset)

  return {
    te_ptext = te_ptext, te_ptmplt = te_ptmplt,
    te_pvalid = te_pvalid, te_font = te_font,
    te_fontid = te_fontid, te_just = te_just,
    te_color = te_color, te_fontsize = te_fontsize,
    te_thickness = te_thickness, te_txtlen = te_txtlen,
    te_tmplen = te_tmplen
  }
end

-- bitblk_peek. Returns resource bitblk as values
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) integer: pdata: pointer to bit image data
--   2) integer: wb: width of bit image in bytes
--   3) integer: hl: height of bit image in lines
--   4) integer: x: x position of top left
--   5) integer: y: y position of top left
--   6) integer: color: foreground color of image
function Structs:bitblk_peek(rsrc_offset)
  local <const> bi_pdata_hi, bi_pdata_lo, bi_wb, bi_hl,
    bi_x, bi_y, bi_color = self.rsrc_:peek(k_s16, rsrc_offset, 7)

  return (bi_pdata_hi & 0xFFFF) << 16 | (bi_pdata_lo & 0xFFFF),
    bi_wb, bi_hl, bi_x, bi_y, bi_color
end

-- bitblk_readt. Returns resource bitblk as a table
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) table: table containing bitblk values
function Structs:bitblk_readt(rsrc_offset)
  local <const> bi_pdata, bi_wb, bi_hl,
    bi_x, bi_y, bi_color = self:bitblk_peek(rsrc_offset)

  return {
    bi_pdata = bi_pdata, bi_wb = bi_wb, bi_hl = bi_hl,
    bi_x = bi_x, bi_y = bi_y, bi_color = bi_color
  }
end

-- iconblk_peek. Returns resource iconblk as values
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) integer: pmask: pointer to mask
--   2) integer: pdata: pointer to data
--   3) integer: ptext: pointer to text
--   4) integer: char: colour and letter
--   5) integer: xchar: rel. x position of letter
--   6) integer: ychar: rel. y position of letter
--   7) integer: xicon: rel. x position of icon
--   8) integer: yicon: rel. y position of icon
--   9) integer: wicon: width of icon in pixels
--   10) integer: hicon: height of icon in pixels
--   11) integer: xtext: rel. x position of text
--   12) integer: ytext: rel. y position of text
--   13) integer: wtext: width of icon text in pixels
--   14) integer: htext: height of icon text in pixels
function Structs:iconblk_peek(rsrc_offset)
  local <const> ib_pmask_hi, ib_pmask_lo,
    ib_pdata_hi, ib_pdata_lo,
    ib_ptext_hi, ib_ptext_lo,
    ib_char, ib_xchar, ib_ychar,
    ib_xicon, ib_yicon, ib_wicon, ib_hicon,
    ib_xtext, ib_ytext, ib_wtext, ib_htext =
      self.rsrc_:peek(k_s16, rsrc_offset, 17)

  return (ib_pmask_hi & 0xFFFF) << 16 | (ib_pmask_lo & 0xFFFF),
    (ib_pdata_hi & 0xFFFF) << 16 | (ib_pdata_lo & 0xFFFF),
    (ib_ptext_hi & 0xFFFF) << 16 | (ib_ptext_lo & 0xFFFF),
    ib_char, ib_xchar, ib_ychar,
    ib_xicon, ib_yicon, ib_wicon, ib_hicon,
    ib_xtext, ib_ytext, ib_wtext, ib_htext
end

-- iconblk_readt. Returns resource iconblk as a table
-- Input:
--   1) integer: rsrc_offset: offset relative to resource start
-- Returns:
--   1) table: table containing iconblk values
function Structs:iconblk_readt(rsrc_offset)
  local <const> ib_pmask, ib_pdata, ib_ptext,
    ib_char, ib_xchar, ib_ychar,
    ib_xicon, ib_yicon, ib_wicon, ib_hicon,
    ib_xtext, ib_ytext, ib_wtext, ib_htext =
      self:iconblk_peek(rsrc_offset)

  return {
    ib_pmask = ib_pmask, ib_pdata = ib_pdata,
    ib_ptext = ib_ptext, ib_char = ib_char,
    ib_xchar = ib_xchar, ib_ychar = ib_ychar,
    ib_xicon = ib_xicon, ib_yicon = ib_yicon,
    ib_wicon = ib_wicon, ib_hicon = ib_hicon,
    ib_xtext = ib_xtext, ib_ytext = ib_ytext,
    ib_wtext = ib_wtext, ib_htext = ib_htext
  }
end

return Structs
