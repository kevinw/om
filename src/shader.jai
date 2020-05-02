#import "Sokol_Gfx";
#import "Process";

Shader_Type :: enum { Vertex; Fragment; }

Reflection_Info :: struct {
    input_locations: [..]struct {
        name: string;
        location: int;
    };

    images: [..]struct {
        name: string;
        shader_type: Shader_Type;
        binding: u16;
    };
}


run_shdc :: () {
    path_to_shdc :: "C:\\src\\fips-deploy\\sokol-tools\\win64-vstudio-release\\sokol-shdc.exe";

    os_run_command(
        path_to_shdc,
        capture_and_return_output = true,
    );
}

// builtin shaders
shader_color2d :: () -> *Shader {
    using state.shader_cache;

    if _color2d == null
        _color2d = shader(Builtin_Shaders.color2d_v, Builtin_Shaders.color_f);
    return _color2d;
}

shader_texture2d :: () -> *Shader {
    using state.shader_cache;

    if _texture2d == null
        _texture2d = shader(Builtin_Shaders.texture2d_v, Builtin_Shaders.texture_f);
    return _texture2d;
}