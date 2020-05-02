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

    shader_cache: struct {
        _color2d: *Shader;
        _texture2d: *Shader;
    };
};

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
        case Group; render_children(node_base);
        case Sprite; render_children(node_base);
        case Rect; render_children(node_base);
        case Circle; render_children(node_base);

        case;
            panic("unknown entity type %", node_base.type);
    }
}

render_draw_node :: (draw_node: *Draw) {

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