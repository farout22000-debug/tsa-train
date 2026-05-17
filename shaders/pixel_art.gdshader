shader_type canvas_item;

uniform float pixel_size : hint_range(1, 32) = 4.0;
uniform float color_levels : hint_range(1, 64) = 16.0;
uniform float dither_strength : hint_range(0.0, 0.5) = 0.05;
uniform float contrast : hint_range(0.0, 2.0) = 1.2;

const float bayer4x4[16] = float[](
    0.0, 8.0, 2.0, 10.0,
    12.0, 4.0, 14.0, 6.0,
    3.0, 11.0, 1.0, 9.0,
    15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	
	// 1. Pixelate
	vec2 uv = floor(UV * texture_size / pixel_size) * pixel_size / texture_size;
	vec4 color = texture(TEXTURE, uv);
	
	// 2. Contrast Boost (Pre-rendered look)
	color.rgb = (color.rgb - 0.5) * contrast + 0.5;
	
	// 3. Bayer Dithering
	int x = int(uv.x * texture_size.x / pixel_size) % 4;
	int y = int(uv.y * texture_size.y / pixel_size) % 4;
	float b = (bayer4x4[y * 4 + x] / 16.0) - 0.5;
	color.rgb += b * dither_strength;
	
	// 4. Quantize
	color.rgb = floor(color.rgb * color_levels) / color_levels;
	
	COLOR = color;
}

