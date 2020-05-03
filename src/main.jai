Debug :: #import "Debug";

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
    //Debug.init();

    // TODO: get jai to let us initialize globals with constant values
    _init_colors();
    _init_blend_states();

    example_rect();
    host_main();
}
