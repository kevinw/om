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
    print("parsing shdc meta: %\n", filename);

    Stage :: enum u8 { INVALID; VS; FS; }

    read :: inline ($T: Type, s: *string) -> T {
        assert(s.count >= size_of(T));
        result := << cast(*T)s.data;
        advance(s, size_of(T));
        return result;
    }

    read_bytes :: inline (s: *string, num_bytes: int) -> string {
        assert(s.count >= num_bytes);

        new_str: string;
        new_str.data = s.data;
        new_str.count = num_bytes;
        
        advance(s, num_bytes);

        return new_str;
    }

    read_string :: inline (s: *string) -> string {
        return read_bytes(s, read(u16, s));
    }

    read_attr :: (s: *string, attr: *sg_shader_attr_desc) {
        attr.name = to_c_string(read_string(s));
        unused_slot := read(u16, s);
        attr.sem_name = to_c_string(read_string(s));
        attr.sem_index = read(u8, s);
    }

    read_uniform_block :: (s: *string, block: *sg_shader_uniform_block_desc) {
        num_uniforms := read(u16, s);
        for i: 0..num_uniforms-1 {
            using *block.uniforms[i];
            name = to_c_string(read_string(s));
            type = cast(sg_uniform_type)(read(u8, s));
            array_count = read(u16, s);
            print("member % % %\n", to_string(name), type, array_count);
            unused_offset := read(u16, s);
        }
    }

    bytes, ok := File.read_entire_file(filename);
    if !ok {
        Log.error();
        Log.print("could not read %", filename);
        return false;
    }

    buf := *bytes;

    // header and version
    assert(read_bytes(buf, 4) == "SHDC");
    assert(read(u16, buf) == 1);

    // shader stage
    shader_stage := cast(Stage)read(u8, buf);
    assert(shader_stage != Stage.INVALID);
    assert(shader_stage == Stage.VS || shader_stage == Stage.FS);

    // entry point
    entry_point := read_string(buf);
    print("entry point: %\n", entry_point);

    // inputs
    inputs: [..]sg_shader_attr_desc;
    input_count := read(u16, buf);
    print("num inputs: %\n", input_count);
    if input_count > 0 {
        array_resize(*inputs, input_count);
        for i: 0..input_count-1
            read_attr(buf, *inputs[i]);
    }
    
    // outputs
    outputs: [..]sg_shader_attr_desc;
    output_count := read(u16, buf);
    print("num outputs: %\n", output_count);
    if output_count > 0 {
        array_resize(*outputs, output_count);
        for i: 0..output_count-1
            read_attr(buf, *outputs[i]);
    }
    
    // uniform blocks
    blocks: [..]sg_shader_uniform_block_desc;
    uniform_block_count := read(u16, buf);
    print("num uniform blocks: %\n", uniform_block_count);
    if uniform_block_count > 0 {
        array_resize(*blocks, uniform_block_count);
        for i: 0..uniform_block_count-1
            read_uniform_block(buf, *blocks[i]);
    }

    // images
    images: [..]sg_shader_image_desc;
    image_count := read(u16, buf);
    print("num images: %\n", image_count);
    if image_count > 0 {
        array_resize(*images, image_count);
        for i: 0..image_count-1 {
            images[i].name = to_c_string(read_string(buf));
            unused_slot := read(u16, buf);
            images[i].type = cast(sg_image_type)read(u8, buf);
            unused_base_type := cast(sg_image_type)read(u8, buf);
        }
    }

    if bytes.count > 0 {
        print("error:\n");
        for i: 0..bytes.count-1 {
            print("% ", bytes[i]);
        }
        print("\n");
        panic("leftover bytes\n");
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