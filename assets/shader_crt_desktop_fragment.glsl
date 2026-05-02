#version 330
precision highp float;

in vec2 frag_texcoord;
in vec4 frag_color;

out vec4 final_color;

uniform sampler2D tex;
uniform float time;

uniform float curve;
uniform float blur;

const vec2 resolution = vec2(256.0, 192.0);
const float mask_scale = 1.2;

// const float raw_weights[] = float[](
//   0, 4, 7, 4, 0,
//   4,16,26,16, 4,
//   7,26,41,26, 7,
//   4,16,26,16, 4,
//   0, 4, 7, 4, 0,
// );
// const float raw_weights_side[] = float[](
//   0, 0, 7, 4, 0,
//   0,16,26,16, 4,
//   0,26,41,26, 7,
//   0,16,26,16, 4,
//   0, 0, 7, 4, 0,
// );

const float w3[] = float[](
  0.18385650224215247,   // 41
  0.11659192825112108,   // 26
  0.07174887892376682,   // 16
  0.03139013452914798,   // 7
  0.017937219730941704); // 4

const float w1[] = float[](
  0.16666666666666666,   // 41
  0.10569105691056911,   // 26
  0.06504065040650407,   // 16
  0.028455284552845527,  // 7
  0.016260162601626018); // 4

vec3 sample_rgb(vec2 uv, vec2 offset, float weight)
{
  vec2 pos = ((uv * resolution) + (offset * blur)) / resolution;
  return texture(tex, pos).rgb * weight;
}
vec3 sample_r(vec2 uv, vec2 offset, float weight)
{
  vec2 pos = ((uv * resolution) + (offset * blur)) / resolution;
  return vec3(texture(tex, pos).r, 0.0, 0.0) * weight;
}
vec3 sample_b(vec2 uv, vec2 offset, float weight)
{
  vec2 pos = ((uv * resolution) + (offset * blur)) / resolution;
  return vec3(0.0, 0.0, texture(tex, pos).b) * weight;
}

vec3 mask(vec2 uv)
{
  vec2 pos = uv * resolution * mask_scale;

  pos.x += 0.5;
  bool offgrid = int(pos.x) % 2 == 0;
  if (offgrid) {
    pos.y += 0.5;
  }

  vec2 frac = vec2(fract(pos.x), fract(pos.y));
  float d = 1.5 - length(frac - vec2(0.5, 0.5));
  return vec3(1.0, 1.0, 1.0) * d;
}

void main()
{
  vec2 center = frag_texcoord - 0.5;
  float distance = dot(center, center) * curve;
  vec2 uv = frag_texcoord + center * (1.0 + distance) * distance;

  if (max(abs(uv.x - 0.5), abs(uv.y - 0.5)) > 0.5) {
    final_color = vec4(0.0);
    return;
  }

  if (blur > 0.0) {
    vec3 color = vec3(0.0);

     color += sample_r(uv, vec2(-2.0, -2.0), w1[4]);
    color += sample_r(uv, vec2(-4.0, -1.0), w1[4]);
    color += sample_r(uv, vec2(-4.0,  0.0), w1[3]);
    color += sample_r(uv, vec2(-4.0,  1.0), w1[4]);
     color += sample_r(uv, vec2(-2.0,  2.0), w1[4]);

     color += sample_b(uv, vec2(2.0, -2.0), w1[4]);
    color += sample_b(uv, vec2(4.0, -1.0), w1[4]);
    color += sample_b(uv, vec2(4.0,  0.0), w1[3]);
    color += sample_b(uv, vec2(4.0,  1.0), w1[4]);
     color += sample_b(uv, vec2(2.0,  2.0), w1[4]);

    color += sample_rgb(uv, vec2(0.0, -2.0), w3[3]);
    color += sample_rgb(uv, vec2(0.0,  2.0), w3[3]);

    color += sample_rgb(uv, vec2(-1.0, -1.0), w3[2]);
    color += sample_rgb(uv, vec2(-1.0,  1.0), w3[2]);
    color += sample_rgb(uv, vec2( 1.0, -1.0), w3[2]);
    color += sample_rgb(uv, vec2( 1.0,  1.0), w3[2]);

    color += sample_rgb(uv, vec2(-1.0,  0.0), w3[1]);
    color += sample_rgb(uv, vec2( 0.0, -1.0), w3[1]);
    color += sample_rgb(uv, vec2( 1.0,  0.0), w3[1]);
    color += sample_rgb(uv, vec2( 0.0,  1.0), w3[1]);

    color += sample_rgb(uv, vec2(0.0, 0.0), w3[0]);

    color *= mask(uv);

    final_color = vec4(color, 1.0);
  } else {
    final_color = texture(tex, uv);
  }
}
