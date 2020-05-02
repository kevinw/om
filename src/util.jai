#import "Debug";

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