#version 330
precision highp float;
in vec2 frag_texcoord;
in vec4 frag_color;
out vec4 final_color;

uniform sampler2D tex;
uniform float time;

vec3 my_mask(vec2 uv)
{
    ivec2 iuv = ivec2(uv * vec2(5120,2560));
    const vec3 factors[] = vec3[](
        vec3(1,0,0),
        vec3(1,1,1),
        vec3(1,1,1),
        vec3(1,1,1),
        vec3(0,0,1),
        vec3(0,0,0));
    int indexA = (iuv.y * 3 + iuv.x - 1) % 6;
    int indexB = (iuv.y * 3 + iuv.x) % 6;
    int indexC = (iuv.y * 3 + iuv.x + 1) % 6;

    vec3 a = factors[indexA];
    vec3 b = factors[indexB];
    vec3 c = factors[indexC];

    return a * b * c;
}

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec4 gaussian(vec2 uv, float offset)
{
    float blur = 1.0 / 1024;

    float factor = 0.0162;
    if (offset < 1) {
        factor = 0.227;
    } else if (offset < 2) {
        factor = 0.1945;
    } else if (offset < 3) {
        factor = 0.121;
    } else if (offset < 4) {
        factor = 0.054;
    }

    vec4 col = vec4(0.0);
    col += texture(tex, uv + vec2(offset, 0) * blur);
    col += texture(tex, uv + vec2(0, offset) * blur);
    col += texture(tex, uv - vec2(offset, 0) * blur);
    col += texture(tex, uv - vec2(0, offset) * blur);

    // col.rgb /= 4.0;

    return col * factor * 0.5;
}

void main()
{
    vec2 uv = frag_texcoord;

    vec4 col = vec4(0.0);
    col += gaussian(uv, 0.0);
    col += gaussian(uv, 1.0);
    col += gaussian(uv, 2.0);
    col += gaussian(uv, 3.0);
    col += gaussian(uv, 4.0);
    final_color = col;

    // float luminance = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    //
    // if (luminance > 0.1) {
    //     final_color = col;
    // } else {
    //     final_color = vec4(0.0, 0.0, 0.0, 1.0);
    // }
}
