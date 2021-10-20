#import "Basic";
#import "Compiler";

build :: () {
    set_working_directory(#filepath);

    set_build_options_dc(.{do_output=false});
    opts := get_build_options();

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        import_path: [..]string;
        for opts.import_path
            array_add(*import_path, it);
        array_add(*import_path, "lib");

        opts.import_path = import_path;
        opts.output_type = .EXECUTABLE;
        opts.stack_trace = true;
        set_build_options(opts, w);
        add_build_file("src/main.jai", w);

        while true {
            message := compiler_wait_for_message();
            if !message continue;
            if message.workspace != w continue;
            if message.kind == .COMPLETE break;
        }
    }
}

#run build();
