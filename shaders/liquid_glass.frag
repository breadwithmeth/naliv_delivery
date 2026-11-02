#version 460 core
#include <flutter/runtime_effect.glsl>

// Geometry is in logical pixels of the page the shader is painted over.
//
// uScene is an already Gaussian-blurred crop of that page (see
// `LiquidGlassDock`), so the frost itself is smooth by construction and this
// shader only refracts it, smooths the refraction with a tiny fixed filter,
// tints it and lights the rim. The material is a bar anchored to the bottom of
// the page: its left, right and bottom edges are open (they lie on the screen
// edge) and only the top edge and its corners carry rim optics.
uniform vec2 uSize;
uniform vec4 uBounds;
uniform vec4 uCorners; // top-left, top-right, bottom-right, bottom-left
uniform vec4 uTint;
uniform float uDark;
// 1.0 when raw sampling reverses rows relative to Flutter's image painter.
// A paired reference/shader probe measures this once at warm-up.
uniform float uFlipY;
// Page-space rectangle (x, y, width, height) that uScene covers. A zero width
// means uScene spans [0, uSize] from the page origin.
uniform vec4 uCrop;
uniform sampler2D uScene;
out vec4 fragColor;

float roundedBox(vec2 point, vec2 halfSize, vec4 corners) {
  float radius = point.y < 0.0
      ? (point.x < 0.0 ? corners.x : corners.y)
      : (point.x < 0.0 ? corners.w : corners.z);
  radius = min(radius, min(halfSize.x, halfSize.y));
  vec2 q = abs(point) - halfSize + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vec4 scene(vec2 point) {
  vec4 crop = uCrop.z > 0.0 ? uCrop : vec4(0.0, 0.0, uSize);
  vec2 uv = clamp((point - crop.xy) / max(crop.zw, vec2(1.0)), vec2(0.0), vec2(1.0));
  uv.y = mix(uv.y, 1.0 - uv.y, uFlipY);
  return texture(uScene, uv);
}

// Fixed 9-tap smoothing over an already blurred scene. It only hides the
// stretch of the refraction near the rim, so the taps need no per-pixel
// rotation (which is what read as grain before).
vec3 smoothed(vec2 point, float radius) {
  vec3 sum = scene(point).rgb * 4.0;
  for (int i = 0; i < 8; i++) {
    float angle = float(i) * 0.78539816;
    sum += scene(point + vec2(cos(angle), sin(angle)) * radius).rgb;
  }
  return sum / 12.0;
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  if (uBounds.z <= 0.0 || uBounds.w <= 0.0) {
    fragColor = scene(point);
    return;
  }
  vec2 halfSize = uBounds.zw * 0.5;
  vec2 local = point - uBounds.xy - halfSize;
  float distance = roundedBox(local, halfSize, uCorners);
  if (distance > 24.0) {
    fragColor = vec4(0.0);
    return;
  }
  if (distance > 0.75) {
    // Soft shadow thrown upward from the top edge only.
    float shadowDistance = roundedBox(local + vec2(0.0, 6.0), halfSize, uCorners);
    float shadow = exp(-max(shadowDistance, 0.0) * 0.16) * mix(0.10, 0.07, uDark);
    fragColor = vec4(0.0, 0.0, 0.0, shadow);
    return;
  }

  // A rounded shell's surface normal. Refraction concentrates in the curved
  // top rim; the flat interior stays a faithful, only barely domed pane.
  vec2 gradient = vec2(
    roundedBox(local + vec2(0.5, 0.0), halfSize, uCorners) -
        roundedBox(local - vec2(0.5, 0.0), halfSize, uCorners),
    roundedBox(local + vec2(0.0, 0.5), halfSize, uCorners) -
        roundedBox(local - vec2(0.0, 0.5), halfSize, uCorners)
  );
  gradient /= max(length(gradient), 0.0001);
  // The side and bottom edges are the screen edge: no optics there.
  float topFacing = smoothstep(0.10, 0.80, -gradient.y);
  float rim = exp(min(distance, 0.0) / 10.0) * topFacing;
  vec2 slope = gradient * rim * 1.30 + local / max(halfSize, vec2(1.0)) * 0.018;
  vec3 normal = normalize(vec3(slope, 1.0));
  const float indexOfRefraction = 1.45;
  vec3 transmitted = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / indexOfRefraction);
  float bend = 16.0 + rim * 16.0;
  vec2 displacement = transmitted.xy / max(-transmitted.z, 0.1) * bend;
  vec3 color = smoothed(point + displacement, 1.5 + rim * 4.0);

  // Mild dispersion along the curved rim.
  color.r = mix(color.r, scene(point + displacement * 1.045).r, rim * 0.30);
  color.b = mix(color.b, scene(point + displacement * 0.955).b, rim * 0.30);

  // Theme-adaptive range control: tame the extreme luminances that would sit
  // under sharp text, without flattening the scene into an opaque slab.
  float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(color, vec3(1.0), (1.0 - uDark) * clamp((0.50 - luminance) * 1.05, 0.0, 0.62));
  color = mix(color, vec3(0.0), uDark * clamp((luminance - 0.30) * 1.40, 0.0, 0.85));
  color = mix(color, uTint.rgb, uTint.a);

  // Lighting: Fresnel plus a crisp top streak and a faint counter-light.
  // No saturated sheen and no constant gloss across the pane.
  float baseReflection = pow((indexOfRefraction - 1.0) / (indexOfRefraction + 1.0), 2.0);
  float fresnel = baseReflection + (1.0 - baseReflection) * pow(1.0 - normal.z, 5.0);
  vec2 key = normalize(vec2(-0.35, -0.85));
  float edgeBand = exp(-abs(distance + 2.5) * 0.9) * topFacing;
  float streak = pow(max(dot(normal.xy, key), 0.0), 6.0) * edgeBand;
  float sheen = pow(max(dot(normal.xy, key), 0.0), 1.5) * 0.03;
  float counter = pow(max(dot(normal.xy, vec2(0.45, 0.89)), 0.0), 3.0) * edgeBand * 0.08;
  color = clamp(color + vec3(fresnel * 0.10 + streak * 0.34 + sheen + counter), 0.0, 1.0);

  // Dithering (at most +-0.5/255) keeps the wide frosted gradients free of
  // 8-bit banding without adding visible grain.
  float noise = fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
  color += (noise - 0.5) / 255.0;

  float coverage = 1.0 - smoothstep(-0.65, 0.75, distance);
  fragColor = vec4(clamp(color, 0.0, 1.0) * coverage, coverage);
}
