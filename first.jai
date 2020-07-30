#import "Basic";
#import "Compiler";

build :: () {
    set_working_directory(#filepath);

    opts := get_build_options();
    opts.output_type = Build_Output_Type.NO_OUTPUT;
    set_build_options(opts);

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        array_add(*opts.modules_search_path_array, "lib");
        opts.output_type = Build_Output_Type.EXECUTABLE;
        opts.stack_trace = true;
        set_build_options(opts, w);
        add_build_file("src/main.jai", w);

        while true {
            using Compiler_Message.Kind;
            
            message := compiler_wait_for_message();
            if !message continue;
            if message.workspace != w continue;
            if message.kind == COMPLETE break;
        }
    }
}

#run build();