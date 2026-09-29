global assert, setmetatable, table, gempb

local <const> VDI = {}

local <const> k_vdi_control = gempb.const.Pbid.vdi_control
local <const> k_vdi_intin = gempb.const.Pbid.vdi_intin
local <const> k_vdi_ptsin = gempb.const.Pbid.vdi_ptsin
local <const> k_vdi_intout = gempb.const.Pbid.vdi_intout
local <const> k_vdi_ptsout = gempb.const.Pbid.vdi_ptsout

-- new. Create VDI table using passed GEM parameter block.
-- Input:
--   1) userdata: pb the GEMPB userdata
--   2) table: table to use or nil for a new table
-- Result:
--   1) table: the VDI table
function VDI:new(pb, o)
  o = o or {}
  o.pb_ = pb
  self.__index = self
  return setmetatable(o, self)
end

-- pb
-- Returns:
--   1) integer: parameter block user data
function VDI:pb()
  return self.pb_
end

-- bversion. gemdbindl VDI binding version
-- Returns:
--   1) integer: gembindl VDI binding major version
--   2) integer: gembindl VDI binding minor version
--   3) integer: gembindl VDI binding micro version
function VDI:bversion()
  return 1, 0, 0
end

-- v_opnwk. Open workstation.
-- Input:
--   1) table: workin (array of 11 numbers):
--      {
--        device id [from assign.sys],
--        line drawing pattern [vsl_type()],
--        Line pen number [vsl_color()],
--        Marker type [vsm_type()],
--        Marker pen number [vsm_color()],
--        Text font [vst_font()],
--        Text pen number [vst_color()],
--        Fill pattern type [vsf_interior()],
--        Fill pattern index [vsf_style()],
--        Fill pen number [vsf_color()],
--        0 = NDC otherwise 2 = RC
--      }
-- Result:
--   1) integer: Physical workstation handle
--   2) table: workout (array of 57 numbers)
function VDI:v_opnwk(workin)
  assert(#workin == 11)
  local pb <const> = self.pb_
  pb:set(k_vdi_intin, 0, workin)
  return pb:call(
    k_vdi_control, 4, 0, 1, 0, 11,
    k_vdi_control, 0x60001), pb:get(k_vdi_intout, 0, 57)
end

-- v_clswk. Close workstation.
-- Input:
--   1) integer: physical workstation handle
-- Result:
--   None
function VDI:v_clswk(handle)
  return self.pb_:vdi(handle, 2)
end

-- v_clrwk. Clear workstation.
-- Inputs:
--   1) integer: workstation handle
-- Result:
--   None
function VDI:v_clrwk(handle)
  return self.pb_:vdi(handle, 3)
end

-- v_updwk. Update workstation.
-- Input:
--   1) integer: workstation handle
-- Result:
--   1) integer: status code (valid for SLM804 driver)
function VDI:v_updwk(handle)
  return self.pb_:call(
    k_vdi_control, 2, handle, 4,
    k_vdi_intout, 1)
end

-- vq_chcells.
-- Input:
--   1) integer: workstation handle
-- Result:
--   1) integer: number of rows for alpha text mode
--   2) integer: number of columns for alpha text mode
function VDI:vq_chcells(handle)
  return self.pb_:call(
    k_vdi_control, 3, handle, 5, 1,
    k_vdi_intout, 2)
end

-- v_exit_cur. Exit text mode and restore mouse pointer
-- Input:
--   1) integer: workstation handle
function VDI:v_exit_cur(handle)
  return self.pb_:vdi(handle, 5, 2)
end

-- v_enter_cur. Enter text mode
-- Input:
--   1) integer: workstation handle
function VDI:v_enter_cur(handle)
  return self.pb_:vdi(handle, 5, 3)
end

-- v_curup. Move text cursor up one line
-- Input:
--   1) integer: workstation handle
function VDI:v_curup(handle)
  return self.pb_:vdi(handle, 5, 4)
end

-- v_curdown. Move text cursor down one line
-- Input:
--   1) integer: workstation handle
function VDI:v_curdown(handle)
  return self.pb_:vdi(handle, 5, 5)
end

-- v_curright. Move text cursor right one column
-- Input:
--   1) integer: workstation handle
function VDI:v_curright(handle)
  return self.pb_:vdi(handle, 5, 6)
end

-- v_curleft. Move text cursor left one column
-- Input:
--   1) integer: workstation handle
function VDI:v_curleft(handle)
  return self.pb_:vdi(handle, 5, 7)
end

-- v_curhome. Move text cursor to top left position
-- Input:
--   1) integer: workstation handle
function VDI:v_curhome(handle)
  return self.pb_:vdi(handle, 5, 8)
end

-- v_eeos. Erase to end of screen
-- Input:
--   1) integer: workstation handle
function VDI:v_eeos(handle)
  return self.pb_:vdi(handle, 5, 9)
end

-- v_eeol. Erase to end of line
-- Input:
--   1) integer: workstation handle
function VDI:v_eeol(handle)
  return self.pb_:vdi(handle, 5, 10)
end

-- vs_curaddress. Move cursor to screen position
-- Input:
--   1) integer: workstation handle
--   2) integer: row
--   3) integer: column
function VDI:vs_curaddress(handle, row, column)
  return self.pb_:call(
    k_vdi_intin, 2, row, column,
    k_vdi_control, 4, handle, 5, 11, 2)
end

-- v_curtext. Output alpha text at cursor position.
-- Input:
--   1) integer: workstation handle
--   2) string: the string to output
function VDI:v_curtext(handle, str)
  local <const> pb = self.pb_
  pb:setstr(0, str)
  return pb:vdi(handle, 5, 12, #str)
end

-- v_rvon. Turn on reverse video.
-- Input:
--   1) integer: workstation handle
function VDI:v_rvon(handle)
  return self.pb_:vdi(handle, 5, 13)
end

-- v_rvoff. Turn off reverse video.
-- Input:
--   1) integer: workstation handle
function VDI:v_rvoff(handle)
  return self.pb_:vdi(handle, 5, 14)
end

-- vq_curaddress. Inquire cursor address.
-- Input:
--   1) integer: workstation handle
-- Return:
--   1) integer: row
--   2) integer: column
function VDI:vq_curaddress(handle)
  return self.pb_:call(
    k_vdi_control, 3, handle, 5, 15,
    k_vdi_intout, 2)
end

-- vq_tabstatus. Inquire tablet status.
-- Input:
--   1) integer: workstation handle
-- Return:
--   1) integer: 0 = not available, 1 = available
function VDI:vq_tabstatus(handle)
  return self.pb_:call(
    k_vdi_control, 3, handle, 5, 16,
    k_vdi_intout, 1)
end

-- v_hardcopy. Print screen.
-- Input:
--   1) integer: workstation handle
function VDI:v_hardcopy(handle)
  return self.pb_:vdi(handle, 5, 17)
end

-- v_dspcur. Display graphics cursor at position
-- Input:
--   1) integer: workstation handle
--   2) integer: x position
--   3) integer: y position
function VDI:v_dspcur(handle, x, y)
  return self.pb_:call(
    k_vdi_ptsin, 2, x, y,
    k_vdi_control, 5, handle, 5, 18, 0, 1
  )
end

-- v_rmcur. Remove graphics cursor
-- Input:
--   1) integer: workstation handle
function VDI:v_rmcur(handle)
  return self.pb_:vdi(handle, 5, 19)
end

-- v_form_adv. Form advance
-- Input:
--   1) integer: workstation handle
function VDI:v_form_adv(handle)
  return self.pb_:vdi(handle, 5, 20)
end

-- v_output_window. Output window
-- Input:
--   1) integer: workstation handle
--   2) integer: x coord left edge
--   3) integer: y coord top edge
--   4) integer: x coord right edge
--   5) integer: y coord bottom edge
function VDI:v_output_window(handle, x1, y1, x2, y2)
  return self.pb_:call(
    k_vdi_ptsin, 4, x1, y1, x2, y2,
    k_vdi_control, 5, handle, 5, 21, 0, 2)
end

-- v_clear_disp_list. Clear display list
-- Input:
--   1) integer: workstation handle
function VDI:v_clear_disp_list(handle)
  return self.pb_:vdi(handle, 5, 22)
end

-- v_bit_image. Output bit image file
-- Input:
--   1) integer: workstation handle
--   2) string: filename
--   3) integer: pixel aspect ratio (0 = ignore, 1 = preserve)
--   4) integer: xscale (0 = fractional, 1 = integer)
--   5) integer: yscale (0 = fractional, 1 = integer)
--   6) integer: halign (0 = left, 1 = center, 2 = right)
--   7) integer: valign (0 = top, 1 = middle, 2 = bottom)
--   8) table: point array (between 0 and 2 points)
--   NOTE: See VDIDefs for alignments
function VDI:v_bit_image(handle, filename, aspect, xscale, yscale,
    halign, valign, pxy)
  pxy = pxy or {}
  assert(#pxy <= 4)
  local <const> pb = self.pb_
  pb:setstr(5, filename)
  pb:set(k_vdi_ptsin, 0, pxy)
  return pb:call(
    k_vdi_intin, 5, aspect, xscale, yscale, halign, valign,
    k_vdi_control, 5, handle, 5, 23, #filename + 5, #pxy >> 1)
end

-- vq_scan. Query printer banding
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: grh
--   2) integer: passes
--   3) integer: alh
--   4) integer: apage
--   5) integer: div
function VDI:vq_scan(handle)
  return self.pb_:call(
    k_vdi_control, 3, handle, 5, 24,
    k_vdi_intout, 5)
end

-- v_alpha_text. Output a line of alpha text
-- Input:
--   1) integer: workstation handle
--   2) string: the string to output
function VDI:v_alpha_text(handle, str)
  local <const> pb = self.pb_
  pb:setstr(0, str)
  return pb:vdi(handle, 5, 25, #str)
end

-- vm_filename. User-defined filename for metafile
-- Input:
--   1) integer: workstation handle
--   2) string: filename
function VDI:vm_filename(handle, fname)
  local <const> pb = self.pb_
  pb:setstr(0, fname)
  return pb:vdi(handle, 5, 100, #fname)
end

-- v_pline_t. Output polyline using table coordinates
-- Input:
--   1) integer: workstation handle
--   2) table: point array
function VDI:v_pline_t(handle, pxy)
  local <const> pb = self.pb_
  pb:set(k_vdi_ptsin, 0, pxy)
  return pb:vdi(handle, 6, 0, 0, #pxy >> 1)
end

-- v_pline_v. Output polyline using vargs coordinates
-- Input:
--   1) integer: workstation handle
--   n) integer: coordinates
function VDI:v_pline_v(handle, ...vararg)
  local <const> pb = self.pb_
  pb:poke(k_vdi_ptsin, 0, ...)
  return pb:vdi(handle, 6, 0, 0, vararg.n >> 1)
end

-- v_pmarker_t. Output markers using table coordinates
-- Input:
--   1) integer: workstation handle
--   2) table: point array
function VDI:v_pmarker_t(handle, pxy)
  local <const> pb = self.pb_
  pb:set(k_vdi_ptsin, 0, pxy)
  return pb:vdi(handle, 7, 0, 0, #pxy >> 1)
end

-- v_pmarker_v. Output markers using vargs coordinates
-- Input:
--   1) integer: workstation handle
--   n) integer: coordinates
function VDI:v_pmarker_v(handle, ...vararg)
  local <const> pb = self.pb_
  pb:poke(k_vdi_ptsin, 0, ...)
  return pb:vdi(handle, 7, 0, 0, vararg.n >> 1)
end

-- v_gtext. Output graphical text
-- Input:
--   1) integer: workstation handle
--   2) integer: x coordinate
--   3) integer: y coordinate
--   4) string: the text to write
function VDI:v_gtext(handle, x, y, str)
  local <const> pb = self.pb_
  pb:setstr(0, str)
  return pb:call(
    k_vdi_ptsin, 2, x, y,
    k_vdi_control, 5, handle, 8, 0, #str, 1
  )
end

-- v_fillarea_t. Fill area using table coordinates
-- Input:
--   1) integer: workstation handle
--   2) table: point array
function VDI:v_fillarea_t(handle, pxy)
  local <const> pb = self.pb_
  pb:set(k_vdi_ptsin, 0, pxy)
  return pb:vdi(handle, 9, 0, 0, #pxy >> 1)
end

-- v_fillarea_v. Fill area using varg coordinates
-- Input:
--   1) integer: workstation handle
--   n) integer: coordinates
function VDI:v_fillarea_v(handle, ...vararg)
  local <const> pb = self.pb_
  pb:poke(k_vdi_ptsin, 0, ...)
  return pb:vdi(handle, 9, 0, 0, vararg.n >> 1)
end

-- v_bar_t. Draw a filled rectangle
-- Input:
--   1) integer: workstation handle
--   2) integer: x1
--   3) integer: y1
--   4) integer: x2
--   5) integer: y2
function VDI:v_bar(handle, x1, y1, x2, y2)
  return self.pb_:call(
    k_vdi_ptsin, 4, x1, y1, x2, y2,
    k_vdi_control, 5, handle, 11, 1, 0, 2)
end

-- v_arc. Draw an arc
-- Input:
--   1) integer: workstation handle
--   2) integer: x
--   3) integer: y
--   4) integer: radius
--   5) integer: start angle (0-3600)
--   6) integer: end angle (0-3600)
function VDI:v_arc(handle, x, y, radius, beginangle, endangle)
  return self.pb_:call(
    k_vdi_intin, 2, beginangle, endangle,
    k_vdi_ptsin, 8, x, y, 0, 0, 0, 0, radius, 0,
    k_vdi_control, 5, handle, 11, 2, 2, 4
  )
end

-- v_pieslice. Draw a pieslice
-- Input:
--   1) integer: workstation handle
--   2) integer: x
--   3) integer: y
--   4) integer: radius
--   5) integer: start angle (0-3600)
--   6) integer: end angle (0-3600)
function VDI:v_pieslice(handle, x, y, radius, beginangle, endangle)
  return self.pb_:call(
    k_vdi_intin, 2, beginangle, endangle,
    k_vdi_ptsin, 8, x, y, 0, 0, 0, 0, radius, 0,
    k_vdi_control, 5, handle, 11, 3, 2, 4)
end

-- v_circle. Draw a circle
-- Input:
--   1) integer: workstation handle
--   2) integer: x
--   3) integer: y
--   4) integer: radius
function VDI:v_circle(handle, x, y, radius)
  return self.pb_:call(
    k_vdi_ptsin, 6, x, y, 0, 0, radius, 0,
    k_vdi_control, 5, handle, 11, 4, 0, 3)
end

-- v_ellipse. Draw an ellipse
-- Input:
--   1) integer: workstation handle
--   2) integer: x
--   3) integer: y
--   4) integer: horizontal radius
--   5) integer: vertical radius
function VDI:v_ellipse(handle, x, y, xradius, yradius)
  return self.pb_:call(
    k_vdi_ptsin, 4, x, y, xradius, yradius,
    k_vdi_control, 5, handle, 11, 5, 0, 2)
end

-- v_ellarc. Draw an ellipse arc
-- Input:
--   1) integer: workstation handle
--   2) integer: x
--   3) integer: y
--   4) integer: horizontal radius
--   5) integer: vertical radius
--   6) integer: start angle (0-3600)
--   7) integer: end angle (0-3600)
function VDI:v_ellarc(handle, x, y, xradius, yradius, beginangle, endangle)
  return self.pb_:call(
    k_vdi_intin, 2, beginangle, endangle,
    k_vdi_ptsin, 4, x, y, xradius, yradius,
    k_vdi_control, 5, handle, 11, 6, 2, 2)
end

-- v_ellpie. Draw an elliptical pie
-- Input:
--   1) integer: workstation handle
--   2) integer: x
--   3) integer: y
--   4) integer: horizontal radius
--   5) integer: vertical radius
--   5) integer: start angle (0-3600)
--   6) integer: end angle (0-3600)
function VDI:v_ellpie(handle, x, y, xradius, yradius, beginangle, endangle)
  return self.pb_:call(
    k_vdi_intin, 2, beginangle, endangle,
    k_vdi_ptsin, 4, x, y, xradius, yradius,
    k_vdi_control, 5, handle, 11, 7, 2, 2)
end

-- v_rbox. Draw a rounded box
-- Input:
--   1) integer: workstation handle
--   2) integer: x1
--   3) integer: y1
--   4) integer: x2
--   5) integer: y2
function VDI:v_rbox(handle, x1, y1, x2, y2)
  return self.pb_:call(
    k_vdi_ptsin, 4, x1, y1, x2, y2,
    k_vdi_control, 5, handle, 11, 8, 0, 2)
end

-- v_rfbox. Draw a rounded filled box
-- Input:
--   1) integer: workstation handle
--   2) integer: x1
--   3) integer: y1
--   4) integer: x2
--   5) integer: y2
function VDI:v_rfbox(handle, x1, y1, x2, y2)
  return self.pb_:call(
    k_vdi_ptsin, 4, x1, y1, x2, y2,
    k_vdi_control, 5, handle, 11, 9, 0, 2)
end

-- v_justified. Output justified graphics text
-- Input:
--   1) integer: workstation handle
--   2) integer: x
--   3) integer: y
--   4) string: the string to output
--   5) integer: pixel length for justification
--   6) integer: 1 = justify between words, otherwise 0
--   7) integer: 1 = justify between characters, otherwise 0
--   NOTE: See VDIDefs for justify/nojustify
function VDI:v_justified(handle, x, y, str, length, wflag, cflag)
  local <const> pb = self.pb_
  pb:setstr(2, str)
  return pb:call(
    k_vdi_intin, 2, wflag, cflag,
    k_vdi_ptsin, 4, x, y, length, 0,
    k_vdi_control, 5, handle, 11, 10, 2 + #str, 2)
end

-- vst_height. Set height of current text face in pixels
-- Input:
--   1) integer: workstation handle
--   2) integer: height in pixels
-- Returns:
--   1) integer: wchar
--   2) integer: hchar
--   3) integer: wcell
--   4) integer: hcell
function VDI:vst_height(handle, height)
  return self.pb_:call(
    k_vdi_ptsin, 2, 0, height,
    k_vdi_control, 5, handle, 12, 0, 0, 1,
    k_vdi_ptsout, 4)
end

-- vst_rotation. Set rotation of graphics text
-- Input:
--   1) integer: workstation handle
--   2) integer: angle (0-3600)
-- Returns:
--   1) integer: angle set
function VDI:vst_rotation(handle, angle)
  return self.pb_:call(
    k_vdi_intin, 1, angle,
    k_vdi_control, 4, handle, 13, 0, 1,
    k_vdi_intout, 1)
end

-- vs_color. Set color representation
-- Input:
--   1) integer: workstation handle
--   2) integer: pen
--   3) integer: r (0-1000)
--   4) integer: g (0-1000)
--   5) integer: b (0-1000)
function VDI:vs_color(handle, pen, r, g, b)
  return self.pb_:call(
    k_vdi_intin, 4, pen, r, g, b,
    k_vdi_control, 4, handle, 14, 0, 4)
end

-- vsl_type. Set polyline linetype
-- Input:
--   1) integer: workstation handle
--   2) integer: type
--   NOTE: See VDIDefs for line types
-- Returns:
--   1) integer: type set
function VDI:vsl_type(handle, type)
  return self.pb_:call(
    k_vdi_intin, 1, type,
    k_vdi_control, 4, handle, 15, 0, 1,
    k_vdi_intout, 1)
end

-- vsl_width. Set polyline width
-- Input:
--   1) integer: workstation handle
--   2) integer: width
-- Returns:
--   1) integer: width set
function VDI:vsl_width(handle, width)
  return self.pb_:call(
    k_vdi_ptsin, 2, width, 0,
    k_vdi_control, 5, handle, 16, 0, 0, 1,
    k_vdi_ptsout, 1)
end

-- vsl_color. Set polyline color
-- Input:
--   1) integer: workstation handle
--   2) integer: color index
-- Returns:
--   1) integer: color index set
function VDI:vsl_color(handle, color)
  return self.pb_:call(
    k_vdi_intin, 1, color,
    k_vdi_control, 4, handle, 17, 0, 1,
    k_vdi_intout, 1)
end

-- vsm_type. Set polymarker type
-- Input:
--   1) integer: workstation handle
--   2) integer: type
--   NOTE: See VDIDefs for marker types
-- Returns:
--   1) integer: type set
function VDI:vsm_type(handle, type)
  return self.pb_:call(
    k_vdi_intin, 1, type,
    k_vdi_control, 4, handle, 18, 0, 1,
    k_vdi_intout, 1)
end

-- vsm_height. Set polymarker height
-- Input:
--   1) integer: workstation handle
--   2) integer: height
-- Returns:
--   1) integer: height set
--   2) integer: width set
function VDI:vsm_height(handle, height)
  local <const> set_w, set_h = self.pb_:call(
    k_vdi_ptsin, 2, 0, height,
    k_vdi_control, 5, handle, 19, 0, 0, 1,
    k_vdi_ptsout, 2)
  return set_h, set_w
end

-- vsm_color. Set marker color
-- Input:
--   1) integer: workstation handle
--   2) integer: color index
-- Returns:
--   1) integer: color index set
function VDI:vsm_color(handle, color)
  return self.pb_:call(
    k_vdi_intin, 1, color,
    k_vdi_control, 4, handle, 20, 0, 1,
    k_vdi_intout, 1)
end

-- vst_font. Set text face
-- Input:
--   1) integer: workstation handle
--   2) integer: fontid
-- Returns:
--   1) integer: fontid set
function VDI:vst_font(handle, fontid)
  return self.pb_:call(
    k_vdi_intin, 1, fontid,
    k_vdi_control, 4, handle, 21, 0, 1,
    k_vdi_intout, 1)
end

-- vst_color. Set text color
-- Input:
--   1) integer: workstation handle
--   2) integer: color index
-- Returns:
--   1) integer: color index set
function VDI:vst_color(handle, color)
  return self.pb_:call(
    k_vdi_intin, 1, color,
    k_vdi_control, 4, handle, 22, 0, 1,
    k_vdi_intout, 1)
end

-- vsf_interior. Set interior fill pattern
-- Input:
--   1) integer: workstation handle
--   2) integer: interior (0=hollow, 1=solid, 2=pattern, 3=hatch,  4=user)
--   NOTE: See VDIDefs for interiors
-- Returns:
--   1) integer: interior set
function VDI:vsf_interior(handle, interior)
  return self.pb_:call(
    k_vdi_intin, 1, interior,
    k_vdi_control, 4, handle, 23, 0, 1,
    k_vdi_intout, 1)
end

-- vsf_style. Set interior fill style
-- Applies to interior 2 (pattern) and interior 3 (hatch)
-- Input:
--   1) integer: workstation handle
--   2) integer: style (1-24 pattern, 1-12 hatch)
-- Returns:
--   1) integer: style set
function VDI:vsf_style(handle, style)
  return self.pb_:call(
    k_vdi_intin, 1, style,
    k_vdi_control, 4, handle, 24, 0, 1,
    k_vdi_intout, 1)
end

-- vsf_color. Set interior fill color
-- Input:
--   1) integer: workstation handle
--   2) integer: color index
-- Returns:
--   1) integer: color index set
function VDI:vsf_color(handle, color)
  return self.pb_:call(
    k_vdi_intin, 1, color,
    k_vdi_control, 4, handle, 25, 0, 1,
    k_vdi_intout, 1)
end

-- vq_color. Inquire color representation
-- Input:
--   1) integer: workstation handle
--   2) integer: color index
--   3) integer: flag (0=inquire color requested, 1=inquire color set)
--   NOTE: See VDIDefs for requested/actual
-- Returns:
--   1) integer: -1 if color index out of range, otherwise the color index
--   2) integer: r (0-1000)
--   3) integer: g (0-1000)
--   4) integer: b (0-1000)
function VDI:vq_color(handle, color, flag)
  return self.pb_:call(
    k_vdi_intin, 2, color, flag,
    k_vdi_control, 4, handle, 26, 0, 2,
    k_vdi_intout, 4)
end

-- vswr_mode. Set writing mode
-- Input:
--   1) integer: workstation handle
--   2) integer: mode
--   NOTE: See VDIDefs for writing modes
-- Returns:
--   1) integer: writing mode set 
function VDI:vswr_mode(handle, mode)
  return self.pb_:call(
    k_vdi_intin, 1, mode,
    k_vdi_control, 4, handle, 32, 0, 1,
    k_vdi_intout, 1)
end

-- vql_attributes. Query line attributes
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: line type (see vsl_type)
--   2) integer: line color (see vsl_color)
--   3) integer: writing mode (see vswr_mode)
--   4) integer: line width (see vsl_width)
function VDI:vql_attributes(handle)
  return self.pb_:call(
    k_vdi_control, 2, handle, 35,
    k_vdi_intout, 3,
    k_vdi_ptsout, 1)
end

-- vqm_attributes. Query marker attributes
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: marker type (see vsm_type)
--   2) integer: marker color (see vsm_color)
--   3) integer: writing mode (see vswr_mode)
--   4) integer: marker height (see vsm_height)
function VDI:vqm_attributes(handle)
  return self.pb_:call(
    k_vdi_control, 2, handle, 36,
    k_vdi_intout, 3,
    k_vdi_ptsout, 0x10001)
end

-- vqf_attributes. Query fill attributes
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: fill type (see vsf_interior)
--   2) integer: fill color (see vsf_color)
--   3) integer: fill style (see vsf_style)
--   4) integer: writing mode (see vswr_mode)
--   5) integer: perimeter flag (see vsf_perimeter)
function VDI:vqf_attributes(handle)
  return self.pb_:call(
    k_vdi_control, 2, handle, 37,
    k_vdi_intout, 5)
end

-- vqt_attributes. Query graphics text attributes
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: text face (see vst_font())
--   2) integer: text color (see vst_color())
--   3) integer: angle of rotation (0-3600 see vst_rotation())
--   4) integer: horizontal alignment (see vst_alignment())
--   5) integer: vertical alignment (see vst_alignment())
--   6) integer: writing mode (see vswr_mode())
--   7) integer: char width (see vst_height())
--   8) integer: char height (see vst_height())
--   9) integer: cell width (see vst_height())
--  10) integer: cell height (see vst_height())
function VDI:vqt_attributes(handle)
  return self.pb_:call(
    k_vdi_control, 2, handle, 38,
    k_vdi_intout, 6,
    k_vdi_ptsout, 4)
end

-- vst_alignment. Set graphics text alignment
-- Input:
--   1) integer: workstation handle
--   2) integer: horizontal alignment
--   3) integer: vertical alignment
--   NOTE: See VDIDefs for alignments
-- Returns
--   1) integer: horizontal alignment set
--   2) integer: vertical alignment set
function VDI:vst_alignment(handle, halign, valign)
  return self.pb_:call(
    k_vdi_intin, 2, halign, valign,
    k_vdi_control, 4, handle, 39, 0, 2,
    k_vdi_intout, 2)
end

-- vq_extnd. Extended inquire
-- Input:
--   1) integer: workstation handle
--   2) integer: info flag (0=Open values, 1=extended inquire)
-- Returns:
--   1) table: workout (array of 57 numbers)
function VDI:vq_extnd(handle, info_flag)
  local <const> pb = self.pb_
  pb:call(
    k_vdi_intin, 1, info_flag,
    k_vdi_control, 4, handle, 102, 0, 1)
  return
    table.move(pb:get(k_vdi_ptsout, 0, 12), 1, 12, 46,
      pb:get(k_vdi_intout, 0, 45))
end

-- v_contourfill. Contour fill
-- Input:
--   1) integer: workstation handle
--   2) integer: x coordinate
--   3) integer: y coordinate
--   4) integer: color
function VDI:v_contourfill(handle, x, y, color)
  return self.pb_:call(
    k_vdi_ptsin, 2, x, y,
    k_vdi_intin, 1, color,
    k_vdi_control, 5, handle, 103, 0, 1, 1)
end

-- vsf_perimeter. Set fill perimeter visiblity
-- Input:
--   1) integer: workstation handle
--   2) integer: flag (0=off, 1=on)
--   NOTE: See VDIDefs for off/on
-- Returns:
--   1) integer: visiblity set
function VDI:vsf_perimeter(handle, flag)
  return self.pb_:call(
    k_vdi_intin, 1, flag,
    k_vdi_control, 4, handle, 104, 0, 1,
    k_vdi_intout, 1)
end

-- v_get_pixel. Get pixel color value
-- Input:
--   1) integer: workstation handle
--   2) integer: x coordinate
--   3) integer: y coordinata
-- Returns:
--   1) integer: pindex
--   2) integer: vindex
function VDI:v_get_pixel(handle, x, y)
  return self.pb_:call(
    k_vdi_ptsin, 2, x, y,
    k_vdi_control, 5, handle, 105, 0, 0, 1,
    k_vdi_intout, 2)
end

-- vst_effects. Set text special effects
-- Input:
--   1) integer: workstation handle
--   2) integer: effects (1=thick, 2=light, 4=skew, 8=underline, 16=outline)
--   NOTE: See VDIDefs for effects
-- Returns:
--   1) integer: effects set
function VDI:vst_effects(handle, effects)
  return self.pb_:call(
    k_vdi_intin, 1, effects,
    k_vdi_control, 4, handle, 106, 0, 1,
    k_vdi_intout, 1)
end

-- vst_point. Set height of current text face in points
-- Input:
--   1) integer: workstation handle
--   2) integer: point height
-- Returns:
--   1) integer: points set
--   2) integer: wchar
--   3) integer: hchar
--   4) integer: wcell
--   5) integer: hcell
function VDI:vst_point(handle, point)
  return self.pb_:call(
    k_vdi_intin, 1, point,
    k_vdi_control, 4, handle, 107, 0, 1,
    k_vdi_intout, 1,
    k_vdi_ptsout, 4)
end

-- vsl_ends. Set end point style for start and finish of line
-- Input:
--   1) integer: workstation handle
--   2) integer: start the starting style
--   3) integer: finish the finishing style 
--   NOTE: See VDIDefs for styles
function VDI:vsl_ends(handle, start, finish)
  return self.pb_:call(
    k_vdi_intin, 2, start, finish,
    k_vdi_control, 4, handle, 108, 0, 2)
end

-- vro_cpyfm. Blit screen/memory from one location to another
-- Input:
--   1) integer: workstation handle
--   2) integer: the writing mode (0-15)
--   3) table: table of 8 integers for the src and dst rectangle coords
--   4) integer: src MFDB address
--   5) integer: dst MFDB address
--   NOTE: See VDIDefs for writing modes
function VDI:vro_cpyfm(handle, mode, pxy, src_mfdb_addr, dst_mfdb_addr)
  local <const> pb = self.pb_
  assert(#pxy == 8)
  pb:set(k_vdi_ptsin, 0, pxy)
  return pb:call(
    k_vdi_intin, 1, mode,
    k_vdi_control, 7, handle, 109, 0, 1, 4, src_mfdb_addr, dst_mfdb_addr)
end

-- vr_trnfm. Transform memory block between device-independent and device
-- dependent format
-- Input:
--   1) integer: workstation handle
--   2) integer: src MFDB address
--   3) integer: dst MFDB address
function VDI:vr_trnfm(handle, src_mfdb_addr, dst_mfdb_addr)
  return self.pb_:vdi(handle, 110, 0, 0, 0, src_mfdb_addr, dst_mfdb_addr)
end

-- vsc_form. Set mouse form
-- Input:
--   1) integer: workstation handle
--   2) integer: hot spot x position
--   3) integer: hot spot y position
--   4) integer: bg pen
--   5) integer: fg pen
--   6) table: table of 16 words for mask as integers
--   7) table: table of 16 words for data as integers
function VDI:vsc_form(handle, xhot, yhot, bg, fg, mask, data)
  assert(#mask == 16 and #data == 16)
  local <const> pb = self.pb_
  pb:set(k_vdi_intin, 5, mask)
  pb:set(k_vdi_intin, 21, data)
  return pb:call(
    k_vdi_intin, 5, xhot, yhot, 1, bg, fg,
    k_vdi_control, 4, handle, 111, 0, 37)
end

-- vsf_udpat. Set user defined fill pattern
-- Input:
--   1) integer: workstation handle
--   2) table: pattern data (16 * planes words, as integers)
--   3) integer: planes (number of planes, 32 for true colour)
function VDI:vsf_udpat(handle, pat_dat, planes)
  local <const> pb, num_words = self.pb_, planes << 4
  assert(num_words == #pat_dat)
  pb:set(k_vdi_intin, 0, pat_dat)
  return pb:vdi(handle, 112, 0, num_words)
end

-- vsl_udsty. Set user defined line style
-- Input:
--   1) integer: workstation handle
--   2) integer: pattern (16 bit value)
function VDI:vsl_udsty(handle, pattern)
  return self.pb_:call(
    k_vdi_intin, 1, pattern,
    k_vdi_control, 4, handle, 113, 0, 1)
end

-- vr_recfl. Draw a filled rectangle with no outline
-- Input:
--   1) integer: workstation handle
--   2) integer: x1
--   3) integer: y1
--   4) integer: x2
--   5) integer: y2
function VDI:vr_recfl(handle, x1, y1, x2, y2)
  return self.pb_:call(
    k_vdi_ptsin, 4, x1, y1, x2, y2,
    k_vdi_control, 5, handle, 114, 0, 0, 2)
end

-- vqt_extent. Inquire text extent
-- Input:
--   1) integer: workstation handle
--   2) string: the text string
-- Returns:
--   1) integer: point 1 x
--   2) integer: point 1 y
--   3) integer: point 2 x
--   4) integer: point 2 y
--   5) integer: point 3 x
--   6) integer: point 3 y
--   7) integer: point 4 x
--   8) integer: point 4 y
function VDI:vqt_extent(handle, str)
  local <const> pb = self.pb_
  pb:setstr(0, str)
  return pb:call(
    k_vdi_control, 4, handle, 116, 0, #str,
    k_vdi_ptsout, 8)
end

-- vqt_width. Inquire character cell width
-- Input:
--   1) integer: workstation handle
--   2) integer: the character code
-- Returns:
--   1) integer: character code queried or -1 on error
--   2) integer: pixel width of character cell
--   3) integer: offset of left side from left edge
--   4) integer: offset of right side from right edge
function VDI:vqt_width(handle, char)
  local <const> pb = self.pb_
  local <const> status, cellw, _, left_offset, _, right_offset =
    pb:call(
      k_vdi_intin, 1, char,
      k_vdi_control, 4, handle, 117, 0, 1,
      k_vdi_intout, 1), pb:peek(k_vdi_ptsout, 0, 5)
  return status, cellw, left_offset, right_offset
end

-- vst_load_fonts. Load fonts
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: number of new fonts available
function VDI:vst_load_fonts(handle)
  return self.pb_:call(
    k_vdi_intin, 1, 0,
    k_vdi_control, 4, handle, 119, 0, 1,
    k_vdi_intout, 1)
end

-- vst_unload_fonts. Unload fonts
-- Input:
--   1) integer: workstation handle
function VDI:vst_unload_fonts(handle)
  return self.pb_:call(
    k_vdi_intin, 1, 0,
    k_vdi_control, 4, handle, 120, 0, 1)
end

-- vrt_cpyfm. Blit single plane source to multiple-plane destination
-- Input:
--   1) integer: workstation handle
--   2) integer: the writing mode (1-4 see vswr_mode)
--   3) table: table of 8 integers for the src and dst rectangle coords
--   4) integer: src MFDB address
--   5) integer: dst MFDB address
--   6) integer: foreground pen
--   7) integer: background pen
function VDI:vrt_cpyfm(handle, mode, pxy, src_mfdb_addr, dst_mfdb_addr,
    fore_pen, back_pen)
  assert(#pxy == 8)
  local <const> pb = self.pb_
  pb:set(k_vdi_ptsin, 0, pxy)
  return pb:call(
    k_vdi_intin, 3, mode, fore_pen, back_pen,
    k_vdi_control, 7, handle, 121, 0, 3, 4, src_mfdb_addr, dst_mfdb_addr)
end

-- v_show_c: Show mouse pointer
-- Input:
--   1) integer: workstaion handle
--   2) integer: reset (zero reset to shown, non-zero use counter)
function VDI:v_show_c(handle, reset)
  return self.pb_:call(
    k_vdi_intin, 1, reset,
    k_vdi_control, 4, handle, 122, 0, 1)
end

-- v_hide_c: Hide mouse pointer
-- Input:
--   1) integer: workstation handle
function VDI:v_hide_c(handle)
  return self.pb_:vdi(handle, 123)
end

-- vq_mouse: Query mouse state
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: mouse button bits (bit 0 left, bit 1 right)
--   2) integer: mouse x position
--   3) integer: mouse y position
function VDI:vq_mouse(handle)
  return self.pb_:call(
    k_vdi_control, 2, handle, 124,
    k_vdi_intout, 1,
    k_vdi_ptsout, 2)
end

-- vq_key_s. Query keyboard state
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: key state (bit 0 rsh, 1 lsh, 2 ctr, 3 alt)
function VDI:vq_key_s(handle)
  return self.pb_:call(
    k_vdi_control, 2, handle, 128,
    k_vdi_intout, 1)
end

-- vqt_fontinfo. Query current text font info
-- Input:
--   1) integer: workstation handle
-- Returns:
--   1) integer: first character
--   2) integer: last character
--   3) table: five integers for distance values
--   4) integer: max cell width
--   5) table: three integers for effects values
function VDI:vqt_fontinfo(handle)
  local <const> pb = self.pb_
  local <const> first, last =
    pb:call(
      k_vdi_control, 2, handle, 131,
      k_vdi_intout, 2)
  local <const> pts = pb:get(k_vdi_ptsout, 0, 10)
  local <const> width = pts[1]
  local <const> dist = { pts[2], pts[4], pts[6], pts[8], pts[10] }
  local <const> effs = { pts[3], pts[5], pts[7] }
  return first, last, dist, width, effs
end

-- vs_clip.
-- Input:
--   1) integer: workstation handle
--   2) integer: clip_flag (0 = disable, 1 = enable)
--   3) integer: x1
--   4) integer: y1
--   5) integer: x2
--   6) integer: y2
function VDI:vs_clip(handle, clip_flag, x1, y1, x2, y2)
  return self.pb_:call(
    k_vdi_intin, 1, clip_flag,
    k_vdi_ptsin, 4, x1, y1, x2, y2,
    k_vdi_control, 5, handle, 129, 0, 1, 2)
end

-- vqt_name. Inquire font id and name
-- Input:
--   1) integer: workstation handle
--   2) integer: font number
-- Returns:
--   1) integer: font id
--   2) string: font name
function VDI:vqt_name(handle, number)
  local <const> pb = self.pb_
  return pb:call(
    k_vdi_intin, 1, number,
    k_vdi_control, 4, handle, 130, 0, 1,
    k_vdi_intout, 1), pb:getstr(1, 32)
end

-- v_opnvwk. Open virtual workstation.
-- Inputs:
--   1) integer: handle of the physical workstation (e.g. from graf_handle)
--   2) table: optional workin (array of 11 numbers) otherwise default
--      {
--        device id,
--        line drawing pattern [vsl_type()],
--        Line pen number [vsl_color()],
--        Marker type [vsm_type()],
--        Marker pen number [vsm_color()],
--        Text font [vst_font()],
--        Text pen number [vst_color()],
--        Fill pattern type [vsf_interior()],
--        Fill pattern index [vsf_style()],
--        Fill pen number [vsf_color()],
--        0 = NDC otherwise 2 = RC
--      }
-- Result:
--   1) integer: VDI virtual workstation handle
--   2) table: workout (array of 57 numbers)
function VDI:v_opnvwk(handle, workin)
  workin = workin or {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 }
  assert(#workin == 11)
  local <const> pb = self.pb_
  pb:set(k_vdi_intin, 0, workin)
  return pb:call(
    k_vdi_control, 4, handle, 100, 0, 11,
    k_vdi_control, 0x60001),
      table.move(pb:get(k_vdi_ptsout, 0, 12), 1, 12, 46,
       pb:get(k_vdi_intout, 0, 45))
end

-- v_clsvwk
-- Inputs:
--   1) integer: virtual workstation handle to close
-- Result:
---  None
function VDI:v_clsvwk(handle)
  return self.pb_:vdi(handle, 101)
end

return VDI
