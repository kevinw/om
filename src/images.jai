#import "Hash_Table";
#import "stb_image";

_image_cache: Table(string, Image);

_get_cached_image_from_filename :: (filename: string) -> (Image, bool) {
    {
        img := table_find_pointer(_image_cache, filename);
        if img != null && img.pool_id != 0
            return <<img, true;
    }

    img, ok := _make_image_from_filename(filename);
    if ok {
        table_set(*_image_cache, filename, img);
        return img, true;
    }

    empty: Image;
    return empty, false;
}

_make_image_from_filename :: (filename: string) -> (Image, bool) {
    desired_channels:s32 = 4;
    width, height, channels_in_file: s32;

    c_name := to_c_string(filename);
    defer free(c_name);

    bytes := stbi_load(c_name, *width, *height, *channels_in_file, desired_channels);
    if bytes == null
        return .{}, false;
    if verbose_mode()
        print("loaded image w=% h=% channels=% from '%'\n", width, height, channels_in_file, filename);

    data: []u8;
    data.data = bytes;
    data.count = width * height * channels_in_file;

    return _make_image(cast(u16)width, cast(u16)height, data, false), true;

}

// TODO: global state
white, black, normals: Image;
did_init_placeholders := false;

get_placeholder_image :: (type: Placeholder_Image_Type) -> Image {
    if !did_init_placeholders {
        pixels: [64]u32;
        for i: 0..63 pixels[i] = 0xFFFFFFFF;
        white = _make_image(8, 8, slice_to_bytes(pixels));
        for i: 0..63 pixels[i] = 0xFF000000;
        black = _make_image(8, 8, slice_to_bytes(pixels));
        for i: 0..63 pixels[i] = 0xFFFF7FFF;
        normals = _make_image(8, 8, slice_to_bytes(pixels));
        did_init_placeholders = true;
    }

    using Placeholder_Image_Type;
    if type == {
        case WHITE;   return white;
        case BLACK;   return black;
        case NORMALS; return normals;
    }

    panic("unrecognized Placeholder_Type");

    empty: Image;
    return empty;
}