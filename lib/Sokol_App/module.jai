#if OS_WINDOWS {
    #foreign_system_library "d3d11";
    #foreign_system_library "dxguid";
    #foreign_system_library "user32";
    sapp_lib :: #foreign_library,no_dll "win/sokol_app_d3d11";
}

SAPP_MAX_TOUCHPOINTS :: 8;
SAPP_MAX_MOUSEBUTTONS :: 3;
SAPP_MAX_KEYCODES :: 512;

sapp_event_type :: enum u32 {
    INVALID;
    KEY_DOWN;
    KEY_UP;
    CHAR;
    MOUSE_DOWN;
    MOUSE_UP;
    MOUSE_SCROLL;
    MOUSE_MOVE;
    MOUSE_ENTER;
    MOUSE_LEAVE;
    TOUCHES_BEGAN;
    TOUCHES_MOVED;
    TOUCHES_ENDED;
    TOUCHES_CANCELLED;
    RESIZED;
    ICONIFIED;
    RESTORED;
    SUSPENDED;
    RESUMED;
    UPDATE_CURSOR;
    QUIT_REQUESTED;
    CLIPBOARD_PASTED;
    _SAPP_EVENTTYPE_NUM;
    _SAPP_EVENTTYPE_FORCE_U32 :: 0x7FFFFFFF;
}

/* key codes are the same names and values as GLFW */
sapp_keycode :: enum u32 {
    INVALID          :: 0;
    SPACE            :: 32;
    APOSTROPHE       :: 39;  /* ' */
    COMMA            :: 44;  /* , */
    MINUS            :: 45;  /* - */
    PERIOD           :: 46;  /* . */
    SLASH            :: 47;  /* / */
    _0                :: 48;
    _1                :: 49;
    _2                :: 50;
    _3                :: 51;
    _4                :: 52;
    _5                :: 53;
    _6                :: 54;
    _7                :: 55;
    _8                :: 56;
    _9                :: 57;
    SEMICOLON        :: 59;  /* ; */
    EQUAL            :: 61;  /* = */
    A                :: 65;
    B                :: 66;
    C                :: 67;
    D                :: 68;
    E                :: 69;
    F                :: 70;
    G                :: 71;
    H                :: 72;
    I                :: 73;
    J                :: 74;
    K                :: 75;
    L                :: 76;
    M                :: 77;
    N                :: 78;
    O                :: 79;
    P                :: 80;
    Q                :: 81;
    R                :: 82;
    S                :: 83;
    T                :: 84;
    U                :: 85;
    V                :: 86;
    W                :: 87;
    X                :: 88;
    Y                :: 89;
    Z                :: 90;
    LEFT_BRACKET     :: 91;  /* [ */
    BACKSLASH        :: 92;  /* \ */
    RIGHT_BRACKET    :: 93;  /* ] */
    GRAVE_ACCENT     :: 96;  /* ` */
    WORLD_1          :: 161; /* non-US #1 */
    WORLD_2          :: 162; /* non-US #2 */
    ESCAPE           :: 256;
    ENTER            :: 257;
    TAB              :: 258;
    BACKSPACE        :: 259;
    INSERT           :: 260;
    DELETE           :: 261;
    RIGHT            :: 262;
    LEFT             :: 263;
    DOWN             :: 264;
    UP               :: 265;
    PAGE_UP          :: 266;
    PAGE_DOWN        :: 267;
    HOME             :: 268;
    END              :: 269;
    CAPS_LOCK        :: 280;
    SCROLL_LOCK      :: 281;
    NUM_LOCK         :: 282;
    PRINT_SCREEN     :: 283;
    PAUSE            :: 284;
    F1               :: 290;
    F2               :: 291;
    F3               :: 292;
    F4               :: 293;
    F5               :: 294;
    F6               :: 295;
    F7               :: 296;
    F8               :: 297;
    F9               :: 298;
    F10              :: 299;
    F11              :: 300;
    F12              :: 301;
    F13              :: 302;
    F14              :: 303;
    F15              :: 304;
    F16              :: 305;
    F17              :: 306;
    F18              :: 307;
    F19              :: 308;
    F20              :: 309;
    F21              :: 310;
    F22              :: 311;
    F23              :: 312;
    F24              :: 313;
    F25              :: 314;
    KP_0             :: 320;
    KP_1             :: 321;
    KP_2             :: 322;
    KP_3             :: 323;
    KP_4             :: 324;
    KP_5             :: 325;
    KP_6             :: 326;
    KP_7             :: 327;
    KP_8             :: 328;
    KP_9             :: 329;
    KP_DECIMAL       :: 330;
    KP_DIVIDE        :: 331;
    KP_MULTIPLY      :: 332;
    KP_SUBTRACT      :: 333;
    KP_ADD           :: 334;
    KP_ENTER         :: 335;
    KP_EQUAL         :: 336;
    LEFT_SHIFT       :: 340;
    LEFT_CONTROL     :: 341;
    LEFT_ALT         :: 342;
    LEFT_SUPER       :: 343;
    RIGHT_SHIFT      :: 344;
    RIGHT_CONTROL    :: 345;
    RIGHT_ALT        :: 346;
    RIGHT_SUPER      :: 347;
    MENU             :: 348;
}

sapp_touchpoint :: struct {
    identifier: *void;
    pos_x: float;
    pos_y: float;
    changed: bool;
}

sapp_mousebutton :: enum s32 {
    SAPP_MOUSEBUTTON_INVALID :: -1;
    SAPP_MOUSEBUTTON_LEFT    :: 0;
    SAPP_MOUSEBUTTON_RIGHT   :: 1;
    SAPP_MOUSEBUTTON_MIDDLE  :: 2;
}

SAPP_MODIFIER_SHIFT :: (1<<0);
SAPP_MODIFIER_CTRL :: (1<<1);
SAPP_MODIFIER_ALT :: (1<<2);
SAPP_MODIFIER_SUPER :: (1<<3);

sapp_event :: struct {
    frame_count: u64;
    type: sapp_event_type;
    key_code: sapp_keycode;
    char_code: u32;
    key_repeat: bool;
    modifiers: u32;
    mouse_button: sapp_mousebutton;
    mouse_x: float;
    mouse_y: float;
    scroll_x: float;
    scroll_y: float;
    num_touches: s32;
    touches: [SAPP_MAX_TOUCHPOINTS]sapp_touchpoint;
    window_width: s32;
    window_height: s32;
    framebuffer_width: s32;
    framebuffer_height: s32;
}

sapp_desc :: struct {
    init_cb: () #c_call;                    /* these are the user-provided callbacks without user data */
    frame_cb: () #c_call;
    cleanup_cb: () #c_call;
    event_cb: (*sapp_event) #c_call;
    fail_cb: () #c_call;

    user_data: *void;                        /* these are the user-provided callbacks with user data */
    init_userdata_cb: (*void) #c_call;
    frame_userdata_cb: (*void) #c_call;
    cleanup_userdata_cb: (*void) #c_call;
    event_userdata_cb: (*sapp_event, *void) #c_call;
    fail_userdata_cb: (*u8, *void) #c_call;

    width: s32;                          /* the preferred width of the window / canvas */
    height: s32;                         /* the preferred height of the window / canvas */
    sample_count: s32;                   /* MSAA sample count */
    swap_interval: s32;                  /* the preferred swap interval (ignored on some platforms) */
    high_dpi: bool;                      /* whether the rendering canvas is full-resolution on HighDPI displays */
    fullscreen: bool;                    /* whether the window should be created in fullscreen mode */
    alpha: bool;                         /* whether the framebuffer should have an alpha channel (ignored on some platforms) */
    window_title: *u8;           /* the window title as UTF-8 encoded string */
    user_cursor: bool;                   /* if true, user is expected to manage cursor image in SAPP_EVENTTYPE_UPDATE_CURSOR */
    enable_clipboard: bool;              /* enable clipboard access, default is false */
    clipboard_size: s32;                 /* max size of clipboard content in bytes */

    html5_canvas_name: *u8;      /* the name (id) of the HTML5 canvas element, default is "canvas" */
    html5_canvas_resize: bool;           /* if true, the HTML5 canvas size is set to sapp_desc.width/height, otherwise canvas size is tracked */
    html5_preserve_drawing_buffer: bool; /* HTML5 only: whether to preserve default framebuffer content between frames */
    html5_premultiplied_alpha: bool;     /* HTML5 only: whether the rendered pixels use premultiplied alpha convention */
    html5_ask_leave_site: bool;          /* initial state of the internal html5_ask_leave_site flag (see sapp_html5_ask_leave_site()) */
    ios_keyboard_resizes_canvas: bool;   /* if true, showing the iOS keyboard shrinks the canvas */
    gl_force_gles2: bool;                /* if true, setup GLES2/WebGL even if GLES3/WebGL2 is available */
}

/* user-provided functions */
//extern sapp_desc sokol_main(int argc, char* argv[]);

/* returns true after sokol-app has been initialized */
sapp_isvalid :: () -> bool #foreign sapp_lib;
/* returns the current framebuffer width in pixels */
sapp_width :: () -> s32 #foreign sapp_lib;
/* returns the current framebuffer height in pixels */
sapp_height :: () -> s32 #foreign sapp_lib;
/* returns true when high_dpi was requested and actually running in a high-dpi scenario */
sapp_high_dpi :: () -> bool #foreign sapp_lib;
/* returns the dpi scaling factor (window pixels to framebuffer pixels) */
sapp_dpi_scale :: () -> float #foreign sapp_lib;
/* show or hide the mobile device onscreen keyboard */
sapp_show_keyboard :: (visible: bool) #foreign sapp_lib;
/* return true if the mobile device onscreen keyboard is currently shown */
sapp_keyboard_shown :: () -> bool #foreign sapp_lib;
/* show or hide the mouse cursor */
sapp_show_mouse :: (visible: bool) #foreign sapp_lib;
/* show or hide the mouse cursor */
sapp_mouse_shown :: () -> bool #foreign sapp_lib;
/* put relative mouse movement into x and y */
sapp_get_relative_mouse :: (x: *s32, y: *s32) #foreign sapp_lib;
/* return the userdata pointer optionally provided in sapp_desc */
sapp_userdata :: () -> *void #foreign sapp_lib;
/* return a copy of the sapp_desc structure */
sapp_query_desc :: () -> sapp_desc #foreign sapp_lib;
/* initiate a "soft quit" (sends SAPP_EVENTTYPE_QUIT_REQUESTED) */
sapp_request_quit :: () #foreign sapp_lib;
/* cancel a pending quit (when SAPP_EVENTTYPE_QUIT_REQUESTED has been received) */
sapp_cancel_quit :: () #foreign sapp_lib;
/* intiate a "hard quit" (quit application without sending SAPP_EVENTTYPE_QUIT_REQUSTED) */
sapp_quit :: () #foreign sapp_lib;
/* call from inside event callback to consume the current event (don't forward to platform) */
sapp_consume_event :: () #foreign sapp_lib;
/* get the current frame counter (for comparison with sapp_event.frame_count) */
sapp_frame_count :: () -> u64 #foreign sapp_lib;
/* write string into clipboard */
sapp_set_clipboard_string :: (str: *u8) #foreign sapp_lib;
/* read string from clipboard (usually during SAPP_EVENTTYPE_CLIPBOARD_PASTED) */
sapp_get_clipboard_string :: () -> *u8 #foreign sapp_lib;

/* special run-function for SOKOL_NO_ENTRY (in standard mode this is an empty stub) */
sapp_run :: (desc: *sapp_desc) -> s32 #foreign sapp_lib;

/* GL: return true when GLES2 fallback is active (to detect fallback from GLES3) */
sapp_gles2 :: () -> bool #foreign sapp_lib;

/* HTML5: enable or disable the hardwired "Leave Site?" dialog box */
sapp_html5_ask_leave_site :: (ask: bool) #foreign sapp_lib;

/* Metal: get ARC-bridged pointer to Metal device object */
sapp_metal_get_device :: () -> *void #foreign sapp_lib;
/* Metal: get ARC-bridged pointer to this frame's renderpass descriptor */
sapp_metal_get_renderpass_descriptor :: () -> *void #foreign sapp_lib;
/* Metal: get ARC-bridged pointer to current drawable */
sapp_metal_get_drawable :: () -> *void #foreign sapp_lib;
/* macOS: get ARC-bridged pointer to macOS NSWindow */
sapp_macos_get_window :: () -> *void #foreign sapp_lib;
/* iOS: get ARC-bridged pointer to iOS UIWindow */
sapp_ios_get_window :: () -> *void #foreign sapp_lib;

/* D3D11: get pointer to ID3D11Device object */
sapp_d3d11_get_device :: () -> *void #foreign sapp_lib;
/* D3D11: get pointer to ID3D11DeviceContext object */
sapp_d3d11_get_device_context :: () -> *void #foreign sapp_lib;
/* D3D11: get pointer to ID3D11RenderTargetView object */
sapp_d3d11_get_render_target_view :: () -> *void #foreign sapp_lib;
/* D3D11: get pointer to ID3D11DepthStencilView */
sapp_d3d11_get_depth_stencil_view :: () -> *void #foreign sapp_lib;
/* Win32: get the HWND window handle */
sapp_win32_get_hwnd :: () -> *void #foreign sapp_lib;

/* Android: get native activity handle */
sapp_android_get_native_activity :: () -> *void #foreign sapp_lib;

sapp_calloc_func :: #type (num: int, size: int) -> *void #c_call;
sapp_free_func :: #type (ptr: *void) #c_call;

sapp_set_debug_funcs :: (my_calloc: sapp_calloc_func, my_free: sapp_free_func) #foreign sapp_lib;