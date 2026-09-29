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

-- Test each marker type
local marker_types = {
  vdidefs.smty_dot,
  vdidefs.smty_plus,
  vdidefs.smty_asterisk,
  vdidefs.smty_box,
  vdidefs.smty_cross,
  vdidefs.smty_diamond
}

-- table for position coordinates
local pxy = { }
-- for color 1 then 0
for color = 1,0,-1 do
  -- set marker colour and line colour
  vdi:vsm_color(svwk_h, color)
  vdi:vsl_color(svwk_h, color)
  -- For marker heights between 11 and 88 step size 11
  for marker_height = 11, 88, 11 do
    -- Set the marker height
    local set_height, set_width = vdi:vsm_height(svwk_h, marker_height)
    assert(set_height == marker_height)

    -- Draw markers using coordinates in a table
    local y_pos = 16
    local y_inc = y_max // 14
    for k,v in ipairs(marker_types) do
      -- Set the marker type
      vdi:vsm_type(svwk_h, v)

      -- Query the maker attributes and check them
      local qtype, qcol, qwrmode, qheight = vdi:vqm_attributes(svwk_h)
      assert(qtype == v - 1) -- NOTE(mlpce): Note the -1.
      assert(qcol == color)
      assert(qwrmode == vdidefs.swmo_replace)
      assert(qheight == marker_height)

      -- Set table position coordinates
      pxy[1] = x_max // 3
      pxy[2] = y_pos
      pxy[3] = x_max // 2
      pxy[4] = y_pos
      pxy[5] = x_max * 2 // 3
      pxy[6] = y_pos
      -- Draw the markers using the table position coordinates
      vdi:v_pmarker_t(svwk_h, pxy)

      -- Increase the y position towards the bottom of the screen
      y_pos = y_pos + y_inc
    end

    -- Draw markers using coordinates from stack values
    for k,v in ipairs(marker_types) do
      vdi:vsm_type(svwk_h, v)
      vdi:v_pmarker_v(svwk_h,
        x_max // 3, y_pos, x_max // 2, y_pos, x_max * 2 // 3, y_pos)
      y_pos = y_pos + y_inc
    end

    -- Draw three lines at the bottom of the screen with width of the markers
    local width_line_ypos = y_max - 2
    local quarter_width = set_width // 4
    vdi:v_pline_v(svwk_h,
      x_max // 3 - quarter_width, width_line_ypos,
        x_max // 3 + quarter_width, width_line_ypos)
    vdi:v_pline_v(svwk_h,
      x_max // 2 - quarter_width, width_line_ypos,
        x_max // 2 + quarter_width, width_line_ypos)
    vdi:v_pline_v(svwk_h,
      x_max * 2 // 3 - quarter_width, width_line_ypos,
        x_max * 2 // 3 + quarter_width, width_line_ypos)
  end
end

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
