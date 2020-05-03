#import "Sokol_Gfx";
#import "Process";
#import "Text_File_Handler";
String :: #import "String";

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

make_and_push_working_directory :: (dirname: string) -> {}

translate_glsl :: (vert: string, frag: string, shader: *Shader) ->
    (bool, string, string)
{
    path_to_shdc :: "sokol-shdc.exe";

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

    filename :: "temp.shd";

    if !File.write_entire_file(filename, contents) {
        Log.error();
        Log.print("Could not write to file %\n", filename);
        return false, "", "";
    }

    cmdline := {:string: path_to_shdc,
        "--input", filename,
        "--slang", "hlsl5",
        "--format", "bare",
        "--output", "\"./\"",
    };

    File_win :: #import "File/windows";
    File_win.file_delete("my_program_fs.hlsl");
    File_win.file_delete("my_program_fs.hlsl.meta");
    File_win.file_delete("my_program_vs.hlsl");
    File_win.file_delete("my_program_vs.hlsl.meta");


    ok, exit_code, stdout, stderr := os_run_command(..cmdline, capture_and_return_output = true);
    
    if ok && exit_code == 0 {
        native_vert, vert_ok := File.read_entire_file("my_program_vs.hlsl");
        if !vert_ok return false, "", "";

        if !parse_shdc_meta_file("my_program_vs.hlsl.meta", shader)
            return false, "", "";

        native_frag, frag_ok := File.read_entire_file("my_program_fs.hlsl");
        if !frag_ok return false, "", "";

        if !parse_shdc_meta_file("my_program_fs.hlsl.meta", shader)
            return false, "", "";

        return true, native_vert, native_frag;
    } else {
        print_color("OK: %, exit_code: %\n", ok, exit_code, color=FOREGROUND_RED);
    }

    return false, "", "";
}

parse_shdc_meta_file :: (filename: string, shader: *Shader) -> bool {
    handler: Text_File_Handler;
    handler.do_version_number = false;

    defer deinit(*handler);

    start_file(*handler, "shader_meta", filename, "shader meta parsing");
    if handler.failed {
        Log.error();
        Log.print("Could not open '%'\n", filename);
        return false;
    }

    using Bindings_Type :: enum { Invalid; Inputs; Outputs; Uniform_Block; }
    bindings_type: Bindings_Type;

    stage: sg_shader_stage;
    entry: string;
    uniform_desc: sg_shader_uniform_desc;

    for line: handler {
        print("LINE %\n", line);
        idx, found := String.index_of_char(line, #char ":");
        if !found {
            error(handler, "expected a line to have a colon");
            continue;
        }

        key := String.slice(line, 0, idx);
        rhs := String.slice(line, idx + 1, line.count - idx - 1);
        rhs = String.eat_spaces(rhs);

        if key == {
            case "stage";
                if rhs == {
                    case "FS"; stage = sg_shader_stage.FS;
                    case "VS"; stage = sg_shader_stage.VS;
                    case;
                        error(handler, "Unknown shader stage: '%'\n", rhs);
                        continue;
                }
            case "entry"; entry = rhs;
            case "inputs"; bindings_type = Inputs;
            case "outputs"; bindings_type = Outputs;
            case "uniform block"; bindings_type = Uniform_Block;
            case "member";

                for str, i: String.split(rhs, ",") {
                    if i == 0 {
                        uniform_desc.name = str;
                    } else {
                        elems := String.split(str, ": ");

                        if elems[0] == {
                            case "type";
                            case "array_count";
                            case "offset";
                        }
                        


                    }

                }



            case;
                name := key;
                print("TODO: parse '%' for % with name %\n", rhs, bindings_type, name);

        }
    }

    return true;
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