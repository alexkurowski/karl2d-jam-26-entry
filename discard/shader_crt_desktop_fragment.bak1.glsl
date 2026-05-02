#version 330
precision highp float;

in vec2 frag_texcoord;
in vec4 frag_color;

out vec4 final_color;

uniform sampler2D tex;
uniform float time;

const float curviness = 0.033;
const float blur = 0.00075;
const float sample_width = 1.0 / 256.0;

// Hardness of scanline.
//  -8.0 = soft
// -16.0 = medium
const float scanline_contrast = -2.0;

// Hardness of pixels in scanline.
// -2.0 = soft
// -4.0 = hard
const float pixel_contrast = -2.0;

// Hardness of short vertical bloom.
//  -1.0 = wide to the point of clipping (bad)
//  -1.5 = wide
//  -4.0 = not very wide at all
const float scanline_bloom = -2.0;

// Hardness of short horizontal bloom.
//  -0.5 = wide to the point of clipping (bad)
//  -1.0 = wide
//  -2.0 = not very wide at all
const float pixel_bloom = -0.5;

// Amount of small bloom effect.
//  1.0/1.0 = only bloom
//  1.0/16.0 = what I think is a good amount of small bloom
//  0.0     = no bloom
const float bloom_amount = 1.0 / 16.0;

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
vec3 sample(vec2 pos, vec2 off) {
  pos = (pos + off * blur);
  if (max(abs(pos.x - 0.5), abs(pos.y - 0.5)) > 0.5)
    return vec3(0.0, 0.0, 0.0);
  return texture(tex, pos.xy).rgb;
}

// Distance in emulated pixels to nearest texel.
vec2 distance(vec2 pos) { return -((pos - floor(pos)) - vec2(0.5)); }

// 1D Gaussian.
float gaussian(float pos, float scale) { return exp2(scale * pos * pos); }

// 3-tap Gaussian filter along horz line.
vec3 gaussian_3(vec2 pos, float off) {
  float s = sample_width;
  vec3 b = sample(pos, vec2(-1.0 * s, off * s));
  vec3 c = sample(pos, vec2(0.0 * s, off * s));
  vec3 d = sample(pos, vec2(1.0 * s, off * s));
  float dst = distance(pos * 256.0).x;
  // Convert distance to weight.
  float scale = pixel_contrast;
  float wb = gaussian(dst - 1.0, scale);
  float wc = gaussian(dst + 0.0, scale);
  float wd = gaussian(dst + 1.0, scale);
  // Return filtered sample.
  return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

// 5-tap Gaussian filter along horz line.
vec3 gaussian_5(vec2 pos, float off) {
  float s = sample_width;
  vec3 a = sample(pos, vec2(-2.0 * s, off * s));
  vec3 b = sample(pos, vec2(-1.0 * s, off * s));
  vec3 c = sample(pos, vec2(0.0 * s, off * s));
  vec3 d = sample(pos, vec2(1.0 * s, off * s));
  vec3 e = sample(pos, vec2(2.0 * s, off * s));
  float dst = distance(pos * 256.0).x;
  // Convert distance to weight.
  float scale = pixel_contrast;
  float wa = gaussian(dst - 2.0, scale);
  float wb = gaussian(dst - 1.0, scale);
  float wc = gaussian(dst + 0.0, scale);
  float wd = gaussian(dst + 1.0, scale);
  float we = gaussian(dst + 2.0, scale);
  // Return filtered sample.
  return (a * wa + b * wb + c * wc + d * wd + e * we) /
         (wa + wb + wc + wd + we);
}

// 7-tap Gaussian filter along horz line.
vec3 gaussian_7(vec2 pos, float off) {
  float s = sample_width;
  vec3 a = sample(pos, vec2(-3.0 * s, off * s));
  vec3 b = sample(pos, vec2(-2.0 * s, off * s));
  vec3 c = sample(pos, vec2(-1.0 * s, off * s));
  vec3 d = sample(pos, vec2(0.0 * s, off * s));
  vec3 e = sample(pos, vec2(1.0 * s, off * s));
  vec3 f = sample(pos, vec2(2.0 * s, off * s));
  vec3 g = sample(pos, vec2(3.0 * s, off * s));
  float dst = distance(pos * 256.0).x;
  // Convert distance to weight.
  float scale = pixel_bloom;
  float wa = gaussian(dst - 3.0, scale);
  float wb = gaussian(dst - 2.0, scale);
  float wc = gaussian(dst - 1.0, scale);
  float wd = gaussian(dst + 0.0, scale);
  float we = gaussian(dst + 1.0, scale);
  float wf = gaussian(dst + 2.0, scale);
  float wg = gaussian(dst + 3.0, scale);
  // Return filtered sample.
  return (a * wa + b * wb + c * wc + d * wd + e * we * f * wf + g * wg) /
         (wa + wb + wc + wd + we + wf + wg);
}

// Return scanline weight.
float scanline_weight(vec2 pos, float off) {
  float dst = distance(pos * 128.0).y;
  return gaussian(dst + off, scanline_contrast);
}

// Sample a 3-5-3 circle around
vec3 sample_circle(vec2 pos) {
  vec3 a = gaussian_3(pos, -1.0);
  vec3 b = gaussian_5(pos, 0.0);
  vec3 c = gaussian_3(pos, 1.0);
  float wa = scanline_weight(pos, -1.0);
  float wb = scanline_weight(pos, 0.0);
  float wc = scanline_weight(pos, 1.0);
  return a * wa + b * wb + c * wc;
}

float bloom_weight(vec2 pos, float off) {
  float dst = distance(pos * 128.0).y;
  return gaussian(dst + off, scanline_bloom);
}

vec3 smaple_bloom(vec2 pos){
  vec3 a = gaussian_5(pos,-2.0);
  vec3 b = gaussian_7(pos,-1.0);
  vec3 c = gaussian_7(pos, 0.0);
  vec3 d = gaussian_7(pos, 1.0);
  vec3 e = gaussian_5(pos, 2.0);
  float wa = bloom_weight(pos,-2.0);
  float wb = bloom_weight(pos,-1.0);
  float wc = bloom_weight(pos, 0.0);
  float wd = bloom_weight(pos, 1.0);
  float we = bloom_weight(pos, 2.0);
  return a * wa + b * wb + c * wc + d * wd + e * we;
}

// vec3 make_mask(vec2 pos) {
//   const float dark = 0.9;
//   const float bright = 0.99;

//   // pos.x += pos.y * 3.0;
//   vec3 mask = vec3(dark, dark, dark);
//   pos.x = fract(pos.x);
//   if (pos.x < 0.333)
//     mask.r = bright;
//   else if (pos.x < 0.666)
//     mask.g = bright;
//   else
//     mask.b = bright;
//   return mask;
// }

void main() {
  vec2 center = frag_texcoord - 0.5;
  float distance = dot(center, center) * curviness;
  vec2 uv = frag_texcoord + center * (1.0 + distance) * distance;

  vec3 color = sample_circle(uv);

  final_color = vec4(color, 1.0);
}
