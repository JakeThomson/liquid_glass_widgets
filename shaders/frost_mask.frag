// Copyright 2026, Sebastian Degenaar for pixel-innovations.com (liquid_glass_widgets)
//
// SPDX-License-Identifier: MIT
//
// First stage of a frost pass that is composited with a blend mode: cuts the
// backdrop to the geometry matte before it is blurred, so the blur carries
// the matte in its alpha and frost_unmask.frag can restore a hard edge after
// it. A BackdropFilterLayer blended with lighten or darken is composited
// over its whole rect regardless of the clip path around it (Impeller,
// 3.41), which drew the cloud as a faint box around the shape; cut this way
// the blend outside the shape is a no-op.
//
// Runs directly on the backdrop snapshot, so the UV is the fragment position
// over uSize and the matte is addressed as uGeometryTexture is in
// liquid_glass_render.frag. (A stage after the blur sees fragment positions
// in the blur's padded texture instead, which is why the matte is not read
// there.)

#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>
#include "gles_compat.glsl"

uniform vec2 uSize;            // 0,1  bound-texture size, device px
uniform vec2 uGeometryOffset;  // 2,3  matte top-left, pass-relative device px
uniform vec2 uGeometrySize;    // 4,5  matte size, device px
uniform float uErode;          // 6    the frost's dilate radius, device px; < 0 erode
uniform sampler2D uTexture;
uniform sampler2D uGeometryTexture;

out vec4 fragColor;

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  vec2 geometryUV = (fragCoord - uGeometryOffset) / uGeometrySize;
#ifdef LGR_GLES_FLIP_SAMPLE_Y
  uv.y = 1.0 - uv.y;
  geometryUV.y = 1.0 - geometryUV.y;
#endif
  // Shrunk by the dilate that follows, or grown by the erode
  // (LiquidGlassSettings.frostDilate), so the edge frost_unmask.frag
  // recovers is the shape's own.
  vec2 e = abs(uErode) / uGeometrySize;
  float coverage = 0.0;
  if (all(greaterThanEqual(geometryUV, vec2(0.0))) &&
      all(lessThanEqual(geometryUV, vec2(1.0)))) {
    float c0 = texture(uGeometryTexture, geometryUV).a;
    float c1 = texture(uGeometryTexture, geometryUV + vec2(e.x, 0.0)).a;
    float c2 = texture(uGeometryTexture, geometryUV - vec2(e.x, 0.0)).a;
    float c3 = texture(uGeometryTexture, geometryUV + vec2(0.0, e.y)).a;
    float c4 = texture(uGeometryTexture, geometryUV - vec2(0.0, e.y)).a;
    coverage = uErode >= 0.0
        ? min(c0, min(min(c1, c2), min(c3, c4)))
        : max(c0, max(max(c1, c2), max(c3, c4)));
  }
  // Premultiplied in, premultiplied out.
  fragColor = texture(uTexture, uv) * coverage;
}
