#import "Sokol_Gfx";
#import "Process";
File :: #import "File";

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

translate_glsl :: (vert: string, frag: string, shader: *Shader) ->
    (bool, string, string)
{
    path_to_shdc :: "C:\\src\\fips-deploy\\sokol-tools\\win64-vstudio-release\\sokol-shdc.exe";

    contents := tprint(#string END
@vs vs
%
@end

@fs fs
%
@end

@program my_program vs fs
END, vert, frag);

    File.make_directory_if_it_does_not_exist("temp");
    old_wd := get_working_directory();
    set_working_directory("temp");
    defer set_working_directory(old_wd);

    print_color("current working directory: %\n", get_working_directory(), color=FOREGROUND_BLUE);

    filename :: "temp.shd";
    if !File.write_entire_file(filename, contents) {
        Log.error();
        Log.print("Could not write to file %\n", filename);
        return false, "", "";
    }

    cmdline := {:string: 
        path_to_shdc,
        "--input", filename,
        "--slang", "hlsl5",
        "--format", "bare",
        "--output", "\"./\"",
    };

    print("--------\n%\n-----------", cmdline);

    ok, exit_code, stdout, stderr := os_run_command(
        ..cmdline, capture_and_return_output = true);
    
    print("****stdout*********\n%\n****stderr*******\n%\n", stdout, stderr);

    if ok && exit_code == 0 {
        print("success!?\n");
    } else {
        print_color("OK: %, exit_code: %\n", ok, exit_code, color=FOREGROUND_RED);
    }

    return false, "", "";
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