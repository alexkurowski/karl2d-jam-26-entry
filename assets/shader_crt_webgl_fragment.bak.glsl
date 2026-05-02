#version 300 es
precision highp float;
in vec2 frag_texcoord;
in vec4 frag_color;
out vec4 final_color;

uniform sampler2D tex;
uniform float time;

void main()
{
    vec4 c = texture(tex, frag_texcoord);

    // CRT scanlines
    float scanline = sin(frag_texcoord.y * 800.0) * 0.04;
    c.rgb -= scanline;

    // CRT curve (slight barrel distortion)
    vec2 cc = frag_texcoord - 0.5;
    float dist = dot(cc, cc) * 0.1;
    vec2 uv = frag_texcoord + cc * (1.0 + dist) * dist;

    // Vignette effect
    float vignette = smoothstep(0.7, 0.4, length(cc));

    // RGB shift for chromatic aberration
    float shift = 0.002;
    float r = texture(tex, uv + vec2(shift, 0.0)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - vec2(shift, 0.0)).b;

    // Combine effects
    c = vec4(r, g, b, 1.0);
    c.rgb *= vignette;
    c.rgb -= scanline;

    // Subtle flicker
    c.rgb *= 0.97 + 0.03 * sin(time * 10.0);

    // Add slight noise
    float noise = fract(sin(dot(uv, vec2(12.9898, 78.233)) + time) * 43758.5453);
    c.rgb += noise * 0.02;

    final_color = c * frag_color;
}
