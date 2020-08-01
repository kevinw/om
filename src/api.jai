window :: (title: string = "om") -> *Window {
    if state.window != null
        panic("You cannot create more than one window!");

    win := new(Window);
    win.title = title;
    win.width = 1280;
    win.height = 720;

    state.window = win;

    return win;
}

rad :: (deg: float) -> float {
    pi_on_180 :: 0.017453292519943295;
    return deg * pi_on_180;
}

delta_time :: () -> float { return state.delta_time; }

set_hidden :: (using node: *Node, hidden: bool = true) -> *Node {
    if hidden flags |= Node_Flags.Hidden;
    else flags &= ~Node_Flags.Hidden;
    return node;
}

set_paused :: (using node: *Node, paused: bool = true) -> *Node {
    if paused flags |= Node_Flags.Hidden;
    else flags &= ~Node_Flags.Hidden;
    return node;
}

is_paused :: (using node: *Node) -> bool {
    return 0 != cast(u32)(flags & Node_Flags.Hidden); // TODO why is this cast necessary
}

use_program :: (shd: *Shader) -> *Use_Program {
    assert(shd != null);

    use_program := new_node_with_tag(Use_Program, "use_program");
    use_program.shader = shd;
    return use_program;
}

chain :: (first_arg: *$T = null, args: ..*Node) -> *Node {
    if first_arg == null
        return group();

    if args.count > 0 {
        for i: 0..args.count - 2 {
            node_to_add := args[i + 1];
            assert(node_to_add != null, "chain() nodes can't be null");
            array_add(*args[i].children, args[i + 1]);
        }

        array_add(*first_arg.children, args[0]);
    }

    return first_arg;
}

group :: () -> *Group {
    return new_node_with_tag(Group, "group");
}

add_child :: (using parent_node: *Node, child: *Node) {
    array_add(*children, child);
}

// rotate

rotate :: (angle_radians: float) -> *Rotate {
    rotate_node := new_node_with_tag(Rotate, "rotate");
    rotate_node.axis = .{0, 0, 1};
    rotate_node.angle = angle_radians;
    return rotate_node;
}

set_angle :: (using rotate: *Rotate, angle_radians: float) -> *Rotate {
    angle = angle_radians;
    return rotate;
}

// scale

scale :: (scale_scalar: float) -> *Scale {
    return scale(make_vector3(scale_scalar, scale_scalar, scale_scalar));
}

scale :: (scale_vec: Vector3) -> *Scale {
    scale_node := new_node_with_tag(Scale, "scale");
    scale_node.scale = scale_vec;
    return scale_node;
}

set_scale :: (using scale_node: *Scale, new_scale: Vector3) -> *Scale {
    scale = new_scale;
    return scale_node;
}

set_scale :: (using scale_node: *Scale, new_scale: float) -> *Scale {
    set_scale(scale_node, make_vector3(new_scale, new_scale, new_scale));
    return scale_node;
}

get_scale :: (using scale_node: *Scale) -> Vector3 {
    return scale;
}

// translate

translate :: (offset_vec: Vector3) -> *Translate {
    translate_node := new_node_with_tag(Translate, "translate");
    translate_node.offset = offset_vec;
    return translate_node;
}

translate :: (x: float, y: float, z: float = 0) -> *Translate {
    return translate(make_vector3(x, y, z));
}

set_position :: (using translate_node: *Translate, position: Vector3) -> *Translate {
    translate_node.offset = position;
    return translate_node;
}

bind :: (values: ..Shader_Value_Entry) -> *Bind {
    bind_node := new_node_with_tag(Bind, "bind");
    array_add(*bind_node.values, ..values);
    return bind_node;
}

_make_buffer :: (vec: []$V, type: Buffer_Type) -> Buffer {
    buf: Buffer;

    buf.data.count = vec.count * size_of(V);
    buf.data.data = alloc(buf.data.count);
    memcpy(buf.data.data, cast(*u8)vec.data, buf.data.count);

    //print("make buffer given % % and made a buffer with % bytes.\n", vec.count, V, buf.data.count);
    //print("vals:\n");
    //for vec print("% ", it);
    //print("\n");

    //print("bytes:\n");
    //for buf.data print("% ", it);
    //print("\n");

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


Vec2_Array :: (floats: ..float) -> Buffer {
    return _make_buffer(floats, Buffer_Type.Vector2);
}

Vec2_Array :: (vec2s: ..Vector2) -> Buffer {
    return _make_buffer(vec2s, Buffer_Type.Vector2);
}

U16_Elem_Array :: (u16s: ..u16) -> Buffer {
    return _make_buffer(u16s, Buffer_Type.U16_Elems);
}

U32_Elem_Array :: (u32s: ..u32) -> Buffer {
    return _make_buffer(u32s, Buffer_Type.U32_Elems);
}

circle :: (center: Vector2, radius: float, color: Vector4, sides: u16) -> *Circle {
    node := new_node_with_tag(Circle, "circle");
    node.color = color;

    node.translate_node = translate(center.x, center.y);
    node.scale_node = scale(radius);
    node.bind_node = bind(
        sv("vert", circle_verts(sides = sides)),
        sv("color", color)
    );

    return cast(*Circle)chain(
        node,
        node.scale_node,
        node.translate_node,
        use_program(shader_color2d()),
        blend(.Alpha),
        node.bind_node,
        draw(.Triangles, circle_indices(sides))
    );
}

rect :: (x1: float, y1: float, x2: float, y2: float) -> *Rect {
    return rect(x1, y1, x2, y2, WHITE);
}

rect :: (x1: float, y1: float, x2: float, y2: float, color: Vector4) -> *Rect {
    rect_node := new_node(Rect);

    rect_node.bind_node = bind(
        sv("vert", Vec2_Array(x2, y2, x2, y1, x1, y2, x1, y1)),
        sv("color", color));
    
    return cast(*Rect)chain(
        rect_node,
        use_program(shader_color2d()),
        blend(Blend_Mode.Alpha),
        rect_node.bind_node,
        draw(.Triangles, rect_indices()),
    );
}

set_coords :: (using rect: *Rect, x1: float, y1: float, x2: float, y2: float) -> *Rect {
    assert(false, "TODO: implement set_coords");
    return rect;
}

blend :: (blend_mode: Blend_Mode) -> *Blend {
    blend_node := new_node_with_tag(Blend, "blend");
    blend_node.blend_mode = blend_mode;
    return blend_node;
}

set_blend_mode :: (using blend: *Blend, new_blend_mode: Blend_Mode) {
    blend_mode = new_blend_mode;
}

set_tag :: (node: *Node, tag_name: string) -> *Node {
    array_add(*node.tags, copy_string(tag_name));
    return node;
}

shader :: (vert: string, frag: string) -> *Shader {
    shd := new(Shader);

    // Validate the source code, but don't actually link it yet.
    ok, native_vert, native_frag := translate_glsl(vert, frag, shd);

    if !ok {
        Log.error();
        Log.print("did not compile shader\n");
        print_stack_trace(context.stack_trace);
        exit(1);
    } else {
        shd.vert = native_vert;
        shd.frag = native_frag;
    }

    return shd;
}

draw :: (primitive: Primitive = Primitive.Triangles, elements: Buffer) -> *Draw {
    assert(elements.data.data == null ||
        elements.type == Buffer_Type.U16_Elems || elements.type == Buffer_Type.U32_Elems,
        tprint("index buffer was of unexpected type %", elements.type));

    draw_node := new_node_with_tag(Draw, "draw");
    draw_node.primitive = primitive;
    if elements.data.count != 0
        draw_node.num_elements = num_elements(elements);
    else
        draw_node.num_elements = -1;
    draw_node.index_buffer = elements;
    return draw_node;
}

frame_time :: () -> float64 { return state.frame_time; }

action :: (node: *Node, func: Action_Func) -> *Node {
    return node;
}

sprite :: (ascii_sprite_or_filename: string) -> *Sprite {
    // TODO: keep ascii sprites??
    if String.contains(ascii_sprite_or_filename, "\n") {
        assert(false, "TODO: implement ascii sprites");
        //ascii_img := parse_ascii_sprite(ascii_sprite_or_filename);
        //return sprite_from_image(ascii_img);
    }

    filename := ascii_sprite_or_filename;
    img, ok := _get_cached_image_from_filename(filename);
    if !ok {
        print("could not load sprite from file: %\n", filename);
        img = get_placeholder_image(.NORMALS);
    }

    return sprite(img);
}

sprite :: (img: Image) -> *Sprite {
    W2 := cast(float)img.width * 0.5;
    H2 := cast(float)img.height * 0.5;
    x1, x2 := -W2, W2;
    y1, y2 := -H2, H2;

    return cast(*Sprite)chain(
        new_node_with_tag(Sprite, "sprite"),
        blend(.Alpha),
        use_program(shader_texture2d()),
        bind(
            sv("vert", Vec2_Array(x2, y2, x2, y1, x1, y2, x1, y1)),
            sv("uv", rect_sprite_uvs()),
            sv("tex", img),
        ),
        draw(.Triangles, rect_indices())
    );
}


#scope_file //////////////////////////////////////////////////////////////////////////

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