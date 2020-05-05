#load "Sum_Type.jai";

WHITE: Vector4;

_init_colors :: () {
    WHITE.x = 1;
    WHITE.y = 1;
    WHITE.z = 1;
    WHITE.w = 1;
}

Shader_Value :: Sum_Type(union {
    vec3: Vector3;
    vec4: Vector4;
    buf: Buffer;
    mat: Matrix4;
    img: Image;
});


Shader_Value_Entry :: struct {
    name: string;
    value: Shader_Value;
}

make_shader_value_entry :: (name: string, val: $T) -> Shader_Value_Entry {
    entry: Shader_Value_Entry;
    entry.name = name;
    entry.value.set(*entry.value, val);
    return entry;
}

sv :: make_shader_value_entry; // TODO: replace this with an anonymous struct thing?

Action_Func :: #type (node: *Node);

Action_Entry :: struct {
    func: Action_Func;
    userdata: *void;
}

Node_Flags :: enum_flags {
    Hidden;
    Paused;
    Marked;
}

Node :: struct {
    id: u64;
    name: string;
    children: [..]*Node;
    tags: [..]string;
    actions: [..]Action_Entry;
    recursion_limit: s32;
    flags: Node_Flags;
    type: Type;
}

Use_Program :: struct {
    using node: Node;

    shader: *Shader;
}

Placeholder_Image_Type :: enum { WHITE; BLACK; NORMALS; }

Rotate :: struct {
    using node: Node;

    angle: float;
    axis: Vector3;
}

Scale :: struct {
    using node: Node;

    scale: Vector3;
}

Translate :: struct {
    using node: Node;
    offset: Vector3;
}

Rect :: struct {
    using node: Node;

    bind_node: *Bind;
}

Buffer_Type :: enum s8 {
    Invalid;
    Float;
    Vector2;
    Vector3;
    Vector4;
    U16_Elems;
    U32_Elems;
}

Resource_Usage :: enum s16 {
    Immutable;
    Dynamic;
    Stream;
}

Buffer :: struct {
    data: []u8;
    type: Buffer_Type;

    pool_id: u16;
}

Image :: struct {
    data: []u8;
    width: u16;
    height: u16;
    // format: RGBA8
    pool_id: u16;
}

Sprite :: struct {
    using node: Node;

}

Post_Process :: struct {
    using node: Node;
}

Bind :: struct {
    using node: Node;
    values: [..]Shader_Value_Entry;
}

Window :: struct {
    scene: *Node;
    width: u16;
    height: u16;
    clear_color: Vector4;
    title: string;

    mouse_position: Vector2;
    mouse_button_state: [3]struct {
        current: bool;
        last: bool;
    };
}

Draw :: struct {
    using node: Node;

    num_elements: int;
    primitive: Primitive;
    index_buffer: Buffer;
}

Circle :: struct {
    using node: Node;

    color: Vector4;

    scale_node: *Scale;
    translate_node: *Translate;
    bind_node: *Bind;
}

Group :: struct {
    using node: Node;
}

Read_Uniform :: struct {
    using node: Node;

    uniform: string;
    value: Shader_Value;
}

Blend :: struct {
    using node: Node;

    blend_mode: Blend_Mode;
}

Blend_Mode :: enum s16 {
    Off;
    Alpha;
    Premult;
    Add;
    Subtract;
    Add_Alpha;
    Subtract_Alpha;
    Multiply;
    Invert;
    NUM; // TODO: just use the type info
}

Primitive :: enum s16 {
    Default;
    Points;
    Lines;
    Line_Strip;
    Line_Loop;
    Triangles;
    Triangle_Strip;
}

Mouse_Button :: enum s16 {
    Left;
    Right;
    Middle;
}
