Debug :: #import "Debug";
GWP :: #import "gwpasan";

#load "util.jai";
#load "types.jai";
#load "host_sokol.jai";
#load "api.jai";
#load "shader.jai";
#load "builtin_shaders.jai";
#load "geometry.jai";
#load "images.jai";


example_rect :: () {
    win := window(title="A Rectangle");
    win.scene = rect(-50, -50, 50, 50, WHITE);
}

main :: () {
    Debug.init();
    GWP.init();
    context.allocator = GWP.allocator;

    debug_calloc :: (num: int, size: int) -> *void #c_call {
        ctx: Context;
        ctx.allocator = GWP.allocator;
        push_context ctx {
            ptr := alloc(num * size);
            memset(ptr, 0, num * size);
            return ptr;
        }
    }

    debug_malloc :: (bytes: int) -> *void #c_call {
        ctx: Context;
        ctx.allocator = GWP.allocator;
        push_context ctx {
            return alloc(bytes);
        }
    }

    debug_free :: (ptr: *void) #c_call {
        ctx: Context;
        ctx.allocator = GWP.allocator;
        push_context ctx {
            free(ptr);
        }
    }

    sapp_set_debug_funcs(debug_calloc, debug_free);
    sg_set_debug_funcs(debug_malloc, debug_free);

    /*
    sg_print_struct_sizes();
    print("------in jai:\n");
    print("%: %\n", "sg_shader_desc", size_of(sg_shader_desc));
    print("%: %\n", "sg_bindings", size_of(sg_bindings));
    print("%: %\n", "sg_pipeline_desc", size_of(sg_pipeline_desc));
    */

    // TODO: get jai to let us initialize globals with constant values
    _init_colors();
    _init_blend_states();

    example_rect();
    host_main();
}
