#version 330
precision highp float;

in vec2 frag_texcoord;
in vec4 frag_color;

out vec4 final_color;

uniform sampler2D tex;

const vec3 palette[] = vec3[](
    vec3(0.0000, 0.0000, 0.0000),  // Black
    vec3(0.1137, 0.1686, 0.3255),  // DarkBlue
    vec3(0.4941, 0.1451, 0.3255),  // DarkPurple
    vec3(0.0000, 0.5294, 0.3176),  // DarkGreen
    vec3(0.6706, 0.3216, 0.2118),  // Brown
    vec3(0.3725, 0.3412, 0.3098),  // DarkGray
    vec3(0.7608, 0.7647, 0.7804),  // LightGray
    vec3(1.0000, 0.9451, 0.9098),  // White
    vec3(1.0000, 0.0000, 0.3020),  // Red
    vec3(1.0000, 0.6392, 0.0000),  // Orange
    vec3(1.0000, 0.9255, 0.1529),  // Yellow
    vec3(0.0000, 0.8941, 0.2118),  // Green
    vec3(0.1608, 0.6784, 1.0000),  // Blue
    vec3(0.5137, 0.4627, 0.6118),  // Lavender
    vec3(1.0000, 0.4667, 0.6588),  // Pink
    vec3(1.0000, 0.8000, 0.6667)); // LightPeach

void main()
{
    vec4 c = texture(tex, frag_texcoord);
    int index;

    // Transparent
    if (c.a < 0.01) {
        final_color = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // Foreground
    if (c.r > 0.666) {
        index = int(floor(frag_color.r * 255.0));
        final_color = vec4(palette[index], 1.0);
        return;
    }
    // Background
    if (c.r < 0.333) {
      index = int(floor(frag_color.b * 255.0));
      final_color = vec4(palette[index], 1.0);
      return;
    }
    // Midground
    index = int(floor(frag_color.g * 255.0));
    final_color = vec4(palette[index], 1.0);
}
