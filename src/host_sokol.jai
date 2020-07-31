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

    // state stored while rendering
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
    if block_desc.size == 0 {
        print("no uniforms for %\n", shader_stage);
        return;
    }

    using state.current_program.shader;

    uniform_bytes: []u8;
    uniform_bytes.data = talloc(block_desc.size);
    uniform_bytes.count = block_desc.size;

    {
        // put uniforms into a byte buffer
        byte_offset := 0;
        for uniform: block_desc.uniforms {
            if uniform.type == sg_uniform_type.INVALID break; // sokol's 'end of uniforms' marker
            if uniform.array_count > 1 panic("TODO: impl array_count: % % \n", uniform.array_count, to_string(uniform.name));

            uniform_name_str := to_string(uniform.name);

            val := get_bind_val_ptr(uniform_name_str); // TODO: @Speed - this is strlen everytime....doh
            if val != null {
                dst := *uniform_bytes[byte_offset];
                using val.TagType;
                if val.type == {
                    case _Vector3;
                        memcpy(dst, val, size_of(Vector3));

                        result := cast(*Vector3)dst;
                        assert(!isnan(result.x));
                        assert(!isnan(result.y));
                        assert(!isnan(result.z));

                    case _Vector4;
                        memcpy(dst, val, size_of(Vector4));

                        result := cast(*Vector4)dst;
                        assert(!isnan(result.x));
                        assert(!isnan(result.y));
                        assert(!isnan(result.z));
                        assert(!isnan(result.w));

                    case _Buffer; 
                        buf := val.try_get_ptr(val, Buffer);
                        assert(buf != null, "Expected buffer");
                        memcpy(dst, buf.data.data, buf.data.count);
                    case _Matrix4;

                        memcpy(dst, val, size_of(Matrix4));

                        result := cast(*Matrix4)dst;
                        for it, idx: result.floats
                            assert(!isnan(it), tprint("elem % of matrix % is NaN!", idx, uniform_name_str));

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
            print("created image of size % with sg id %\n", img.data.count, sg_obj);
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

LOG_NODE_RENDERS :: false;

debug_recursion_level: int = 0;

// TODO: use an explicit stack instead of recursion
render_node :: (node_base: *Node) {
    if LOG_NODE_RENDERS {
        for 0..debug_recursion_level-1
                print(" ");
            
            s := node_base.name;
            if node_base.tags.count > 0
                s = node_base.tags[0];
            print("Render '%'\n", s);
    }

    debug_recursion_level += 1;
    defer debug_recursion_level -= 1;

    if node_base.flags & Node_Flags.Hidden
        return;

    if node_base.type == {
        case Bind;
            bind := cast(*Bind)node_base;

            bind_count := state.current_bind_values.count;
            defer state.current_bind_values.count = bind_count;

            pre := state.current_bind_values.allocated;
            array_add(*state.current_bind_values, ..bind.values);
            assert(pre == state.current_bind_values.allocated);

            render_children(node_base);
        case Draw;
            if state.current_program == null {
                Log.warning(); Log.print("Error: cannot draw, there is no active program.\n");
                return;
            }
            render_draw_node(cast(*Draw)node_base);
            render_children(node_base); // TODO: maybe draw nodes should warn if they have children?

        case Scale;
            scale_node := cast(*Scale)node_base;

            mv := get_bind_val_ptr("MV", Matrix4);

            x := mv.v[0].x;
            y := mv.v[1].y;
            z := mv.v[2].z;

            mv.v[0].x *= scale_node.scale.x;
            mv.v[1].y *= scale_node.scale.y;
            mv.v[2].z *= scale_node.scale.z;

            render_children(node_base);

            assert(mv == get_bind_val_ptr("MV", Matrix4));
            mv.v[0].x = x;
            mv.v[1].y = y;
            mv.v[2].z = z;

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

            mv.v[0].z += translate_node.offset.x;
            mv.v[1].z += translate_node.offset.y;
            mv.v[2].z += translate_node.offset.z;

            render_children(node_base);

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
            assert(state.current_program.shader != null);
            defer state.current_program = old_program;
            
            render_children(node_base);

        case Group;  render_children(node_base);
        case Sprite; render_children(node_base);
        case Rect;   render_children(node_base);
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

        if 0 == memcmp(*it.desc, *pipeline_desc, bytes_to_compare)
            return it.pipeline;
    }

    //print("making pipeline %\n", formatStruct(pipeline_desc, use_newlines_if_more_than_this_many_members=0));
    //print("attrs: \n");
    //for pipeline_desc.layout.attrs {
        //if it.format == .INVALID break;
        //print("  %\n", it);
    //}

    pipeline := sg_make_pipeline(*pipeline_desc);

    array_resize(*cached_pipelines, cached_pipelines.count + 1);
    cached_pipelines[cached_pipelines.count - 1].pipeline = pipeline;
    cached_pipelines[cached_pipelines.count - 1].desc = pipeline_desc;

    return pipeline;
}

shader_is_valid :: (shader: sg_shader) -> bool {
    return shader.id != 0;
}

strip_line_directives :: (s: string) -> string {
    builder: String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);
    for line: String.split(s, "\n") {
        if String.begins_with(line, "#line ") continue;
        print_to_builder(*builder, "%\n", line);
    }
    return builder_to_string(*builder);
}

assert_no_null_bytes :: (s: string) {
    i := 0;
    while i < s.count {
        ch := s.data + i;
        assert(<<ch != #char "\0");
        i += 1;
    }
}

_ensure_shader_loaded :: (shader: *Shader) {
    //Log.print("_ensure_shader_loaded %\n", shader);
    assert(shader != null);

    if shader_is_valid(shader.native_shader)
        return; // already loaded this shader

    // TODO: @Speed just allocate the original strings with null bytes!
    vert_shader_no_lines := strip_line_directives(shader.vert);
    frag_shader_no_lines := strip_line_directives(shader.frag);

    assert_no_null_bytes(vert_shader_no_lines);
    assert_no_null_bytes(frag_shader_no_lines);

    /*
    print("~~~~VERT\n");
    print(vert_shader_no_lines);
    print("~~~~~~~\n");
    print("~~~~FRAG\n");
    print(frag_shader_no_lines);
    */

    shader.desc.vs.source = to_c_string(vert_shader_no_lines); // @Leak. use temp allocator
    shader.desc.fs.source = to_c_string(frag_shader_no_lines);

    /*
    print("vs.images\n");
    for shader.desc.vs.images
        print("   %\n", it);
    print("fs.images\n");
    for shader.desc.fs.images
        print("   %\n", it);
    */

    assert(shader.native_shader.id == 0);
    shader.native_shader = sg_make_shader(*shader.desc);
    assert(shader.native_shader.id != 0);

    state := sg_query_shader_state(shader.native_shader);
    if state != sg_resource_state.VALID {
        Log.warning();
        Log.print("shader creation failed %\n", state);
    }
}

buffer_type_to_sg_vertex_format :: (buf_type: Buffer_Type) -> sg_vertex_format {
    if buf_type == {
        case .Float;   return .FLOAT;
        case .Vector2; return .FLOAT2;
        case .Vector3; return .FLOAT3;
        case .Vector4; return .FLOAT4;
        case;
            panic("TODO: implement buffer_type_to_sg_vertex_format for '%'\n", buf_type);
    }

    return .INVALID;
}

render_draw_node :: (draw_node: *Draw) {
    if state.current_program == null || state.current_program.shader == null {
        Log.warning();
        Log.print("Not drawing because no shader is set");
        return;
    }

    has_index_buffer := false;
    index_type: sg_index_type;
    {
        using state.current_program.shader;

        if draw_node.index_buffer.data.count != 0 {
            has_index_buffer = true;
            if draw_node.index_buffer.type == {
                case .U16_Elems; index_type = .UINT16;
                case .U32_Elems; index_type = .UINT32;
                case .Vector2;
                    panic("unimplemented index buffer type %\n", draw_node.index_buffer.type);
                    index_type = sg_index_type.UINT16;
            }
        }
    }
    assert(state.current_program != null && state.current_program.shader != null);
    _ensure_shader_loaded(state.current_program.shader);
    using state.current_program.shader;

    current_bindings: sg_bindings;
    num_elems: int = -1;
    if has_index_buffer {
        num_elems = draw_node.num_elements; // TODO: don't store on the node
    }

    pip_desc: sg_pipeline_desc;
    {
        pip_desc.shader = native_shader;
        pip_desc.primitive_type = cast(sg_primitive_type)draw_node.primitive;
        pip_desc.label = "generated-pipeline"; // TODO: use shader name!?
        //print("in pipeline construction, has_index_buffer: %, index_type: %\n", has_index_buffer, index_type);
        if has_index_buffer
            pip_desc.index_type = index_type;
        memset(*pip_desc.depth_stencil, 0, size_of(type_of(pip_desc.depth_stencil)));
        pip_desc.blend = state.current_blend;
    }

    {
        // bind vertex inputs
        vert_buf_count := 0;
        for * reflection_info.inputs {
            name, location_idx := it.name, it.location;
            val := get_bind_val_ptr(name, Buffer);
            //print("looking up buffer %: %\n", name, val);
            if !val {
                print("warning: expected a shader value with name '%' for an input vertex buffer\n", name);
                continue;
            }
            buf, buf_ok := as_sg_buffer(val);
            if !buf_ok continue;

            current_bindings.vertex_buffers[location_idx] = buf;
            //print("binding vert buffer with location % to %\n", location_idx, val.data.data);
            if location_idx == 0 && !has_index_buffer {
                elements_in_index_buffer := num_elements(<<val);
                elems_per_prim := num_elems_per_primitive(draw_node.primitive);
                print("elements in index buffer: %, elems_per_prim: % %", elements_in_index_buffer, elems_per_prim, draw_node.primitive);
                num_elems = elements_in_index_buffer / elems_per_prim;
            }

            // here we describe the position and type of our input vertex buffers
            // for the pipeline.
            pip_desc.layout.attrs[vert_buf_count].buffer_index = cast(s32)location_idx;
            //print("Vert buffer #% is buffer location %\n", location_idx);
            pip_desc.layout.attrs[vert_buf_count].offset = 0;
            pip_desc.layout.attrs[vert_buf_count].format = buffer_type_to_sg_vertex_format(val.type);
            vert_buf_count += 1;
            if vert_buf_count >= SG_MAX_VERTEX_ATTRIBUTES panic("too many vertex buffers");

            continue;
        }

        // bind images
        for * reflection_info.images {
            sg_img, ok := get_current_bind_sg_image(it.name);
            if !ok continue;
            if it.shader_type == {
                case Shader_Type.Vertex;   current_bindings.vs_images[it.binding] = sg_img;
                case Shader_Type.Fragment; current_bindings.fs_images[it.binding] = sg_img;
                case; panic("unknown shader type %\n", it.shader_type);
            }
        }
    }

    // Get or create a cached pipeline, and apply it.
    cached_pipeline := get_or_make_cached_pipeline(pip_desc);
    sg_apply_pipeline(cached_pipeline);

    // Set uniforms
    {
        // TODO: multiple uniform blocks
        // TODO: think about how to cache whether a set of uniforms is
        //       "dirty" or not.
        apply_uniforms(sg_shader_stage.FS, 0, desc.fs.uniform_blocks[0]);
        apply_uniforms(sg_shader_stage.VS, 0, desc.vs.uniform_blocks[0]);
    }

    if has_index_buffer && draw_node.index_buffer.pool_id != 0 {
        current_bindings.index_buffer = _ensure_buffer_created(buf=*draw_node.index_buffer, index=true);
    }

    assert(num_elems > 0);
    //print("applying bindings: %\n", current_bindings);
    //print("vs_images:\n");
    //for current_bindings.vs_images print("   %", it);
    //print("\n");
    //print("fs_images:\n");
    //for current_bindings.fs_images print("   %", it);
    //print("\n");
    sg_apply_bindings(*current_bindings);
    sg_draw(0, cast(s32)num_elems, 1);
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

    array_reserve(*state.current_bind_values, 20);

    // init default P (projection) and MV (model-view) matrices
    {
        mv: Shader_Value_Entry;
        mv.name = "MV";
        mv.value.set(*mv.value, matrix4_identity());

        p: Shader_Value_Entry;
        p.name = "P";

        proj_mat := get_win_projection();
        for proj_mat.floats assert(!isnan(it));
        p.value.set(*p.value, proj_mat);
        
        array_add(*state.current_bind_values, mv, p);
    }
}

get_win_projection :: () -> Matrix4 {
    assert(state.window.width > 0 && state.window.height > 0);
    w, h := cast(float)state.window.width, cast(float)state.window.height;
    w2, h2 := w/2, h/2;
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

        buffer_content: *void = null;
        if pool_entry.usage == Resource_Usage.Immutable {
            buffer_content = data.data;
            //print("buffer content: ");
            //for data
                //print("%02x ", it);
            //print("\n");
        }

        {
            using buf_desc;
            type = ifx index then sg_buffer_type.INDEXBUFFER else sg_buffer_type.VERTEXBUFFER;
            size = cast(s32)data.count;
            usage = _get_sg_usage(pool_entry.usage);
            content = buffer_content;
            label = "generated-buffer"; // TODO: better names would be nice
            if verbose_mode() print("%", buf_desc);
        }
        pool_entry.sg_obj = sg_make_buffer(*buf_desc);

        if pool_entry.usage != Resource_Usage.Immutable && data.count != 0 {
            sg_update_buffer(pool_entry.sg_obj, data.data, cast(s32)data.count);
        }

        if verbose_mode() {
            print("create % buffer of size % with sg id %\n", (ifx index then "index" else "vertex"), data.count, pool_entry.sg_obj);
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

callback_context: Context;

host_main :: () {
    callback_context = context;

    // We provide #c_call functions to sokol, and use its "userdata" pointer
    // to get our Context through.
    app_desc: sapp_desc;
    {
        using app_desc;
        init_userdata_cb = (userdata: *void) #c_call {
            push_context callback_context { init_cb(); }
        };
        frame_userdata_cb = (userdata: *void) #c_call {
            push_context callback_context { frame(); }
        };
        event_userdata_cb = (e: *sapp_event, userdata: *void) #c_call {
            push_context callback_context { event(e); }
        };
        cleanup_userdata_cb = (userdata: *void) #c_call {
            push_context callback_context { cleanup(); }
        };
        width = state.window.width;
        height = state.window.height;
        user_data = *callback_context;
        sample_count = 4;
        fullscreen = false;
        high_dpi = true;
    }

    sapp_run(*app_desc);
}
