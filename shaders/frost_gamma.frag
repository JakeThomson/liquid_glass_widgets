// Copyright 2026, Sebastian Degenaar for pixel-innovations.com (liquid_glass_widgets)
//
// SPDX-License-Identifier: MIT
//
// One side of the frost's tone curve: raises the backdrop to uExponent so the
// Gaussian blur composed after it averages in that space, and the same
// program with the reciprocal exponent brings the result back. The native
// frost is not a plain mean of the content beneath it: the light material's
// cloud over black-on-white detail is brighter than the mean, the dark
// material's over white-on-black darker, which a blur in a curved space
// reproduces while leaving flat colour untouched. See
// LiquidGlassSettings.frostGamma.
//
// The bound texture is the enclosing compositor pass, so the UV is the
// fragment position over uSize, as in liquid_glass_render.frag.

#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>
#include "gles_compat.glsl"

uniform vec2 uSize;          // 0,1  bound-texture size, device px
uniform float uExponent;     // 2    curve exponent
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
#ifdef LGR_GLES_FLIP_SAMPLE_Y
  uv.y = 1.0 - uv.y;
#endif
  vec4 c = texture(uTexture, uv);
  // Premultiplied in, premultiplied out: un-premultiply around the curve.
  float a = max(c.a, 1e-4);
  vec3 curved = pow(max(c.rgb / a, 0.0), vec3(uExponent));
  fragColor = vec4(curved * c.a, c.a);
}
