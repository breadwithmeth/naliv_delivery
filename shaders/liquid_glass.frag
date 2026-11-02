#version 460 core
#include <flutter/runtime_effect.glsl>

// Scene coordinates are logical pixels. The sampler supplies a GPU-backed live scene.
uniform vec2 uSize;
uniform vec4 uBounds;
uniform vec4 uCorners; // top-left, top-right, bottom-right, bottom-left
uniform vec4 uTint;
uniform float uDark;
// 1.0 when raw sampling reverses rows relative to Flutter's image painter.
// A paired reference/shader probe measures this once at warm-up.
uniform float uFlipY;
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
  vec2 uv = clamp(point / uSize, vec2(0.0), vec2(1.0));
  uv.y = mix(uv.y, 1.0 - uv.y, uFlipY);
  return texture(uScene, uv);
}

// 21-tap golden-angle disc. Real frosted transmission: the scene stays
// structured instead of dissolving into a flat veil. The disc rotates per
// pixel so the fixed tap pattern cannot beat against regular scene detail,
// and the radius grows toward the rim where displacement stretches sources.
vec3 frosted(vec2 point, float radius) {
  float rotation = 6.2831853 *
      fract(52.9829189 * fract(dot(point, vec2(0.06711056, 0.00583715))));
  vec3 sum = scene(point).rgb;
  for (int i = 0; i < 20; i++) {
    float angle = (float(i) + 0.5) * 2.39996323 + rotation;
    float offset = radius * sqrt((float(i) + 0.5) / 20.0);
    sum += scene(point + vec2(cos(angle), sin(angle)) * offset).rgb;
  }
  return sum / 21.0;
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
  if (distance > 14.0) {
    fragColor = vec4(0.0);
    return;
  }
  if (distance > 0.75) {
    float shadowDistance = roundedBox(local - vec2(0.0, 4.0), halfSize, uCorners);
    float shadow = exp(-max(shadowDistance, 0.0) * 0.30) * mix(0.10, 0.045, uDark);
    fragColor = vec4(0.0, 0.0, 0.0, shadow);
    return;
  }

  // A rounded shell's surface normal. Refraction concentrates in the curved
  // rim; the flat interior stays a faithful, only barely domed pane.
  vec2 gradient = vec2(
    roundedBox(local + vec2(0.5, 0.0), halfSize, uCorners) -
        roundedBox(local - vec2(0.5, 0.0), halfSize, uCorners),
    roundedBox(local + vec2(0.0, 0.5), halfSize, uCorners) -
        roundedBox(local - vec2(0.0, 0.5), halfSize, uCorners)
  );
  gradient /= max(length(gradient), 0.0001);
  float rim = exp(min(distance, 0.0) / 10.0);
  vec2 slope = gradient * rim * 1.30 + local / max(halfSize, vec2(1.0)) * 0.018;
  vec3 normal = normalize(vec3(slope, 1.0));
  const float indexOfRefraction = 1.45;
  vec3 transmitted = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / indexOfRefraction);
  float bend = 16.0 + rim * 16.0;
  vec2 displacement = transmitted.xy / max(-transmitted.z, 0.1) * bend;
  float blur = min(mix(8.5, 10.5, uDark) * (1.0 + rim * 1.2 + exp(min(distance, 0.0) / 25.0) * 2.2), 26.0);
  vec3 color = frosted(point + displacement, blur);

  // Mild dispersion along the curved rim.
  color.r = mix(color.r, frosted(point + displacement * 1.045, blur).r, rim * 0.30);
  color.b = mix(color.b, frosted(point + displacement * 0.955, blur).b, rim * 0.30);

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
  float edgeBand = exp(-abs(distance + 2.5) * 0.9);
  float streak = pow(max(dot(normal.xy, key), 0.0), 6.0) * edgeBand;
  float sheen = pow(max(dot(normal.xy, key), 0.0), 1.5) * 0.03;
  float counter = pow(max(dot(normal.xy, vec2(0.45, 0.89)), 0.0), 3.0) * edgeBand * 0.08;
  color = clamp(color + vec3(fresnel * 0.10 + streak * 0.34 + sheen + counter), 0.0, 1.0);

  // Dithering keeps the wide frosted gradients free of 8-bit banding.
  float noise = fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
  color += (noise - 0.5) / 255.0;

  float coverage = 1.0 - smoothstep(-0.65, 0.75, distance);
  fragColor = vec4(clamp(color, 0.0, 1.0) * coverage, coverage);
}
