#import "Basic";
#import "Math";

#import "Sokol_Gfx";
#import "Sokol_App";
#import "Sokol_Time";


state: struct {
    last_frame_time: float64;
    frame_time: float64;
    delta_time: float;
    frame_count: u64;

    current_program: *Use_Program;
    current_bind_values: [..]Shader_Value_Entry;
    current_blend: sg_blend_state;
};

init :: () {
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

    stm_setup();
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
    }
}

event :: (event: *sapp_event) {
    print("% %\n", state.frame_count, <<event);
}

host_main :: () {
    print("Hello, om!\n");

    // We provide #c_call functions to sokol, and use its "userdata" pointer
    // to get our Context through.
    app_desc: sapp_desc;
    {
        using app_desc;
        init_userdata_cb = (userdata: *void) #c_call {
            push_context <<(cast(*Context)userdata) {  init(); }
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
    }
    sapp_run(*app_desc);

    print("finished.\n");
}