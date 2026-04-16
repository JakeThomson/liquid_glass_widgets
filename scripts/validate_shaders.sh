#!/usr/bin/env bash
# validate_shaders.sh
#
# Validates liquid_glass_widgets GLSL shaders for Windows/SkSL compatibility
# using glslangValidator (the same compiler core used by Flutter on Windows).
#
# Usage:
#   bash scripts/validate_shaders.sh
#
# Install (once):
#   brew install glslang
#
# What this catches:
#   - Dynamic array indices  ("index expression must be constant")
#   - Non-constant loop bounds
#   - Forbidden builtins (min(int,int), etc.)
#   - General GLSL syntax/type errors
#
# What this does NOT catch:
#   - Impeller-specific builtins (FlutterFragCoord, layout locations) — these
#     will warn but not error. They are valid at Impeller runtime.
#   - Semantic / visual bugs — only visual testing catches those.

set -euo pipefail

SHADER_DIR="$(cd "$(dirname "$0")/.." && pwd)/shaders"
VALIDATOR="glslangValidator"
PASS=0
FAIL=0
WARN=0

# Check glslangValidator is available.
if ! command -v "$VALIDATOR" &>/dev/null; then
  echo "❌  glslangValidator not found."
  echo "    Install with: brew install glslang"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Liquid Glass — Windows/SkSL Shader Validation"
echo "  Shader dir: $SHADER_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# We only validate .frag files (entry-point shaders).
# .glsl include files are pulled in by the including shader, so validating the
# .frag automatically validates included .glsl too.
for frag in "$SHADER_DIR"/*.frag; do
  name="$(basename "$frag")"

  # Run validator. Redirect stderr to stdout so we can capture all output.
  # --target-env vulkan1.0 selects the SPIR-V target (same as Windows Flutter).
  # -l suppresses the "Linked" success line that clutters output.
  output=$("$VALIDATOR" \
    --target-env vulkan1.0 \
    -S frag \
    -I "$SHADER_DIR" \
    "$frag" 2>&1) || true

  # Detect hard errors vs Impeller-extension warnings.
  has_error=false
  has_impeller_warn=false
  clean_output=""

  while IFS= read -r line; do
    # Impeller-specific extensions that glslang warns about but are valid at runtime.
    if [[ "$line" == *"FlutterFragCoord"* ]] || \
       [[ "$line" == *"GL_GOOGLE_include_directive"* ]] || \
       [[ "$line" == *"layout"*"location"* && "$line" == *"warning"* ]]; then
      has_impeller_warn=true
      continue  # Suppress known Impeller warnings from output
    fi

    # Real errors the Windows compiler will also reject.
    if [[ "$line" == *"error"* ]]; then
      has_error=true
      clean_output+="  ❌  $line"$'\n'
    elif [[ "$line" == *"warning"* ]]; then
      clean_output+="  ⚠️   $line"$'\n'
    fi
  done <<< "$output"

  if $has_error; then
    echo "FAIL  $name"
    echo "$clean_output"
    FAIL=$((FAIL + 1))
  elif [[ -n "$clean_output" ]]; then
    echo "WARN  $name"
    echo "$clean_output"
    WARN=$((WARN + 1))
  else
    echo "PASS  $name"
    PASS=$((PASS + 1))
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: ${PASS} passed  ${WARN} warnings  ${FAIL} failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "  ⛔  Windows build will fail. Fix errors above before releasing."
  echo "  See: knowledge/liquid_glass_shader_windows/artifacts/compatibility_rules.md"
  exit 1
else
  echo ""
  echo "  ✅  All shaders pass Windows/SkSL validation."
  exit 0
fi
