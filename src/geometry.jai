#import "Math";

DEFAULT_CIRCLE_SIDES :: 255;

cache: struct { // TODO: put this in the global "state" struct?
    // these indexed by number of sides in the circle
    circle_verts, circle_indices: [..]struct {
        sides: int;
        buffer: Buffer;
    };

    rect_indices:    Buffer;
    rect_verts:      Buffer;
    rect_sprite_uvs: Buffer;
};

rect_indices :: () -> Buffer {
    using cache;

    if rect_indices.data.count == 0 {
        rect_indices = U16_Elem_Array(0, 1, 2, 1, 2, 3); // TODO: one of these tris may be backwards, cull-wise
    }
    assert(num_elements(rect_indices) == 6);

    return rect_indices;
}

rect_verts :: () -> Buffer {
    using cache;

    if rect_verts.data.count == 0
        rect_verts = Vec2_Array(-1, 1, 1, 1,
                                -1, -1, 1, -1);
    return rect_verts;
}

rect_sprite_uvs :: () -> Buffer {
    using cache;

    if rect_sprite_uvs.data.count == 0
        rect_sprite_uvs = Vec2_Array(1, 0, 1, 1,
                                     0, 0, 0, 1);
    return rect_sprite_uvs;
}


circle_verts :: (sides: u16 = DEFAULT_CIRCLE_SIDES) -> Buffer {
    using cache;

    for * circle_verts if it.sides == sides
        return it.buffer;

    t: [..]float; // TODO: @Speed use a non-dynamic array here
    //defer delete(t); // @Leak

    array_add(*t, 0);
    array_add(*t, 0);

    angle:float = 0;
    dangle:float = TAU / cast(float)sides;

    for 0..sides-1 {
        array_add(*t, cos(angle));
        array_add(*t, sin(angle));
        angle += dangle;
    }

    buf := Vec2_Array(..t);

    // TODO: this is gnarly...
    array_reserve(*circle_verts, circle_verts.count + 1);
    circle_verts[circle_verts.count].sides = sides;
    circle_verts[circle_verts.count].buffer = buf;
    circle_verts.count += 1;

    return buf;
}

circle_indices :: (sides: u16 = DEFAULT_CIRCLE_SIDES) -> Buffer {
    using cache;

    for * circle_indices if it.sides == sides
        return it.buffer;

    t: [..]u16; // TODO: @Speed use a non-dynamic array here
    //defer delete(t); // @Leak

    for s: 2..(sides + 1)
        array_add(*t, cast(u16)1, cast(u16)s, cast(u16)((s - 1) % sides + 2));

    buf := U16_Elem_Array(..t);
    array_reserve(*circle_indices, circle_indices.count + 1);
    circle_indices[circle_indices.count].sides = sides;
    circle_indices[circle_indices.count].buffer = buf;
    circle_indices.count += 1;
    return buf;
}