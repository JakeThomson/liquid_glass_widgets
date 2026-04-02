// Copyright 2025, Tim Lehmann for whynotmake.it
//
// Final rendering pass for liquid glass with pre-computed geometry
// This shader reads displacement data from a pre-computed texture and applies
// the liquid glass effect efficiently

#version 460 core
precision highp float; // mediump causes colour banding (10-bit mantissa on mobile)

#define DEBUG_GEOMETRY 0

#include <flutter/runtime_effect.glsl>
#include "displacement_encoding.glsl"
#include "render.glsl"

// Slot 0-1:  uSize           — physical-pixel size of the backdrop capture
// Slots 2-3: uGeometryOffset — top-left of geometry matte in physical pixels
// Slots 4-5: uGeometrySize   — size of geometry matte in physical pixels
// Slots 6-9: uGlassColor
// Slots 10-12: uOpticalProps (refractiveIndex, chromaticAberration, thickness)
// Slots 13-15: uLightConfig  (lightIntensity, ambientStrength, saturation)
// Slots 16-17: uLightDirection
// Slot 18: uBlurSigma
uniform vec2 uSize;          // physical-pixel size of the backdrop capture
uniform vec2 uGeometryOffset;
uniform vec2 uGeometrySize;

uniform vec4 uGlassColor;
uniform vec3 uOpticalProps;
uniform vec3 uLightConfig;
uniform vec2 uLightDirection;

float uRefractiveIndex = uOpticalProps.x;
float uChromaticAberration = uOpticalProps.y;
float uThickness = uOpticalProps.z;
float uLightIntensity = uLightConfig.x;
float uAmbientStrength = uLightConfig.y;
float uSaturation = uLightConfig.z;

uniform sampler2D uBackgroundTexture;
uniform sampler2D uGeometryTexture;

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // Use the explicit uSize uniform for UV derivation. textureSize() was tried
    // but can return (0,0) on the first frame before GPU texture upload completes
    // in Impeller's BackdropFilterLayer context, causing 1/0 = Infinity UVs and
    // an invisible first-frame render. uSize (physical pixels of the backdrop
    // capture, equal to desiredMatteSize * devicePixelRatio) is always valid.
    vec2 invTexSize = 1.0 / uSize;
    vec2 screenUV = fragCoord * invTexSize;

    #ifdef IMPELLER_TARGET_OPENGLES
        screenUV.y = 1.0 - screenUV.y;
    #endif

    vec2 geometryUV = (fragCoord - uGeometryOffset) / uGeometrySize;
    #ifdef IMPELLER_TARGET_OPENGLES
        geometryUV.y = 1.0 - geometryUV.y;
    #endif

    // Any fragment whose geometryUV falls outside [0,1] is outside the glass
    // pill boundary entirely.  Without this early-out the sampler clamps to the
    // edge pixel (UV.x=0 → left boundary pixel, alpha ≈ 0.5 from SDF AA), which
    // renders a faint glass stripe in the _clipExpansion zone (20 px on each
    // side).  That stripe is visible at the pill's vertical midpoint as a short
    // line protruding left and right from the pill edges.
    if (any(lessThan(geometryUV, vec2(0.0))) || any(greaterThan(geometryUV, vec2(1.0)))) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 geometryData = texture(uGeometryTexture, geometryUV);

    #if DEBUG_GEOMETRY
        fragColor = geometryData;
        return;
    #endif

    if (geometryData.a < 0.01) {
        fragColor = vec4(0);
        return;
    }

    float maxDisplacement = uThickness * 10.0;
    vec2 displacement = decodeDisplacement(geometryData, maxDisplacement);

    // Blur is applied by the BackdropFilterLayer (ImageFilter.blur) in the Dart
    // layer BEFORE this shader runs.  The background texture already contains the
    // frosted/blurred content — just sample it directly here for refraction.
    vec4 refractColor;
    if (uChromaticAberration < 0.01) {
        vec2 refractedUV = screenUV + displacement * invTexSize;
        refractColor = texture(uBackgroundTexture, refractedUV);
    } else {
        float dispersionStrength = uChromaticAberration * 0.5;
        vec2 redOffset = displacement * (1.0 + dispersionStrength);
        vec2 blueOffset = displacement * (1.0 - dispersionStrength);

        vec2 redUV = screenUV + redOffset * invTexSize;
        vec2 greenUV = screenUV + displacement * invTexSize;
        vec2 blueUV = screenUV + blueOffset * invTexSize;

        float red   = texture(uBackgroundTexture, redUV).r;
        vec4 greenSample = texture(uBackgroundTexture, greenUV);
        float blue  = texture(uBackgroundTexture, blueUV).b;

        refractColor = vec4(red, greenSample.g, blue, greenSample.a);
    }

    vec4 finalColor = applyGlassColor(refractColor, uGlassColor);
    finalColor.rgb = applySaturation(finalColor.rgb, uSaturation);

    // Compute edge lighting
    float normalizedHeight = geometryData.b;

    float thicknessScale = clamp(40.0 / max(uThickness, 1.0), 1.0, 4.0);
    float edgeThreshold = mix(0.8, 0.5, 1.0 / thicknessScale);
    float edgeFactor = 1.0 - smoothstep(0.0, edgeThreshold, normalizedHeight);

    if (edgeFactor > 0.01) {
        vec2 normalXY = normalize(displacement);

        float mainLight = max(0.0, dot(normalXY, uLightDirection));
        float oppositeLight = max(0.0, dot(normalXY, -uLightDirection));

        float totalInfluence = mainLight + oppositeLight * 0.8;

        float directional = pow(totalInfluence, 1.5) * uLightIntensity * 3.0;
        float ambient = uAmbientStrength * 0.5;

        // Soft-clamp brightness with x/(1+x) to prevent mix() extrapolating
        // beyond highlightColor. The original * 3.0 drove the corner brightness
        // to ~9.6 (corner normal perfectly aligns with the 135° light angle),
        // causing a blinding "leading dot". The soft clamp maps all values to
        // [0, 1) so corner and edges converge instead of both blowing out.
        float brightnessRaw = (directional + ambient) * edgeFactor * thicknessScale * 0.8;
        float brightness = brightnessRaw / (1.0 + brightnessRaw);

        vec3 highlightColor = getHighlightColor(refractColor.rgb, 1.0);
        finalColor.rgb = mix(finalColor.rgb, highlightColor, brightness);
    }

    float alpha = geometryData.a;
    fragColor = vec4(finalColor.rgb * alpha, alpha);
}
