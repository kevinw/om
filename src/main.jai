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

example_main :: example_sprite;

example_sprite :: () {
    window(title = "a sprite").scene = chain(
        action(rotate(0.01), (r: *Node) { set_angle(cast(*Rotate)r, cast(float)frame_time() * 0.05); }),
        sprite("examples/resources/owl.jpg"),
    );
}

example_circle :: () {
    window().scene = circle(.{0, 0}, 50, WHITE, 255);
}

example_rect :: () {
    win := window(title="A Rectangle");
    x1 := -50.0; y1 := -50.0;
    x2 := 50.0;  y2 := 50.0;
    win.scene = chain(
        use_program(shader_color2d()),
        bind(
            sv("vert", Vec2_Array(x2, y2, x2, y1, x1, y2, x1, y1)),
            sv("color", WHITE)),
        draw(.Triangles, rect_indices()),
    );
}

example_rotate :: () {
    window().scene = chain(
        rotate(rad(45)),
        rect(-100, -100, 100, 100),
    );
}

_c_context: Context;

DEBUG_STUFF_ENABLED :: true;

main :: () {
    if DEBUG_STUFF_ENABLED {
        Debug.init();
        GWP.init();
        context.allocator = GWP.allocator;
    }

    _c_context = context;

    debug_calloc :: (num: int, size: int) -> *void #c_call {
        push_context _c_context {
            ptr := alloc(num * size);
            memset(ptr, 0, num * size);
            return ptr;
        }
    }

    debug_malloc :: (bytes: int) -> *void #c_call {
        push_context _c_context { return alloc(bytes); }
    }

    debug_free :: (ptr: *void) #c_call {
        push_context _c_context { free(ptr); }
    }

    debug_assert :: (expr: *u8, filename: *u8, line_number: s32) #c_call {
        push_context _c_context {
            assert(false, tprint("expression: '%' at %:%", to_string(expr), to_string(filename), line_number));
        }
    }

    sapp_set_debug_funcs(debug_calloc, debug_free);
    sg_set_debug_funcs(debug_malloc, debug_free, debug_assert);

    /*
    sg_print_struct_sizes();
    print("------in jai:\n");
    print("%: %\n", "sg_shader_desc", size_of(sg_shader_desc));
    print("%: %\n", "sg_bindings", size_of(sg_bindings));
    print("%: %\n", "sg_pipeline_desc", size_of(sg_pipeline_desc));
    */

    // TODO: get jai to let us initialize globals with constant values
    _init_blend_states();

    example_main();
    host_main();

    print("MAIN IS DONE.\n");
}
