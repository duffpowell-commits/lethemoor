extends Node3D
## Visual-only wet stone ground study. No gameplay dependencies.

const SIZE := Vector2(8.0, 8.0)
const GRID := 8

func _ready() -> void:
	_build()

func _material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 stone_color : source_color = vec3(0.19, 0.22, 0.25);
uniform vec3 wet_color : source_color = vec3(0.075, 0.095, 0.12);
uniform float roughness_base = 0.82;
uniform float wetness = 0.42;
uniform float tile_scale = 8.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),
		mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
	vec2 uv=UV*tile_scale;
	vec2 cell=floor(uv);
	vec2 local=fract(uv);
	float mortar=step(0.055,local.x)*step(0.055,local.y);
	float variation=noise(cell*0.7+noise(cell))*0.22;
	float puddle=smoothstep(0.52,0.8,noise(UV*13.0+vec2(3.7,8.1)))*wetness;
	vec3 base=mix(stone_color,wet_color,puddle);
	base*=0.83+variation;
	ALBEDO=mix(wet_color*0.55,base,mortar);
	ROUGHNESS=mix(roughness_base,0.24,puddle);
	METALLIC=0.03;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _build() -> void:
	var plane := MeshInstance3D.new()
	plane.name = "WetStoneSurface"
	var mesh := PlaneMesh.new()
	mesh.size = SIZE
	plane.mesh = mesh
	plane.material_override = _material()
	plane.rotation.x = 0.0
	add_child(plane)

	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.035,0.045,0.055)
	border_mat.roughness = 0.95
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(SIZE.x,0.1,SIZE.y)
	var border := MeshInstance3D.new()
	border.name = "GroundBase"
	border.mesh = border_mesh
	border.position.y = -0.06
	border.material_override = border_mat
	add_child(border)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-25,0)
	light.light_energy = 1.2
	add_child(light)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025,0.035,0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.18,0.2,0.23)
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	add_child(environment_node)

	var camera := Camera3D.new()
	camera.position = Vector3(5.0,5.8,6.5)
	camera.look_at(Vector3(0,0,0),Vector3.UP)
	camera.current = true
	camera.fov = 48
	add_child(camera)
