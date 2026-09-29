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

-- Array of fill interior types
local fill_interior_types = {
  vdidefs.sfin_hollow,
  vdidefs.sfin_solid,
  vdidefs.sfin_pattern,
  vdidefs.sfin_hatch,
  vdidefs.sfin_user
}

-- Set user fill pattern
vdi:vsf_udpat(svwk_h, {
    0xffff, 0x8001, 0x8001, 0x8001,
    0x8001, 0x8001, 0x8001, 0x8001,
    0x8001, 0x8001, 0x8001, 0x8001,
    0x8001, 0x8001, 0x8001, 0xffff
  }, 1)

local w = x_max // 30
local h = y_max // 20
local x
local y

-- Render a grid of each fill interior with perimeter on then off
for perimeter = vdidefs.sfpe_on, vdidefs.sfpe_off, -1 do
  x = w << 1
  y = h << 1
  vdi:vsf_perimeter(svwk_h, perimeter)
  for k,v in ipairs(fill_interior_types) do
    -- Set the interior type
    local set_interior = vdi:vsf_interior(svwk_h, v)
    assert(set_interior == v)

    if v == vdidefs.sfin_pattern then
      -- Draw 24 styles of pattern interior across the screen
      local xx = x
      local yy = y
      for style = 1,24 do
        local other_xx = xx + w
        local other_yy = yy + h
        assert(vdi:vsf_style(svwk_h, style) == style)
        vdi:v_bar(svwk_h, xx, yy, other_xx, other_yy)
        xx = xx + w
      end
    elseif v == vdidefs.sfin_hatch then
      -- Draw 12 styles of hatch interior across the screen
      local xx = x
      local yy = y
      for style = 1,12 do
        local other_xx = xx + w
        local other_yy = yy + h
        assert(vdi:vsf_style(svwk_h, style) == style)
        vdi:v_bar(svwk_h, xx, yy, other_xx, other_yy)
        xx = xx + w
      end
    else
      -- Draw the interior as a single rectangle
      vdi:v_bar(svwk_h, x, y, x + w, y + h)
    end

    -- Move down to next grid line
    y = y + h + 1
  end
end

-- Test v_fillarea_v and v_fillarea_t using pattern interior
x = w << 1
vdi:vsf_interior(svwk_h, vdidefs.sfin_pattern)
assert(vdi:vsf_style(svwk_h, 4) == 4)

-- With color 1 then 0
for color = 1,0,-1 do
  vdi:vsf_color(svwk_h, color)
  -- With perimeter on then off
  for perimeter = vdidefs.sfpe_on, vdidefs.sfpe_off, -1 do
    -- Draw a pair of triangles using v_fillarea_v and v_fillarea_t
    vdi:vsf_perimeter(svwk_h, perimeter)
    local qinterior, qcolor, qstyle, qwrmode, qperim =
      vdi:vqf_attributes(svwk_h)
    assert(qinterior == vdidefs.sfin_pattern)
    assert(qcolor == color)
    assert(qstyle == 4)
    assert(qwrmode == vdidefs.swmo_replace)
    assert(qperim == perimeter)

    local other_xx = x + w
    local other_yy = y + h
    vdi:v_fillarea_v(svwk_h, x, other_yy, other_xx, y, other_xx, other_yy)
    x = x + w
    other_xx = x + w
    other_yy = y + h
    vdi:v_fillarea_t(svwk_h, { x, y, other_xx, other_yy, x, other_yy })
    x = x + w
  end
  -- The color 0 triangles will be drawn over a filled bar
  vdi:v_bar(svwk_h, x, y, x + 4*w, y + h)
end

-- Use vr_recfl to draw a filled rectangle with no outline even though
-- perimeter is turned on.
vdi:vsf_perimeter(svwk_h, vdidefs.sfpe_on)
vdi:vsf_color(svwk_h, 1)
vdi:vr_recfl(svwk_h, x, y, x + w, y + h)
x = x + w

-- Draw a hollow rectangle using v_fillarea_v
vdi:vsf_interior(svwk_h, vdidefs.sfin_hollow)
local other_xx = x + w
local other_yy = y + h
vdi:v_fillarea_v(svwk_h, x, other_yy, other_xx, y,
  other_xx + w, other_yy, x, other_yy)
x = x + w

-- Now fill the hollow rectangle using contour fill
vdi:vsf_interior(svwk_h, vdidefs.sfin_solid)
vdi:v_contourfill(svwk_h, x, y + h // 2, 1)

-- Close virtual workstation for screen
vdi:v_clsvwk(svwk_h)

-- appl_exit
aes:appl_exit()
