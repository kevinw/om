#import "Sokol_Gfx";
#import "Process";
#import "Text_File_Handler";
String :: #import "String";

File :: #import "File";

Shader_Type :: enum { Vertex; Fragment; }

Shader :: struct {
    vert, frag: string;

    // TODO: sokol specific stuff. it would be nice if this stuff
    // was over in host_sokol or hidden somehow. or maybe just a
    // subtype polymorphic struct would be enough.


    native_shader: sg_shader;
    desc: sg_shader_desc;
    pipeline: sg_pipeline;
    reflection_info: Reflection_Info;

    shader_attr_desc: [16]sg_shader_attr_desc; // TODO: use type_of() on the sokol thing instead of hard-coding 16 here.
    vertex_attr_desc: [16]sg_vertex_attr_desc;
}

Reflection_Info :: struct {
    inputs: [..]struct { name: string; location: int; };
    outputs: [..]struct { name: string; location: int; };

    images: [..]struct {
        name: string;
        shader_type: Shader_Type;
        binding: u16;
    };
}

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

    for cmdline
        Log.print("% ", it);
    Log.print("\n");

    ok, exit_code, stdout, stderr := os_run_command(..cmdline, capture_and_return_output = true);

    if exit_code != 0 {
        Log.error();
        Log.print("sokol-shdc returned an error (%)\n", exit_code);
        Log.print("%\n%\n", stdout, stderr);
        return false, "", "";
    }
    
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
        print("OK: %, exit_code: %\n", ok, exit_code);
    }

    return false, "", "";
}

parse_shdc_meta_file :: (filename: string, shader: *Shader) -> bool {
    //print("parsing shdc meta: %\n", filename);

    // in our shdc binary format, strings are encoded as (u16-len, bytes)
    read_string :: inline (s: *string) -> string {
        return read_bytes(s, read(u16, s));
    }

    Stage :: enum u8 { INVALID; VS; FS; }

    bytes, ok := File.read_entire_file(filename);
    if !ok {
        Log.error();
        Log.print("could not read %\n", filename);
        return false;
    }

    buf := *bytes;

    // header and version
    if read_bytes(buf, 4) != "SHDC" {
        msg := tprint("expected 'SHDC' bytes at the beginning of the file, got: %", buf);
        assert(false, msg);
    }

    assert(read(u16, buf) == 1);

    // shader stage
    shader_stage := cast(Stage)read(u8, buf);
    assert(shader_stage != Stage.INVALID);
    assert(shader_stage == Stage.VS || shader_stage == Stage.FS);

    // entry point
    entry_name := to_c_string(read_string(buf)); // @Leak
    stage_desc: *sg_shader_stage_desc;
    // print("entry point: %\n", entry_point);
    if shader_stage == {
        case Stage.VS; stage_desc = *shader.desc.vs;
        case Stage.FS; stage_desc = *shader.desc.fs;
    }
    stage_desc.entry = entry_name;

    // inputs
    input_count := read(u16, buf);
    // print("num inputs: %\n", input_count);
    if input_count > 0 {
        for i: 0..input_count-1 {
            name := read_string(buf);
            shader.desc.attrs[i].name = to_c_string(name);
            location := read(u16, buf);
            shader.desc.attrs[i].sem_name = to_c_string(read_string(buf));
            shader.desc.attrs[i].sem_index = read(u8, buf);

            // store name and location in the shader's reflection info
            using shader.reflection_info;
            array_resize(*inputs, inputs.count + 1);
            inputs[inputs.count - 1].name     = copy_string(name);
            inputs[inputs.count - 1].location = location;
        }
    }
    
    // outputs
    outputs: [..]sg_shader_attr_desc;
    output_count := read(u16, buf);
    // print("num outputs: %\n", output_count);
    if output_count > 0 {
        array_resize(*outputs, output_count);
        for i: 0..output_count-1 {
            name := read_string(buf);
            outputs[i].name = to_c_string(name);
            location := read(u16, buf);
            outputs[i].sem_name = to_c_string(read_string(buf));
            outputs[i].sem_index = read(u8, buf);

            using shader.reflection_info;
            array_resize(*outputs, outputs.count + 1);
            outputs[outputs.count - 1].name     = copy_string(name);
            outputs[outputs.count - 1].location = location;
        }
    }
    
    // uniform blocks
    uniform_block_count := read(u16, buf);
    // print("num uniform blocks: %\n", uniform_block_count);
    if uniform_block_count > 0 {
        for i: 0..uniform_block_count-1 {
            block := *stage_desc.uniform_blocks[i];
            num_uniforms := read(u16, buf);
            for j: 0..num_uniforms-1 {
                block.uniforms[j].name = to_c_string(read_string(buf));
                block.uniforms[j].type = cast(sg_uniform_type)(read(u8, buf));
                block.uniforms[j].array_count = read(u16, buf);
                //print("member % % %\n", to_string(block.uniforms[j].name), block.uniforms[j].type, block.uniforms[j].array_count);
                unused_offset := read(u16, buf);
            }
            compute_uniform_block_size(block);
        }
    }

    // images
    images: [..]sg_shader_image_desc;
    image_count := read(u16, buf);
    // print("num images: %\n", image_count);
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
        for i: 0..bytes.count-1 print("% ", bytes[i]);
        print("\n");
        panic("leftover bytes\n");
    }

    return true;
}

compute_uniform_block_size :: (uniform_block: *sg_shader_uniform_block_desc) {
    total_size:s32 = 0;
    for uniform_block.uniforms {
        using sg_uniform_type;
        if it.type == INVALID break;
        if it.type == {
            case FLOAT;  total_size += size_of(float);
            case FLOAT2; total_size += size_of(Vector2);
            case FLOAT3; total_size += size_of(Vector3);
            case FLOAT4; total_size += size_of(Vector4);
            //case INT;    total_size += size_of(s32);
            case MAT4;   total_size += size_of(Matrix4);
            case; panic("unhandled uniform type %\n", it.type);
        }
    }

    //print("calculated uniform block size %\n", total_size);
    if total_size == 0
        print("warning: calculated uniform block size %\n", total_size);
    uniform_block.size = total_size;
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