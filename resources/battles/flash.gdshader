shader_type canvas_item;
render_mode blend_mix;

uniform bool is_flashing = true;
uniform float FlashSpeed : hint_range(0.0, 5.0) = 1.0;
uniform float FlashIntensity : hint_range(0.2, 4.0) = 1.0;
void fragment() {
// BooleanParameter:16
	bool n_out16p0 = is_flashing;
// ColorConstant:11
	vec4 n_out11p0 = vec4(1.000000, 1.000000, 1.000000, 0.000000);
// Input:12
	vec4 n_out12p0 = COLOR;
	float n_out12p4 = n_out12p0.a;
	bool n_out13p0;
// Compare:13
	{
		bvec4 _bv = notEqual(n_out11p0, n_out12p0);
		n_out13p0 = any(_bv);
	}
// Input:2
	float n_out2p0 = TIME;
// FloatParameter:4
	float n_out4p0 = FlashSpeed;
// FloatOp:5
	float n_out5p0 = n_out2p0 * n_out4p0;
// FloatFunc:3
	float n_out3p0 = sin(n_out5p0);
// FloatParameter:8
	float n_out8p0 = FlashIntensity;
// FloatOp:9
	float n_in9p0 = 5.00000;
	float n_out9p0 = n_in9p0 - n_out8p0;
// FloatOp:7
	float n_out7p0 = n_out3p0 / n_out9p0;
// FloatFunc:6
	float n_out6p0 = abs(n_out7p0);
	vec3 n_out14p0;
// If:14
	float n_in14p1 = 1.00000;
	float n_in14p2 = 0.00001;
	vec3 n_in14p4 = vec3(0.00000, 0.00000, 0.00000);
	vec3 n_in14p5 = vec3(0.00000, 0.00000, 0.00000);
	if(abs((n_out13p0 ? 1.0 : 0.0) - n_in14p1) < n_in14p2)
	{
		n_out14p0 = vec3(n_out6p0);
	}
	else if((n_out13p0 ? 1.0 : 0.0) < n_in14p1)
	{
		n_out14p0 = n_in14p5;
	}
	else
	{
		n_out14p0 = n_in14p4;
	}
	vec3 n_out17p0;
// If:17
	float n_in17p1 = 1.00000;
	float n_in17p2 = 0.00001;
	if(abs((n_out16p0 ? 1.0 : 0.0) - n_in17p1) < n_in17p2)
	{
		n_out17p0 = n_out14p0;
	}
	else if((n_out16p0 ? 1.0 : 0.0) < n_in17p1)
	{
		n_out17p0 = vec3(n_out13p0 ? 1.0 : 0.0);
	}
	else
	{
		n_out17p0 = vec3(n_out13p0 ? 1.0 : 0.0);
	}
// FloatOp:15
	float n_out15p0 = n_out17p0.x * n_out12p4;
// Output:0
	COLOR.a = n_out15p0;
}