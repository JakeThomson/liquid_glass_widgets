// Copyright 2026, Sebastian Degenaar for pixel-innovations.com (liquid_glass_widgets)
//
// SPDX-License-Identifier: MIT
//
// Last stage of a frost pass that is composited with a blend mode, after the
// blur of what frost_mask.frag cut to the matte: the alpha is the blurred
// matte, 0.5 exactly at the shape edge, so the colour is normalised back to
// what the content inside the shape averages to and the edge is made hard
// again. Outside the shape the pass is then transparent and its blend a
// no-op.
//
// The bound texture is the blur's output, so the UV is the fragment position
// over uSize.

#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>
#include "gles_compat.glsl"

uniform vec2 uSize;          // 0,1  bound-texture size, device px
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
#ifdef LGR_GLES_FLIP_SAMPLE_Y
  uv.y = 1.0 - uv.y;
#endif
  vec4 c = texture(uTexture, uv);
  float inside = step(0.5, c.a);
  fragColor = vec4(c.rgb / max(c.a, 1e-4), 1.0) * inside;
}
