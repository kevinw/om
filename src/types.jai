#load "Sum_Type.jai";

Shader_Value :: Sum_Type(union {
    vec3: Vector3;
    vec4: Vector4;
    //buf: Buffer;
    mat: Matrix4;
    //img: Image;
});

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
}

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
    Vector2;
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
    // format:  RGBA8
    pool_id: u16;
}

Sprite :: struct {
    using node: Node;

}

Post_Process :: struct {
    using node: Node;
}

Shader_Value_Entry :: struct {
    name: string;
    value: Shader_Value;
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