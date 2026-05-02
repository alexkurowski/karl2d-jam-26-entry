#version 330
precision highp float;

in vec2 frag_texcoord;
in vec4 frag_color;

out vec4 final_color;

uniform sampler2D tex;

// Palette from https://lospec.com/palette-list/lost-century
const vec3 palette[] = vec3[](
    vec3(0.82, 0.69, 0.53),  // Light
    vec3(0.78, 0.48, 0.35),  // LightRed
    vec3(0.68, 0.36, 0.25),  // Red
    vec3(0.47, 0.27, 0.29),  // DarkRed
    vec3(0.29, 0.24, 0.27),  // Dark
    vec3(0.73, 0.57, 0.35),  // LightBrown
    vec3(0.57, 0.45, 0.25),  // Brown
    vec3(0.30, 0.27, 0.22),  // DarkGreen
    vec3(0.47, 0.45, 0.23),  // Green
    vec3(0.70, 0.65, 0.33),  // LightGreen
    vec3(0.82, 0.79, 0.65),  // LightBlue
    vec3(0.55, 0.67, 0.63),  // Blue
    vec3(0.29, 0.45, 0.43),  // DarkBlue
    vec3(0.34, 0.28, 0.32),  // DarkGray
    vec3(0.52, 0.47, 0.46),  // Gray
    vec3(0.67, 0.61, 0.56)); // LightGray

void main()
{
    vec4 c = texture(tex, frag_texcoord);
    int index;

    // Transparent pixel
    if (c.a < 0.01) {
        final_color = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }
    // White / Foreground
    if (c.r > 0.9) {
        index = int(floor(frag_color.r * 255.0));
        final_color = vec4(palette[index], 1.0);
        return;
    }
    // Light / Mid 1
    if (c.r > 0.5) {
        index = int(floor(frag_color.g * 255.0));
        final_color = vec4(palette[index], 1.0);
        return;
    }
    // Dark / Mid 2
    if (c.r > 0.1) {
        index = int(floor(frag_color.b * 255.0));
        final_color = vec4(palette[index], 1.0);
        return;
    }
    // Black / Background
    index = int(floor(frag_color.a * 255.0));
    final_color = vec4(palette[index], 1.0);
}
