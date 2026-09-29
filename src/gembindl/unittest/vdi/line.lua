local AES = require("gembindl.aes")
local VDI = require("gembindl.vdi")
local vdidefs = require("gembindl.utility.defs.vdidefs")

-- Create parameter block and aes/vdi tables
local pb = gempb.create_pb()
local aes = AES:new(pb)
local vdi = VDI:new(pb)

-- Check that gdos is present
assert(gempb.utility.vq_gdos() ~= 0)

-- appl_init
local ap_id = aes:appl_init()
-- Open virtual workstation for screen
local gh, wcel, hcel, wbox, hbox = aes:graf_handle()
gemdos.Cconws("hcel: " .. hcel .. "\r\n")

local svwk_h, workout = vdi:v_opnvwk(gh,
  { gempb.utility.scr_devid(), 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 })
assert(#workout == 57)

-- Set clip
local x_max, y_max = workout[1], workout[2]
vdi:vs_clip(svwk_h, 1, 0, 0, x_max, y_max)

-- Cursor home
vdi:v_curhome(svwk_h)

-- Clear screen
vdi:v_clrwk(svwk_h)

-- Array of line types
local line_types = {
  vdidefs.slty_solid,
  vdidefs.slty_ldashed,
  vdidefs.slty_dotted,
  vdidefs.slty_dashdot,
  vdidefs.slty_dash,
  vdidefs.slty_dashdotdot,
  vdidefs.slty_userline
}

-- Array of line end types
local line_end_types = {
  vdidefs.slen_square,
  vdidefs.slen_arrowed,
  vdidefs.slen_round
}

local w = x_max // 18 -- width unit
local h = y_max // 10 -- height unit

local h2 = h << 1 -- twice height unit
local w2 = w << 1 -- twice width unit

local line_width_max = 7 -- maximum line width
local line_width_max2 = line_width_max << 1 -- twice maximum line width
local halfh = h >> 1 -- half height unit

-- The triangle shape
local shape_tbl = { -w, h, w, h, 0, -h, -w, h }
local pos_tbl = {}

-- Set user line style
vdi:vsl_udsty(svwk_h, 0xA)
-- For colour 1 then 0
for color = 1, 0, -1 do
  -- Set the line colour
  vdi:vsl_color(svwk_h, color)
  local y_centre = h2
  local x_centre
  -- For odd line widths between 1 and line_width_max
  for width = 1, line_width_max, 2 do
    -- Set the line width
    vdi:vsl_width(svwk_h, width)
    -- Compute starting x_centre
    x_centre = w + line_width_max
    -- For each line type a triangle will be drawn
    for ltype in ipairs(line_types) do
      -- Set the line type
      vdi:vsl_type(svwk_h, ltype)
      -- Work out positions of triangle vertices
      for k,v in ipairs(shape_tbl) do
        if k & 1 == 1 then
          pos_tbl[k] = x_centre + v
        else
          pos_tbl[k] = y_centre + v
        end
      end

      -- Query the line attributes and check the values
      local qlinetype, qlinecolor, qwritingmode, qwidth =
        vdi:vql_attributes(svwk_h)
      assert(qlinetype == ltype)
      assert(qlinecolor == color)
      assert(qwritingmode == vdidefs.swmo_replace)
      assert(qwidth == width)

      -- Draw poly line using positions from table
      vdi:v_pline_t(svwk_h, pos_tbl)
      -- Draw poly line using positions from stack
      vdi:v_pline_v(svwk_h,
        pos_tbl[1], pos_tbl[2] + h, pos_tbl[3], pos_tbl[4] + h,
        pos_tbl[5], pos_tbl[6] + h, pos_tbl[7], pos_tbl[8] + h)
      -- Increase the x_centre towards the right of the screen
      x_centre = x_centre + w2
    end

    -- Set the line to solid
    vdi:vsl_type(svwk_h, vdidefs.slty_solid)
    -- With each line end type draw a line
    for k,v in ipairs(line_end_types) do
      vdi:vsl_ends(svwk_h, v, v)
      vdi:v_pline_v(svwk_h,
        x_centre, pos_tbl[2] + halfh - width,
        x_centre, pos_tbl[6] + halfh + width)
      x_centre = x_centre + line_width_max2
    end

    -- Increase the y_centre towards the bottom of the screen
    y_centre = y_centre + h2
  end
end

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
