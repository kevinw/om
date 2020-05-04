#import "Debug";
#import "Text_File_Handler";

for_expansion :: (handler: *Text_File_Handler, body: Code, pointer: bool, reverse: bool) #expand {
    #assert(!pointer && !reverse);

    while true {
        line, found := consume_next_line(handler);
        if !found break;

        `it := line;
        #insert body;
    }
}


panic :: (msg: string, fmt_args: ..Any) {
    print(msg, ..fmt_args);
    abort();
}

slice_to_bytes :: (slice: []$T) -> []u8 {
    bytes: []u8;
    bytes.count = slice.count * size_of(T);
    bytes.data = cast(*u8)slice.data;
    return bytes;
}

verbose_mode :: inline () -> bool {
    if _verbose_mode == -1 {
        _verbose_mode = 0;
        for get_command_line_arguments() {
            if it == "--verbose" || it == "-v" {
                _verbose_mode = 1;
            }
        }
    }

    return  _verbose_mode == 1;
}

round_up :: (n: float) -> int {
    return cast(int)(n + 0.5);
}

// Tools for reading binary file formats.

read :: inline ($T: Type, s: *string) -> T {
    assert(s.count >= size_of(T));
    result := << cast(*T)s.data;
    advance(s, size_of(T));
    return result;
}

read_bytes :: inline (s: *string, num_bytes: int) -> string {
    assert(s.count >= num_bytes);

    new_str: string;
    new_str.data = s.data;
    new_str.count = num_bytes;
    
    advance(s, num_bytes);

    return new_str;
}


#scope_file
_verbose_mode: s8 = -1;