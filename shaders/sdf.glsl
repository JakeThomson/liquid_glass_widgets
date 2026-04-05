// Shape array uniforms - 6 floats per shape (type, centerX, centerY, sizeW, sizeH, cornerRadius)
// Reduced from 64 to 16 shapes to fit Impeller's uniform buffer limit (16 * 6 = 96 floats vs 384)
#define MAX_SHAPES 16

float sdfRRect( in vec2 p, in vec2 b, in float r ) {
    float shortest = min(b.x, b.y);
    r = min(r, shortest);
    vec2 q = abs(p)-b+r;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r;
}

float sdfRect(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// NOTE: sdfSquircle was removed — it was byte-for-byte identical to sdfRRect.
// A true Euclidean superellipse SDF requires Newton-Raphson root finding which
// is too expensive for a real-time mobile shader hot path. Both shape types
// (squircle/superellipse and rounded rectangle) now route to sdfRRect.

float sdfEllipse(vec2 p, vec2 r) {
    r = max(r, 1e-4);
    
    vec2 invR = 1.0 / r;
    vec2 invR2 = invR * invR;
    
    vec2 pInvR = p * invR;
    float k1 = length(pInvR);
    
    vec2 pInvR2 = p * invR2;
    float k2 = length(pInvR2);
    
    return (k1 * (k1 - 1.0)) / max(k2, 1e-4);
}

// Branchless smooth-union — replaces the `if (k <= 0)` early-return that
// caused warp divergence when blend=0 (every pixel took a different path).
// When k=0: e=0, so e²/max(k,ε)=0, result = min(d1,d2). Mathematically
// identical to the branching version but all threads execute the same path.
float smoothUnion(float d1, float d2, float k) {
    float e = max(k - abs(d1 - d2), 0.0);
    return min(d1, d2) - e * e * 0.25 / max(k, 1e-5);
}

// Use else-if so the compiler can skip remaining checks once a branch is
// taken — on predicated-execution GPUs this avoids evaluating all three
// SDF functions for every pixel. Return 0.0 (inside shape) for unknown
// types so a misconfigured shape fails visibly rather than silently.
float getShapeSDF(float type, vec2 p, vec2 center, vec2 size, float r) {
    if (type == 1.0) {        // squircle / superellipse → uses same SDF as rounded rect
        return sdfRRect(p - center, size / 2.0, r);
    } else if (type == 2.0) { // ellipse / circle
        return sdfEllipse(p - center, size / 2.0);
    } else if (type == 3.0) { // rounded rectangle
        return sdfRRect(p - center, size / 2.0, r);
    }
    return 0.0; // unknown type — treat as fully inside (visible failure mode)
}

float getShapeSDFFromArray(int index, vec2 p, float shapeData[MAX_SHAPES * 6]) {
    int baseIndex = index * 6;
    float type = shapeData[baseIndex];
    vec2 center = vec2(shapeData[baseIndex + 1], shapeData[baseIndex + 2]);
    vec2 size = vec2(shapeData[baseIndex + 3], shapeData[baseIndex + 4]);
    float cornerRadius = shapeData[baseIndex + 5];
    
    return getShapeSDF(type, p, center, size, cornerRadius);
}

float sceneSDF(vec2 p, int numShapes, float shapeData[MAX_SHAPES * 6], float blend) {
    if (numShapes == 0) {
        return 1e9;
    }
    
    float result = getShapeSDFFromArray(0, p, shapeData);
    
    // Optimized: unroll for common cases (1-4 shapes), use loop for 5+ shapes
    if (numShapes <= 4) {
        // Fully unrolled for 1-4 shapes (covers 90%+ of use cases)
        if (numShapes >= 2) {
            float shapeSDF = getShapeSDFFromArray(1, p, shapeData);
            result = smoothUnion(result, shapeSDF, blend);
        }
        if (numShapes >= 3) {
            float shapeSDF = getShapeSDFFromArray(2, p, shapeData);
            result = smoothUnion(result, shapeSDF, blend);
        }
        if (numShapes >= 4) {
            float shapeSDF = getShapeSDFFromArray(3, p, shapeData);
            result = smoothUnion(result, shapeSDF, blend);
        }
    } else {
        // Dynamic loop for 5+ shapes (uncommon cases)
        for (int i = 1; i < min(numShapes, MAX_SHAPES); i++) {
            float shapeSDF = getShapeSDFFromArray(i, p, shapeData);
            result = smoothUnion(result, shapeSDF, blend);
        }
    }
    
    return result;
}

// Calculate 3D normal using derivatives (shader-specific normal calculation)
vec3 getNormal(float sd, float thickness) {
    float dx = dFdx(sd);
    float dy = dFdy(sd);
    
    // The cosine and sine between normal and the xy plane
    float n_cos = max(thickness + sd, 0.0) / thickness;
    float n_sin = sqrt(max(0.0, 1.0 - n_cos * n_cos));
    
    return normalize(vec3(dx * n_cos, dy * n_cos, n_sin));
}
