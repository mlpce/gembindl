local <const> VDIDefs = {
  -- vswr_mode
  swmo_replace = 1,
  swmo_trans = 2,
  swmo_xor = 3,
  swmo_erase = 4,
  -- vro_cpyfm
  rocp_all_white = 0,
  rocp_s_and_d = 1,
  rocp_s_and_notd = 2,
  rocp_s_only = 3,
  rocp_nots_and_d = 4,
  rocp_d_only = 5,
  rocp_s_xor_d = 6,
  rocp_s_or_d = 7,
  rocp_not_sord = 8,
  rocp_not_sxord = 9,
  rocp_d_invert = 10,
  rocp_not_d = 10,
  rocp_s_or_notd = 11,
  rocp_not_s = 12,
  rocp_nots_or_d = 13,
  rocp_not_sandd = 14,
  rocp_all_black = 15,
  -- v_bit_image
  biim_left = 0,
  biim_center = 1,
  biim_right = 2,
  biim_top = 0,
  biim_bottom = 2,
  -- v_justified
  just_nojustify = 0,
  just_justify = 1,
  -- vq_color
  qcol_requested = 0,
  qcol_actual = 1,
  -- vsf_interior
  sfin_hollow = 0,
  sfin_solid = 1,
  sfin_pattern = 2,
  sfin_hatch = 3,
  sfin_user = 4,
  -- vsf_perimeter
  sfpe_off = 0,
  sfpe_on = 1,
  -- vsl_ends
  slen_square = 0,
  slen_arrowed = 1,
  slen_round = 2,
  -- vsl_type
  slty_solid = 1,
  slty_ldashed = 2,
  slty_dotted = 3,
  slty_dashdot = 4,
  slty_dash = 5,
  slty_dashdotdot = 6,
  slty_userline = 7,
  -- vsm_type
  smty_dot = 1,
  smty_plus = 2,
  smty_asterisk = 3,
  smty_box = 4,
  smty_cross = 5,
  smty_diamond = 6,
  -- vst_alignment
  stal_left = 0,
  stal_center = 1,
  stal_right = 2,
  stal_base = 0,
  stal_half = 1,
  stal_ascent = 2,
  stal_bottom = 3,
  stal_descent = 4,
  stal_top = 5,
  -- vst_effects
  stef_normal = 0,
  stef_thickened = 1,
  stef_light = 2,
  stef_skewed = 4,
  stef_underlined = 8,
  stef_outlined = 16,
  -- v_updwk SLM804 driver result codes
  updw_slm_ok = 0,
  updw_slm_error = 2,
  updw_slm_notoner = 3,
  updw_slm_nopaper = 5,
  -- vs_clip flags
  scli_off = 0,
  scli_on = 1
} 

return VDIDefs
