window :: (title: string) -> *Window {
    if state.window != null
        panic("You cannot create more than one window!");

    win := new(Window);
    win.title = title;

    state.window = win;

    return win;
}

bind :: (values: []Shader_Value_Entry) -> *Bind {
    bind_node := new_node_with_tag(Bind, "bind");
    array_add(*bind_node.values, ..values);
    return bind_node;
}

rect :: (x1: float, y1: float, x2: float, y2: float) -> *Rect {
    return rect(x1, y1, x2, y2, WHITE);
}

_make_buffer :: (vec: []$V, type: Buffer_Type) -> Buffer {
    buf: Buffer;
    buf.data = slice_to_bytes(vec);
    buf.type = type;
    buf.pool_id = next_free_native_buffer_id();
    return buf;
}


// TODO: this should not be an API function. instead, _make_buffer should be? or can we export different kinds
// of buffer constructor functions?
next_free_native_buffer_id :: () -> u16 {
    for *entry, index: state.native_buffer_pool {
        if index == 0 continue;
        if !entry.occupied {
            entry.occupied = true;
            return cast(u16)index;
        }
    }

    panic("native buffer pool exhausted");
    return 0;
}

// TODO: this should not be an API function. instead, _make_buffer should be? or can we export different kinds
// of buffer constructor functions?
next_free_native_image_id :: () -> u16 {
    for *entry, index: state.native_image_pool {
        if index == 0 continue;
        if !entry.occupied {
            entry.occupied = true;
            return cast(u16)index;
        }
    }
    panic("native image pool exhausted");
    return 0;
}


Vec2_Array :: (vec2s: ..Vector2) -> Buffer {
    return _make_buffer(vec2s, Buffer_Type.Vector2);
}

rect :: (x1: float, y1: float, x2: float, y2: float, color: Vector4) -> *Rect {
    rect_node := new_node(Rect);

    return rect_node;
}

#scope_file

new :: ($T: Type) -> *T {
    ptr := cast(*T)alloc(size_of(T));
    memset(ptr, 0, size_of(T));
    return ptr;
}

new_node :: ($T: Type) -> *T {
    node := new(T);
    node.type = T;
    assert(node.children.count == 0);
    return node;
}

new_node_with_tag :: ($T: Type, tag: string) -> *T {
    node := new_node(T);
    array_add(*node.tags, copy_string(tag));
    return node;
}