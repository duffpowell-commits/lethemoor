shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 stone_tint : source_color = vec4(0.26,0.29,0.33,1.0);
uniform float roughness = 0.88;
uniform float grain_scale = 7.0;
float hash(vec2 p) {
 p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y);
}
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
 float n=noise(UV*grain_scale)*0.13+noise(UV*grain_scale*3.0)*0.04;
 ALBEDO=stone_tint.rgb*(0.82+n);
 ROUGHNESS=roughness;
}