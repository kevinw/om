#import "Basic";
#import "Sokol_Gfx";
#import "Sokol_App";

init :: () {
    print("in jai init!!!!\n");
}

frame :: () {
}

event :: (event: *sapp_event) {
    print("%\n", <<event);
}

main :: () {
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
        width = 1280;
        height = 720;
        user_data = *context;
    }
    sapp_run(*app_desc);

    print("finished.\n");
}
