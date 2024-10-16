shader_type canvas_item;

uniform vec4 color : source_color;
uniform float mixture;
uniform float alpha = 1.0;

void fragment() 
{
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
	COLOR.rgb = mix(COLOR.rgb, color.rgb, mixture);
}