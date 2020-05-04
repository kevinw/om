#import "Basic";
#import "Math";
Log :: #import "Log";

#import "Sokol_Gfx";
#import "Sokol_App";
#import "Sokol_Time";


// Global state
state: struct {
    last_frame_time: float64;
    frame_time: float64;
    delta_time: float;
    frame_count: u64;

    current_program: *Use_Program;
    current_bind_values: [..]Shader_Value_Entry;
    current_blend: sg_blend_state;

    pass_action: sg_pass_action;

    window: *Window;

    native_buffer_pool: [150]Native_Pool_Entry(sg_buffer);
    native_image_pool: [150]Native_Pool_Entry(sg_image);
    cached_pipelines: [..]struct {
        desc: sg_pipeline_desc;
        pipeline: sg_pipeline;
    };
    shader_cache: struct {
        _color2d: *Shader;
        _texture2d: *Shader;
    };
};

_make_image :: (w: u16, h: u16, _data: []u8, clone_data := true) -> Image {
    data := _data;

    if clone_data {
        old_ptr := data.data;
        data.data = alloc(data.count);
        memcpy(data.data, old_ptr, data.count);
    }

    img: Image;
    img.data = data;
    img.width = w;
    img.height = h;
    img.pool_id = next_free_native_image_id();
    return img;
}

apply_uniforms :: (shader_stage: sg_shader_stage, slot: int, block_desc: sg_shader_uniform_block_desc) {
    if block_desc.size == 0 return;

    using state.current_program.shader;

    uniform_bytes: []u8;
    uniform_bytes.data = talloc(block_desc.size);
    uniform_bytes.count = block_desc.size;

    {
        // put uniforms into a byte buffer
        byte_offset := 0;
        for uniform: block_desc.uniforms {
            if uniform.type == sg_uniform_type.INVALID break; // sokol's 'end of uniforms' marker
            if uniform.array_count > 0 panic("TODO: impl array_count\n");

            val := get_bind_val_ptr(to_string(uniform.name)); // TODO: @Speed - this is strlen everytime....doh
            if val != null {
                dst := *uniform_bytes[byte_offset];
                using val.TagType;
                if val.type == {
                    case _Vector3; memcpy(dst, val, size_of(Vector3));
                    case _Vector4; memcpy(dst, val, size_of(Vector4));
                    case _Buffer; 
                        buf := val.try_get_ptr(val, Buffer);
                        memcpy(dst, buf.data.data, buf.data.count);
                    case _Matrix4; memcpy(dst, val, size_of(Matrix4));
                    case _Image;   print("warning: % is an image, not a uniform\n", uniform.name);
                }
            }

            sz := size_of_uniform_type(uniform.type);

            // In HLSL, each bare uniform must occupy a multiple of vec4 size.
            // TODO: is this true for other shader envs like metal or opengl?
            PACK_SIZE :: size_of(Vector4);
            sz_packed := round_up(cast(float)sz / PACK_SIZE) * PACK_SIZE;
            byte_offset += sz_packed;
        }
    }

    sg_apply_uniforms(shader_stage, cast(s32)slot, *uniform_bytes[0], cast(s32)block_desc.size);
}

size_of_uniform_type :: inline (uniform_type: sg_uniform_type) -> int {
    using sg_uniform_type;
    if uniform_type == {
        case FLOAT;  return size_of(float32);
        case FLOAT2; return size_of(Vector2);
        case FLOAT3; return size_of(Vector3);
        case FLOAT4; return size_of(Vector4);
        case MAT4;   return size_of(Matrix4);
        //case INT;    return size_of(s32);
        case INVALID;
            panic("invalid size_of_uniform arg");
        case;
            panic("unimplemented size_of_uniform");
    }
    return 0;
}

_ensure_image_created :: (img: *Image) -> sg_image {
    assert(img.pool_id != 0, "image was not created");
    using pool_entry := *state.native_image_pool[img.pool_id];
    assert(occupied == true);

    if sg_obj.id == 0 {
        assert(img.width > 0,  "image width must be positive non-zero");
        assert(img.height > 0, "image height must be positive non-zero");

        desc: sg_image_desc;
        {
            using desc;
            type = sg_image_type._2D;
            render_target = false;
            width  = cast(s32)img.width;
            height = cast(s32)img.height;
            label = copy_string(tprint("generated-image-%%", img.pool_id, #char "\0")).data; // TODO: @Leak
        };
        desc.content.subimage[0][0].ptr = *img.data[0];
        desc.content.subimage[0][0].size = cast(s32)img.data.count;
        sg_obj = sg_make_image(*desc);

        if verbose_mode()
            print("created image of size % with sg id %\n", img.data.count, sg_obj.id);
    }

    return sg_obj;
}

Native_Pool_Entry :: struct(T: Type) {
    sg_obj: T;
    occupied: bool;
    usage: Resource_Usage;
}

// TODO: these could just be [dynamic]

num_elements :: (buffer: Buffer) -> int {
    sz:int;

    if buffer.type == {
        case Buffer_Type.U16_Elems; sz = size_of(u16);
        case Buffer_Type.U32_Elems; sz = size_of(u32);
        case Buffer_Type.Vector2;   sz = size_of(Vector2);
        case;           panic("unimplemented Buffer_Type for num_elements");
    }

    return buffer.data.count / sz; // TODO: assert that this is a whole number
}

sokol_blend_states: [5]sg_blend_state;
_init_blend_states :: () {
    s := *sokol_blend_states;
    // TODO: JAI BUG;
    /*

    sokol_blend_states[0].enabled = false;

    {
        s[cast(int)Blend_Mode.Alpha].enabled          = true;
        op_rgb           = sg_blend_op.ADD;
        op_alpha         = sg_blend_op.ADD;
        src_factor_rgb   = sg_blendfactor.SRC_ALPHA;
        dst_factor_rgb   = sg_blendfactor.ONE_MINUS_SRC_ALPHA;
        src_factor_alpha = sg_blendfactor.SRC_ALPHA;
        dst_factor_alpha = sg_blendfactor.ONE_MINUS_SRC_ALPHA;
        blend_color      = {:float: 1, 1, 1, 1 };
    }
    */
}

render_children :: inline (using node: *Node) {
    if recursion_limit < 0 return;
    recursion_limit -= 1;
    defer recursion_limit += 1;

    for children render_node(it);
}

// TODO: use an explicit stack instead of recursion
render_node :: (node_base: *Node) {
    if node_base.flags & Node_Flags.Hidden {
        return;
    }

    if node_base.type == {
        case Bind;
            bind := cast(*Bind)node_base;

            bind_count := state.current_bind_values.count;
            defer state.current_bind_values.count = bind_count;

            array_add(*state.current_bind_values, ..bind.values);

            render_children(node_base);
        case Draw;
            if state.current_program == null {
                Log.warning(); Log.print("Error: cannot draw, there is no active program.\n");
                return;
            }
            render_draw_node(cast(*Draw)node_base);
            render_children(node_base);
        case Scale;
            scale_node := cast(*Scale)node_base;

            mv := get_bind_val_ptr("MV", Matrix4);

            orig := << mv;
            defer << mv = orig;

            m := orig;
            m.v[0].x *= scale_node.scale.x;
            m.v[1].y *= scale_node.scale.y;
            m.v[2].z *= scale_node.scale.z;
            << mv = m;

            render_children(node_base);
        case Rotate;
            rotate_node := cast(*Rotate)node_base;

            mv := get_bind_val_ptr("MV", Matrix4);
            orig := << mv;
            defer << mv = orig;

            rotation: Quaternion;
            set_from_axis_and_angle(*rotation, rotate_node.axis.x, rotate_node.axis.y,
                rotate_node.axis.z, rotate_node.angle);
            << mv = rotate(orig, rotation);

            render_children(node_base);
        case Translate;
            translate_node := cast(*Translate)node_base;

            mv := get_bind_val_ptr("MV", Matrix4);
            orig := << mv;
            defer << mv = orig;

            m := orig;
            m.v[0].z += translate_node.offset.x;
            m.v[1].z += translate_node.offset.y;
            m.v[2].z += translate_node.offset.z;
            << mv = m; // TODO: just write to the pointer
        case Blend;
            blend_node := cast(*Blend)node_base;

            old_blend := state.current_blend;
            state.current_blend = sokol_blend_states[blend_node.blend_mode];
            defer state.current_blend = old_blend;

            render_children(node_base);
        case Read_Uniform;
            read_uniform_node := cast(*Read_Uniform)node_base;
            uniform_name := read_uniform_node.uniform;
            if uniform_name {
                val := get_bind_val_ptr(uniform_name);
                if val {
                    print("%: %\n", uniform_name, << val);
                } else {
                    print("%: null\n", uniform_name);
                }
            } else {
                Log.warning();
                Log.print("Read_Uniform node has no uniform name");
            }
        case Use_Program;
            old_program := state.current_program;
            state.current_program = cast(*Use_Program)node_base;
            defer state.current_program = old_program;
            
            render_children(node_base);
        case Group; render_children(node_base);
        case Sprite; render_children(node_base);
        case Rect; render_children(node_base);
        case Circle; render_children(node_base);

        case;
            panic("unknown entity type %\n", node_base.type);
    }
}

num_elems_per_primitive :: (primitive_type: Primitive) -> int {
    if primitive_type == {
        case Primitive.Triangles; return 3;
        case Primitive.Points;    return 1;
    }

    panic("unimplemented primitve type %", primitive_type);
    return 0;
}

get_or_make_cached_pipeline :: (pipeline_desc: sg_pipeline_desc) -> sg_pipeline {
    using state;
    for * cached_pipelines {
        bytes_to_compare :: size_of(sg_pipeline_desc)
                            - size_of(*u8)  // we don't want to compare labels
                            - size_of(u32); // or the end canary

        if memcmp(*it.desc, *pipeline_desc, bytes_to_compare) == 0
            return it.pipeline;
    }

    print("making pipeline %\n", pipeline_desc);
    pipeline := sg_make_pipeline(*pipeline_desc);

    array_reserve(*cached_pipelines, cached_pipelines.count + 1);
    cached_pipelines[cached_pipelines.count].pipeline = pipeline;
    cached_pipelines[cached_pipelines.count].desc = pipeline_desc;
    cached_pipelines.count += 1;

    return pipeline;
}

render_draw_node :: (draw_node: *Draw) {
    if state.current_program == null || state.current_program.shader == null {
        Log.warning();
        Log.print("Not drawing because no shader is set");
        return;
    }

    has_index_buffer := false;
    {
        using state.current_program.shader;

        index_type: sg_index_type;
        if draw_node.index_buffer.data.count != 0 {
            if draw_node.index_buffer.type == {
                case Buffer_Type.U16_Elems; index_type = sg_index_type.UINT16;
                case Buffer_Type.U32_Elems; index_type = sg_index_type.UINT32;
                case Buffer_Type.Vector2;
                    panic("unimplemented index buffer type %\n", draw_node.index_buffer.type);
                    index_type = sg_index_type.UINT16;
            }
        }
    }

    pip_desc: sg_pipeline_desc;
    cached_pipeline := get_or_make_cached_pipeline(pip_desc);

    using state.current_program.shader;

    // set uniforms
    {
        // TODO: multiple uniform blocks
        // TODO: think about how to cache whether a set of uniforms is
        //       "dirty" or not.
        apply_uniforms(sg_shader_stage.FS, 0, desc.fs.uniform_blocks[0]);
        apply_uniforms(sg_shader_stage.VS, 0, desc.vs.uniform_blocks[0]);
    }

    current_bindings: sg_bindings;
    num_elems: int = -1;
    if has_index_buffer {
        num_elems = draw_node.num_elements; // TODO: don't store on the node
    }

    {
        // bind vertex inputs
        for * reflection_info.inputs {
            name, location_idx := it.name, it.location;
            val := get_bind_val_ptr(name, Buffer);
            if !val {
                buf, buf_ok := as_sg_buffer(val);
                if buf_ok {
                    current_bindings.vertex_buffers[location_idx] = buf;
                    if location_idx == 0 && !has_index_buffer {
                        num_elems = num_elements(<<val) / num_elems_per_primitive(draw_node.primitive);
                    }
                    continue;
                }
            }
        }

        // bind images
        for * reflection_info.images {
            sg_img, ok := get_current_bind_sg_image(it.name);
            if !ok continue;
            if it.shader_type == {
                case Shader_Type.Vertex;   current_bindings.vs_images[it.binding] = sg_img;
                case Shader_Type.Fragment; current_bindings.fs_images[it.binding] = sg_img;
            }
        }
    }


}

get_current_bind_sg_image :: (name: string) -> (sg_image, bool) {
    val := get_bind_val_ptr(name, Image);
    if val {
        img, img_ok := as_sg_image(val);
        if img_ok return img, true;
    }

    img := get_placeholder_image(Placeholder_Image_Type.WHITE);
    sg_img := _ensure_image_created(*img);
    return sg_img, true;
}


get_bind_val_ptr :: (name: string) -> *Shader_Value {
    for < * state.current_bind_values
        if it.name == name
            return *it.value;

    return null;
}

get_bind_val_ptr :: (name: string, $T: Type) -> *T {
    for < * state.current_bind_values {
        if it.name == name {
            val := it.value.try_get_ptr(*it.value, T);
            if val != null return val;
            print("warning: asked for shader val % with type % but it is %",
                name, T, it.value.type);
        }
    }

    return null;
}

init_cb :: () {
    // initialize sokol_gfx
    desc: sg_desc;
    {
        using desc;
		mtl_device                   = sapp_metal_get_device();
		mtl_renderpass_descriptor_cb = sapp_metal_get_renderpass_descriptor;
		mtl_drawable_cb              = sapp_metal_get_drawable;
		d3d11_device                 = sapp_d3d11_get_device();
		d3d11_device_context         = sapp_d3d11_get_device_context();
		d3d11_render_target_view_cb  = sapp_d3d11_get_render_target_view;
		d3d11_depth_stencil_view_cb  = sapp_d3d11_get_depth_stencil_view;
    }
    sg_setup(*desc);

    // initialize sokol_time
    stm_setup();

    // setup initial clear color
    {
        using state.pass_action.colors[0];
        action = sg_action.CLEAR;
        memcpy(*val[0], *state.window.clear_color, size_of(Vector4));
    }

    // init default P (projection) and MV (model-view) matrices
    {
        mv: Shader_Value_Entry;
        mv.name = "MV";
        mv.value.set(*mv.value, matrix4_identity());

        p: Shader_Value_Entry;
        p.name = "P";
        p.value.set(*p.value, get_win_projection());
        
        array_add(*state.current_bind_values, mv, p);
    }

}

get_win_projection :: () -> Matrix4 {
    w2, h2 := cast(float)(state.window.width / 2), cast(float)(state.window.height / 2);
    return orthographic_projection_matrix(-w2, w2, -h2, h2, -10, 10); 
}

_ensure_buffer_created :: (using buf: *Buffer, index: bool = false) -> sg_buffer {
    // TODO: check buffer status
    assert(pool_id != 0, "buffer was not created");
    pool_entry := *state.native_buffer_pool[pool_id];
    assert(pool_entry.occupied == true);

    if pool_entry.sg_obj.id == 0 {
        if verbose_mode() print("creating buffer for pool_id %\n", pool_id);
        buf_desc: sg_buffer_desc;
        {
            using buf_desc;
            type = ifx index then sg_buffer_type.INDEXBUFFER else sg_buffer_type.VERTEXBUFFER;
            size = cast(s32)data.count;
            usage = _get_sg_usage(pool_entry.usage);
            content = ifx pool_entry.usage == Resource_Usage.Immutable then *data[0] else null;
            label = "generated-buffer"; // TODO: better names would be nice
        }
        pool_entry.sg_obj = sg_make_buffer(*buf_desc);

        if pool_entry.usage != Resource_Usage.Immutable && data.count != 0 {
            sg_update_buffer(pool_entry.sg_obj, *data[0], cast(s32)data.count);
        }

        if verbose_mode() {
            print("create % buffer of size % with sg id %\n", (ifx index then "index" else "vertex"), data.count, pool_entry.sg_obj.id);
        }
    }

    return pool_entry.sg_obj;
}

_get_sg_usage :: (usage: Resource_Usage) -> sg_usage {
    if usage == {
        case Resource_Usage.Immutable; return sg_usage.IMMUTABLE;
        case Resource_Usage.Dynamic;   return sg_usage.DYNAMIC;
        case Resource_Usage.Stream;    return sg_usage.STREAM;
    }

    panic("unknown resource usage %", usage);
    return sg_usage.IMMUTABLE;
}


as_sg_buffer :: (val: *Buffer) -> (sg_buffer, bool) {
    if val == null {
        empty: sg_buffer;
        return empty, false;
    }
    return _ensure_buffer_created(val), true;
}


as_sg_image :: (val: *Image) -> (sg_image, bool) {
    if val == null {
        img: sg_image;
        return img, false;
    }

    return _ensure_image_created(val), true;
}

cleanup :: () {
    sg_shutdown();
}

frame :: () {
    // update
    {
        current_ticks := stm_now();

        using state;
        last_frame_time = frame_time;
        frame_time = stm_sec(current_ticks);
        delta_time = cast(float)(frame_time - last_frame_time);
        frame_count += 1;
        // TODO: consider a "FixedUpdate" type loop (in addition?)
    }

    // draw
    {
        win := state.window;

        {
            sg_begin_default_pass(*state.pass_action, sapp_width(), sapp_height());
            defer sg_end_pass();

            if win.scene
                render_node(win.scene);
        }
        sg_commit();

        for i: 0..2
            win.mouse_button_state[i].last = win.mouse_button_state[i].current;
    }
}

event :: (event: *sapp_event) {
    //print("% %\n", state.frame_count, <<event);
}

host_main :: () {
    print("Hello, om!\n");

    // We provide #c_call functions to sokol, and use its "userdata" pointer
    // to get our Context through.
    app_desc: sapp_desc;
    {
        using app_desc;
        init_userdata_cb = (userdata: *void) #c_call {
            push_context <<(cast(*Context)userdata) {  init_cb(); }
        };
        frame_userdata_cb = (userdata: *void) #c_call {
            push_context <<(cast(*Context)userdata) {  frame(); }
        };
        event_userdata_cb = (e: *sapp_event, userdata: *void) #c_call {
            push_context <<(cast(*Context)userdata) {  event(e); }
        };
        cleanup_userdata_cb = (userdata: *void) #c_call {
            push_context <<(cast(*Context)userdata) { cleanup(); }
        };
        width = 1280;
        height = 720;
        user_data = *context;
        sample_count = 4;
        fullscreen = false;
        high_dpi = true;
    }
    sapp_run(*app_desc);

    print("finished.\n");
}
