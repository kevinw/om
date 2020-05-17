#if OS_WINDOWS {
    #foreign_system_library "d3d11";
    #foreign_system_library "dxguid";
    sg_lib :: #foreign_library,no_dll "win/sokol_gfx_d3d11";
}

/*
    Resource id typedefs:

    sg_buffer:      vertex- and index-buffers
    sg_image:       textures and render targets
    sg_shader:      vertex- and fragment-shaders, uniform blocks
    sg_pipeline:    associated shader and vertex-layouts, and render states
    sg_pass:        a bundle of render targets and actions on them
    sg_context:     a 'context handle' for switching between 3D-API contexts

    Instead of pointers, resource creation functions return a 32-bit
    number which uniquely identifies the resource object.

    The 32-bit resource id is split into a 16-bit pool index in the lower bits,
    and a 16-bit 'unique counter' in the upper bits. The index allows fast
    pool lookups, and combined with the unique-mask it allows to detect
    'dangling accesses' (trying to use an object which no longer exists, and
    its pool slot has been reused for a new object)

    The resource ids are wrapped into a struct so that the compiler
    can complain when the wrong resource type is used.
*/
sg_buffer   :: struct { id: u32; }
sg_image    :: struct { id: u32; }
sg_shader   :: struct { id: u32; }
sg_pipeline :: struct { id: u32; }
sg_pass     :: struct { id: u32; }
sg_context  :: struct { id: u32; }

/*
    various compile-time constants

    FIXME: it may make sense to convert some of those into defines so
    that the user code can override them.
*/
SG_INVALID_ID :: 0;
SG_NUM_SHADER_STAGES :: 2;
SG_NUM_INFLIGHT_FRAMES :: 2;
SG_MAX_COLOR_ATTACHMENTS :: 4;
SG_MAX_SHADERSTAGE_BUFFERS :: 8;
SG_MAX_SHADERSTAGE_IMAGES :: 12;
SG_MAX_SHADERSTAGE_UBS :: 4;
SG_MAX_UB_MEMBERS :: 16;
SG_MAX_VERTEX_ATTRIBUTES :: 16;      /* NOTE: actual max vertex attrs can be less on GLES2, see sg_limits! */
SG_MAX_MIPMAPS :: 16;
SG_MAX_TEXTUREARRAY_LAYERS :: 128;

/*
    sg_backend

    The active 3D-API backend, use the function sg_query_backend()
    to get the currently active backend.

    For returned value corresponds with the compile-time define to select
    a backend, with the only exception of SOKOL_GLES3: this may
    return SG_BACKEND_GLES2 if the backend has to fallback to GLES2 mode
    because GLES3 isn't supported.
*/
sg_backend :: enum u32 {
    GLCORE33;
    GLES2;
    GLES3;
    D3D11;
    METAL_IOS;
    METAL_MACOS;
    METAL_SIMULATOR;
    DUMMY;
}

/*
    sg_pixel_format

    sokol_gfx.h basically uses the same pixel formats as WebGPU, since these
    are supported on most newer GPUs. GLES2 and WebGL has a much smaller
    subset of available pixel formats. Call sg_query_pixelformat() to check
    at runtime if a pixel format supports the desired features.

    A pixelformat name consist of three parts:

        - components (R, RG, RGB or RGBA)
        - bit width per component (8, 16 or 32)
        - component data type:
            - unsigned normalized (no postfix)
            - signed normalized (SN postfix)
            - unsigned integer (UI postfix)
            - signed integer (SI postfix)
            - float (F postfix)

    Not all pixel formats can be used for everything, call sg_query_pixelformat()
    to inspect the capabilities of a given pixelformat. The function returns
    an sg_pixelformat_info struct with the following bool members:

        - sample: the pixelformat can be sampled as texture at least with
                  nearest filtering
        - filter: the pixelformat can be samples as texture with linear
                  filtering
        - render: the pixelformat can be used for render targets
        - blend:  blending is supported when using the pixelformat for
                  render targets
        - msaa:   multisample-antiliasing is supported when using the
                  pixelformat for render targets
        - depth:  the pixelformat can be used for depth-stencil attachments

    When targeting GLES2/WebGL, the only safe formats to use
    as texture are SG_PIXELFORMAT_R8 and SG_PIXELFORMAT_RGBA8. For rendering
    in GLES2/WebGL, only SG_PIXELFORMAT_RGBA8 is safe. All other formats
    must be checked via sg_query_pixelformats().

    The default pixel format for texture images is SG_PIXELFORMAT_RGBA8.

    The default pixel format for render target images is platform-dependent:
        - for Metal and D3D11 it is SG_PIXELFORMAT_BGRA8
        - for GL backends it is SG_PIXELFORMAT_RGBA8

    This is mainly because of the default framebuffer which is setup outside
    of sokol_gfx.h. On some backends, using BGRA for the default frame buffer
    allows more efficient frame flips. For your own offscreen-render-targets,
    use whatever renderable pixel format is convenient for you.
*/
sg_pixel_format :: enum u32 {
    _DEFAULT;                 /* value 0 reserved for default-init */
    NONE;

    R8;
    R8SN;
    R8UI;
    R8SI;

    R16;
    R16SN;
    R16UI;
    R16SI;
    R16F;
    RG8;
    RG8SN;
    RG8UI;
    RG8SI;

    R32UI;
    R32SI;
    R32F;
    RG16;
    RG16SN;
    RG16UI;
    RG16SI;
    RG16F;
    RGBA8;
    RGBA8SN;
    RGBA8UI;
    RGBA8SI;
    BGRA8;
    RGB10A2;
    RG11B10F;

    RG32UI;
    RG32SI;
    RG32F;
    RGBA16;
    RGBA16SN;
    RGBA16UI;
    RGBA16SI;
    RGBA16F;

    RGBA32UI;
    RGBA32SI;
    RGBA32F;

    DEPTH;
    DEPTH_STENCIL;

    BC1_RGBA;
    BC2_RGBA;
    BC3_RGBA;
    BC4_R;
    BC4_RSN;
    BC5_RG;
    BC5_RGSN;
    BC6H_RGBF;
    BC6H_RGBUF;
    BC7_RGBA;
    PVRTC_RGB_2BPP;
    PVRTC_RGB_4BPP;
    PVRTC_RGBA_2BPP;
    PVRTC_RGBA_4BPP;
    ETC2_RGB8;
    ETC2_RGB8A1;
    ETC2_RGBA8;
    ETC2_RG11;
    ETC2_RG11SN;

    _NUM;
}

/*
    Runtime information about a pixel format, returned
    by sg_query_pixelformat().
*/
sg_pixelformat_info :: struct {
    sample: bool;        /* pixel format can be sampled in shaders */
    filter: bool;        /* pixel format can be sampled with filtering */
    render: bool;        /* pixel format can be used as render target */
    blend: bool;         /* alpha-blending is supported */
    msaa: bool;          /* pixel format can be used as MSAA render target */
    depth: bool;         /* pixel format is a depth format */
}

/*
    Runtime information about available optional features,
    returned by sg_query_features()
*/
sg_features :: struct {
    instancing: bool;
    origin_top_left: bool;
    multiple_render_targets: bool;
    msaa_render_targets: bool;
    imagetype_3d: bool;          /* creation of SG_IMAGETYPE_3D images is supported */
    imagetype_array: bool;       /* creation of SG_IMAGETYPE_ARRAY images is supported */
    image_clamp_to_border: bool; /* border color and clamp-to-border UV-wrap mode is supported */
}

/*
    Runtime information about resource limits, returned by sg_query_limit()
*/
sg_limits :: struct {
    max_image_size_2d: u32;         /* max width/height of SG_IMAGETYPE_2D images */
    max_image_size_cube: u32;       /* max width/height of SG_IMAGETYPE_CUBE images */
    max_image_size_3d: u32;         /* max width/height/depth of SG_IMAGETYPE_3D images */
    max_image_size_array: u32;
    max_image_array_layers: u32;
    max_vertex_attrs: u32;          /* <= SG_MAX_VERTEX_ATTRIBUTES (only on some GLES2 impls) */
}

/*
    sg_resource_state

    The current state of a resource in its resource pool.
    Resources start in the INITIAL state, which means the
    pool slot is unoccupied and can be allocated. When a resource is
    created, first an id is allocated, and the resource pool slot
    is set to state ALLOC. After allocation, the resource is
    initialized, which may result in the VALID or FAILED state. The
    reason why allocation and initialization are separate is because
    some resource types (e.g. buffers and images) might be asynchronously
    initialized by the user application. If a resource which is not
    in the VALID state is attempted to be used for rendering, rendering
    operations will silently be dropped.

    The special INVALID state is returned in sg_query_xxx_state() if no
    resource object exists for the provided resource id.
*/
sg_resource_state :: enum u32 {
    INITIAL;
    ALLOC;
    VALID;
    FAILED;
    INVALID;
}

/*
    sg_usage

    A resource usage hint describing the update strategy of
    buffers and images. This is used in the sg_buffer_desc.usage
    and sg_image_desc.usage members when creating buffers
    and images:

    SG_USAGE_IMMUTABLE:     the resource will never be updated with
                            new data, instead the data content of the
                            resource must be provided on creation
    SG_USAGE_DYNAMIC:       the resource will be updated infrequently
                            with new data (this could range from "once
                            after creation", to "quite often but not
                            every frame")
    SG_USAGE_STREAM:        the resource will be updated each frame
                            with new content

    The rendering backends use this hint to prevent that the
    CPU needs to wait for the GPU when attempting to update
    a resource that might be currently accessed by the GPU.

    Resource content is updated with the function sg_update_buffer() for
    buffer objects, and sg_update_image() for image objects. Only
    one update is allowed per frame and resource object. The
    application must update all data required for rendering (this
    means that the update data can be smaller than the resource size,
    if only a part of the overall resource size is used for rendering,
    you only need to make sure that the data that *is* used is valid.

    The default usage is SG_USAGE_IMMUTABLE.
*/
sg_usage :: enum u32 {
    _DEFAULT;      /* value 0 reserved for default-init */
    IMMUTABLE;
    DYNAMIC;
    STREAM;
    _NUM;
}

/*
    sg_buffer_type

    This indicates whether a buffer contains vertex- or index-data,
    used in the sg_buffer_desc.type member when creating a buffer.

    The default value is SG_BUFFERTYPE_VERTEXBUFFER.
*/
sg_buffer_type :: enum u32 {
    _DEFAULT;         /* value 0 reserved for default-init */
    VERTEXBUFFER;
    INDEXBUFFER;
    _NUM;
}

/*
    sg_index_type

    Indicates whether indexed rendering (fetching vertex-indices from an
    index buffer) is used, and if yes, the index data type (16- or 32-bits).
    This is used in the sg_pipeline_desc.index_type member when creating a
    pipeline object.

    The default index type is SG_INDEXTYPE_NONE.
*/
sg_index_type :: enum u32 {
    _DEFAULT;   /* value 0 reserved for default-init */
    NONE;
    UINT16;
    UINT32;
    _NUM;
}

/*
    sg_image_type

    Indicates the basic image type (2D-texture, cubemap, 3D-texture
    or 2D-array-texture). 3D- and array-textures are not supported
    on the GLES2/WebGL backend. The image type is used in the
    sg_image_desc.type member when creating an image.

    The default image type when creating an image is SG_IMAGETYPE_2D.
*/
sg_image_type :: enum u32 {
    _DEFAULT;  /* value 0 reserved for default-init */
    _2D;
    CUBE;
    _3D;
    ARRAY;
    _NUM;
}

/*
    sg_cube_face

    The cubemap faces. Use these as indices in the sg_image_desc.content
    array.
*/
sg_cube_face :: enum u32 {
    POS_X;
    NEG_X;
    POS_Y;
    NEG_Y;
    POS_Z;
    NEG_Z;
    NUM;
}

/*
    sg_shader_stage

    There are 2 shader stages: vertex- and fragment-shader-stage.
    Each shader stage consists of:

    - one slot for a shader function (provided as source- or byte-code)
    - SG_MAX_SHADERSTAGE_UBS slots for uniform blocks
    - SG_MAX_SHADERSTAGE_IMAGES slots for images used as textures by
      the shader function
*/
sg_shader_stage :: enum u32 {
    VS;
    FS;
}

/*
    sg_primitive_type

    This is the common subset of 3D primitive types supported across all 3D
    APIs. This is used in the sg_pipeline_desc.primitive_type member when
    creating a pipeline object.

    The default primitive type is SG_PRIMITIVETYPE_TRIANGLES.
*/
sg_primitive_type :: enum u32 {
    _DEFAULT;  /* value 0 reserved for default-init */
    POINTS;
    LINES;
    LINE_STRIP;
    TRIANGLES;
    TRIANGLE_STRIP;
    _NUM;
}

/*
    sg_filter

    The filtering mode when sampling a texture image. This is
    used in the sg_image_desc.min_filter and sg_image_desc.mag_filter
    members when creating an image object.

    The default filter mode is SG_FILTER_NEAREST.
*/
sg_filter :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    NEAREST;
    LINEAR;
    NEAREST_MIPMAP_NEAREST;
    NEAREST_MIPMAP_LINEAR;
    LINEAR_MIPMAP_NEAREST;
    LINEAR_MIPMAP_LINEAR;
    _NUM;
}

/*
    sg_wrap

    The texture coordinates wrapping mode when sampling a texture
    image. This is used in the sg_image_desc.wrap_u, .wrap_v
    and .wrap_w members when creating an image.

    The default wrap mode is SG_WRAP_REPEAT.

    NOTE: SG_WRAP_CLAMP_TO_BORDER is not supported on all backends
    and platforms. To check for support, call sg_query_features()
    and check the "clamp_to_border" boolean in the returned
    sg_features struct.

    Platforms which don't support SG_WRAP_CLAMP_TO_BORDER will silently fall back
    to SG_WRAP_CLAMP_TO_EDGE without a validation error.

    Platforms which support clamp-to-border are:

        - all desktop GL platforms
        - Metal on macOS
        - D3D11

    Platforms which do not support clamp-to-border:

        - GLES2/3 and WebGL/WebGL2
        - Metal on iOS
*/
sg_wrap :: enum u32 {
    _DEFAULT;   /* value 0 reserved for default-init */
    REPEAT;
    CLAMP_TO_EDGE;
    CLAMP_TO_BORDER;
    MIRRORED_REPEAT;
    _NUM;
}

/*
    sg_border_color

    The border color to use when sampling a texture, and the UV wrap
    mode is SG_WRAP_CLAMP_TO_BORDER.

    The default border color is SG_BORDERCOLOR_OPAQUE_BLACK
*/
sg_border_color :: enum u32 {
    _DEFAULT;    /* value 0 reserved for default-init */
    TRANSPARENT_BLACK;
    OPAQUE_BLACK;
    OPAQUE_WHITE;
    _NUM;
}

/*
    sg_vertex_format

    The data type of a vertex component. This is used to describe
    the layout of vertex data when creating a pipeline object.
*/
sg_vertex_format :: enum u32 {
    INVALID;
    FLOAT;
    FLOAT2;
    FLOAT3;
    FLOAT4;
    BYTE4;
    BYTE4N;
    UBYTE4;
    UBYTE4N;
    SHORT2;
    SHORT2N;
    USHORT2N;
    SHORT4;
    SHORT4N;
    USHORT4N;
    UINT10_N2;
    _NUM;
}

/*
    sg_vertex_step

    Defines whether the input pointer of a vertex input stream is advanced
    'per vertex' or 'per instance'. The default step-func is
    SG_VERTEXSTEP_PER_VERTEX. SG_VERTEXSTEP_PER_INSTANCE is used with
    instanced-rendering.

    The vertex-step is part of the vertex-layout definition
    when creating pipeline objects.
*/
sg_vertex_step :: enum u32 {
    _DEFAULT;     /* value 0 reserved for default-init */
    PER_VERTEX;
    PER_INSTANCE;
    _NUM;
}

/*
    sg_uniform_type

    The data type of a uniform block member. This is used to
    describe the internal layout of uniform blocks when creating
    a shader object.
*/
sg_uniform_type :: enum u32 {
    INVALID;
    FLOAT;
    FLOAT2;
    FLOAT3;
    FLOAT4;
    MAT4;
    _NUM;
}

/*
    sg_cull_mode

    The face-culling mode, this is used in the
    sg_pipeline_desc.rasterizer.cull_mode member when creating a
    pipeline object.

    The default cull mode is SG_CULLMODE_NONE
*/
sg_cull_mode :: enum u32 {
    _DEFAULT;   /* value 0 reserved for default-init */
    NONE;
    FRONT;
    BACK;
    _NUM;
}

/*
    sg_face_winding

    The vertex-winding rule that determines a front-facing primitive. This
    is used in the member sg_pipeline_desc.rasterizer.face_winding
    when creating a pipeline object.

    The default winding is SG_FACEWINDING_CW (clockwise)
*/
sg_face_winding :: enum u32 {
    _DEFAULT;    /* value 0 reserved for default-init */
    CCW;
    CW;
    _NUM;
}

/*
    sg_compare_func

    The compare-function for depth- and stencil-ref tests.
    This is used when creating pipeline objects in the members:

    sg_pipeline_desc
        .depth_stencil
            .depth_compare_func
            .stencil_front.compare_func
            .stencil_back.compare_func

    The default compare func for depth- and stencil-tests is
    SG_COMPAREFUNC_ALWAYS.
*/
sg_compare_func :: enum u32 {
    _DEFAULT;    /* value 0 reserved for default-init */
    NEVER;
    LESS;
    EQUAL;
    LESS_EQUAL;
    GREATER;
    NOT_EQUAL;
    GREATER_EQUAL;
    ALWAYS;
    _NUM;
}

/*
    sg_stencil_op

    The operation performed on a currently stored stencil-value when a
    comparison test passes or fails. This is used when creating a pipeline
    object in the members:

    sg_pipeline_desc
        .depth_stencil
            .stencil_front
                .fail_op
                .depth_fail_op
                .pass_op
            .stencil_back
                .fail_op
                .depth_fail_op
                .pass_op

    The default value is SG_STENCILOP_KEEP.
*/
sg_stencil_op :: enum u32 {
    _DEFAULT;      /* value 0 reserved for default-init */
    KEEP;
    ZERO;
    REPLACE;
    INCR_CLAMP;
    DECR_CLAMP;
    INVERT;
    INCR_WRAP;
    DECR_WRAP;
    _NUM;
}

/*
    sg_blend_factor

    The source and destination factors in blending operations.
    This is used in the following members when creating a pipeline object:

    sg_pipeline_desc
        .blend
            .src_factor_rgb
            .dst_factor_rgb
            .src_factor_alpha
            .dst_factor_alpha

    The default value is SG_BLENDFACTOR_ONE for source
    factors, and SG_BLENDFACTOR_ZERO for destination factors.
*/
sg_blend_factor :: enum u32 {
    _DEFAULT;    /* value 0 reserved for default-init */
    ZERO;
    ONE;
    SRC_COLOR;
    ONE_MINUS_SRC_COLOR;
    SRC_ALPHA;
    ONE_MINUS_SRC_ALPHA;
    DST_COLOR;
    ONE_MINUS_DST_COLOR;
    DST_ALPHA;
    ONE_MINUS_DST_ALPHA;
    SRC_ALPHA_SATURATED;
    BLEND_COLOR;
    ONE_MINUS_BLEND_COLOR;
    BLEND_ALPHA;
    ONE_MINUS_BLEND_ALPHA;
    _NUM;
}

/*
    sg_blend_op

    Describes how the source and destination values are combined in the
    fragment blending operation. It is used in the following members when
    creating a pipeline object:

    sg_pipeline_desc
        .blend
            .op_rgb
            .op_alpha

    The default value is SG_BLENDOP_ADD.
*/
sg_blend_op :: enum u32 {
    _DEFAULT;    /* value 0 reserved for default-init */
    ADD;
    SUBTRACT;
    REVERSE_SUBTRACT;
    _NUM;
}

/*
    sg_color_mask

    Selects the color channels when writing a fragment color to the
    framebuffer. This is used in the members
    sg_pipeline_desc.blend.color_write_mask when creating a pipeline object.

    The default colormask is SG_COLORMASK_RGBA (write all colors channels)
*/
sg_color_mask :: enum u32 {
    _DEFAULT :: 0;      /* value 0 reserved for default-init */
    NONE :: (0x10);     /* special value for 'all channels disabled */
    R :: (1<<0);
    G :: (1<<1);
    B :: (1<<2);
    A :: (1<<3);
    RGB :: 0x7;
    RGBA :: 0xF;
}

/*
    sg_action

    Defines what action should be performed at the start of a render pass:

    SG_ACTION_CLEAR:    clear the render target image
    SG_ACTION_LOAD:     load the previous content of the render target image
    SG_ACTION_DONTCARE: leave the render target image content undefined

    This is used in the sg_pass_action structure.

    The default action for all pass attachments is SG_ACTION_CLEAR, with the
    clear color rgba = {0.5f, 0.5f, 0.5f, 1.0f], depth=1.0 and stencil=0.

    If you want to override the default behaviour, it is important to not
    only set the clear color, but the 'action' field as well (as long as this
    is in its _SG_ACTION_DEFAULT, the value fields will be ignored).
*/
sg_action :: enum u32 {
    _DEFAULT;
    CLEAR;
    LOAD;
    DONTCARE;
    _NUM;
}

/*
    sg_pass_action

    The sg_pass_action struct defines the actions to be performed
    at the start of a rendering pass in the functions sg_begin_pass()
    and sg_begin_default_pass().

    A separate action and clear values can be defined for each
    color attachment, and for the depth-stencil attachment.

    The default clear values are defined by the macros:

    - SG_DEFAULT_CLEAR_RED:     0.5f
    - SG_DEFAULT_CLEAR_GREEN:   0.5f
    - SG_DEFAULT_CLEAR_BLUE:    0.5f
    - SG_DEFAULT_CLEAR_ALPHA:   1.0f
    - SG_DEFAULT_CLEAR_DEPTH:   1.0f
    - SG_DEFAULT_CLEAR_STENCIL: 0
*/
sg_color_attachment_action :: struct {
    action: sg_action;
    val: [4]float;
}

sg_depth_attachment_action :: struct {
    action: sg_action;
    val: float;
}

sg_stencil_attachment_action :: struct {
    action: sg_action;
    val: u8;
}

sg_pass_action :: struct {
    _start_canary: u32;
    colors: [SG_MAX_COLOR_ATTACHMENTS]sg_color_attachment_action;
    depth: sg_depth_attachment_action;
    stencil: sg_stencil_attachment_action;
    _end_canary: u32;
}

/*
    sg_bindings

    The sg_bindings structure defines the resource binding slots
    of the sokol_gfx render pipeline, used as argument to the
    sg_apply_bindings() function.

    A resource binding struct contains:

    - 1..N vertex buffers
    - 0..N vertex buffer offsets
    - 0..1 index buffers
    - 0..1 index buffer offsets
    - 0..N vertex shader stage images
    - 0..N fragment shader stage images

    The max number of vertex buffer and shader stage images
    are defined by the SG_MAX_SHADERSTAGE_BUFFERS and
    SG_MAX_SHADERSTAGE_IMAGES configuration constants.

    The optional buffer offsets can be used to group different chunks
    of vertex- and/or index-data into the same buffer objects.
*/
sg_bindings :: struct {
    _start_canary: u32;
    vertex_buffers: [SG_MAX_SHADERSTAGE_BUFFERS]sg_buffer;
    vertex_buffer_offsets: [SG_MAX_SHADERSTAGE_BUFFERS]s32;
    index_buffer: sg_buffer;
    index_buffer_offset: s32;
    vs_images: [SG_MAX_SHADERSTAGE_IMAGES]sg_image;
    fs_images: [SG_MAX_SHADERSTAGE_IMAGES]sg_image;
    _end_canary: u32;
}

/*
    sg_buffer_desc

    Creation parameters for sg_buffer objects, used in the
    sg_make_buffer() call.

    The default configuration is:

    .size:      0       (this *must* be set to a valid size in bytes)
    .type:      SG_BUFFERTYPE_VERTEXBUFFER
    .usage:     SG_USAGE_IMMUTABLE
    .content    0
    .label      0       (optional string label for trace hooks)

    The dbg_label will be ignored by sokol_gfx.h, it is only useful
    when hooking into sg_make_buffer() or sg_init_buffer() via
    the sg_install_trace_hook

    ADVANCED TOPIC: Injecting native 3D-API buffers:

    The following struct members allow to inject your own GL, Metal
    or D3D11 buffers into sokol_gfx:

    .gl_buffers[SG_NUM_INFLIGHT_FRAMES]
    .mtl_buffers[SG_NUM_INFLIGHT_FRAMES]
    .d3d11_buffer

    You must still provide all other members except the .content member, and
    these must match the creation parameters of the native buffers you
    provide. For SG_USAGE_IMMUTABLE, only provide a single native 3D-API
    buffer, otherwise you need to provide SG_NUM_INFLIGHT_FRAMES buffers
    (only for GL and Metal, not D3D11). Providing multiple buffers for GL and
    Metal is necessary because sokol_gfx will rotate through them when
    calling sg_update_buffer() to prevent lock-stalls.

    Note that it is expected that immutable injected buffer have already been
    initialized with content, and the .content member must be 0!

    Also you need to call sg_reset_state_cache() after calling native 3D-API
    functions, and before calling any sokol_gfx function.
*/
sg_buffer_desc :: struct {
    _start_canary: u32;
    size: s32;
    type: sg_buffer_type;
    usage: sg_usage;
    content: *void;
    label: *u8;
    /* GL specific */
    gl_buffers: [SG_NUM_INFLIGHT_FRAMES]u32;
    /* Metal specific */
    mtl_buffers: [SG_NUM_INFLIGHT_FRAMES]*void;
    /* D3D11 specific */
    d3d11_buffer: *void;
    _end_canary: u32;
}

/*
    sg_subimage_content

    Pointer to and size of a subimage-surface data, this is
    used to describe the initial content of immutable-usage images,
    or for updating a dynamic- or stream-usage images.

    For 3D- or array-textures, one sg_subimage_content item
    describes an entire mipmap level consisting of all array- or
    3D-slices of the mipmap level. It is only possible to update
    an entire mipmap level, not parts of it.
*/
sg_subimage_content :: struct {
    ptr: *void;    /* pointer to subimage data */
    size: s32;     /* size in bytes of pointed-to subimage data */
}

/*
    sg_image_content

    Defines the content of an image through a 2D array
    of sg_subimage_content structs. The first array dimension
    is the cubemap face, and the second array dimension the
    mipmap level.
*/
sg_image_content :: struct {
    subimage: [sg_cube_face.NUM][SG_MAX_MIPMAPS]sg_subimage_content;
}

/*
    sg_image_desc

    Creation parameters for sg_image objects, used in the
    sg_make_image() call.

    The default configuration is:

    .type:              SG_IMAGETYPE_2D
    .render_target:     false
    .width              0 (must be set to >0)
    .height             0 (must be set to >0)
    .depth/.layers:     1
    .num_mipmaps:       1
    .usage:             SG_USAGE_IMMUTABLE
    .pixel_format:      SG_PIXELFORMAT_RGBA8 for textures, backend-dependent
                        for render targets (RGBA8 or BGRA8)
    .sample_count:      1 (only used in render_targets)
    .min_filter:        SG_FILTER_NEAREST
    .mag_filter:        SG_FILTER_NEAREST
    .wrap_u:            SG_WRAP_REPEAT
    .wrap_v:            SG_WRAP_REPEAT
    .wrap_w:            SG_WRAP_REPEAT (only SG_IMAGETYPE_3D)
    .border_color       SG_BORDERCOLOR_OPAQUE_BLACK
    .max_anisotropy     1 (must be 1..16)
    .min_lod            0.0f
    .max_lod            FLT_MAX
    .content            an sg_image_content struct to define the initial content
    .label              0       (optional string label for trace hooks)

    SG_IMAGETYPE_ARRAY and SG_IMAGETYPE_3D are not supported on
    WebGL/GLES2, use sg_query_features().imagetype_array and
    sg_query_features().imagetype_3d at runtime to check
    if array- and 3D-textures are supported.

    Images with usage SG_USAGE_IMMUTABLE must be fully initialized by
    providing a valid .content member which points to
    initialization data.

    ADVANCED TOPIC: Injecting native 3D-API textures:

    The following struct members allow to inject your own GL, Metal
    or D3D11 textures into sokol_gfx:

    .gl_textures[SG_NUM_INFLIGHT_FRAMES]
    .mtl_textures[SG_NUM_INFLIGHT_FRAMES]
    .d3d11_texture

    The same rules apply as for injecting native buffers
    (see sg_buffer_desc documentation for more details).
*/
sg_image_desc :: struct {
    _start_canary: u32;
    type: sg_image_type;
    render_target: bool;
    width: s32;
    height: s32;
    union {
        depth: s32;
        layers: s32;
    };
    num_mipmaps: s32;
    usage: sg_usage;
    pixel_format: sg_pixel_format;
    sample_count: s32;
    min_filter: sg_filter;
    mag_filter: sg_filter;
    wrap_u: sg_wrap;
    wrap_v: sg_wrap;
    wrap_w: sg_wrap;
    border_color: sg_border_color;
    max_anisotropy: u32;
    min_lod: float;
    max_lod: float;
    content: sg_image_content;
    label: *u8;
    /* GL specific */
    gl_textures: [SG_NUM_INFLIGHT_FRAMES]u32;
    /* Metal specific */
    mtl_textures: [SG_NUM_INFLIGHT_FRAMES]*void;
    /* D3D11 specific */
    d3d11_texture: *void;
    _end_canary: u32;
}

/*
    sg_shader_desc

    The structure sg_shader_desc defines all creation parameters
    for shader programs, used as input to the sg_make_shader() function:

    - reflection information for vertex attributes (vertex shader inputs):
        - vertex attribute name (required for GLES2, optional for GLES3 and GL)
        - a semantic name and index (required for D3D11)
    - for each vertex- and fragment-shader-stage:
        - the shader source or bytecode
        - an optional entry function name
        - reflection info for each uniform block used by the shader stage:
            - the size of the uniform block in bytes
            - reflection info for each uniform block member (only required for GL backends):
                - member name
                - member type (SG_UNIFORMTYPE_xxx)
                - if the member is an array, the number of array items
        - reflection info for the texture images used by the shader stage:
            - the image type (SG_IMAGETYPE_xxx)
            - the name of the texture sampler (required for GLES2, optional everywhere else)

    For all GL backends, shader source-code must be provided. For D3D11 and Metal,
    either shader source-code or byte-code can be provided.

    For D3D11, if source code is provided, the d3dcompiler_47.dll will be loaded
    on demand. If this fails, shader creation will fail.
*/
sg_shader_attr_desc :: struct {
    name: *u8;           /* GLSL vertex attribute name (only required for GLES2) */
    sem_name: *u8;       /* HLSL semantic name */
    sem_index: s32;              /* HLSL semantic index */
}

sg_shader_uniform_desc :: struct {
    name: *u8;
    type: sg_uniform_type;
    array_count: s32;
}

sg_shader_uniform_block_desc :: struct {
    size: s32;
    uniforms: [SG_MAX_UB_MEMBERS]sg_shader_uniform_desc;
}

sg_shader_image_desc :: struct {
    name: *u8;
    type: sg_image_type;
}

sg_shader_stage_desc :: struct {
    source: *u8;
    byte_code: *u8;
    byte_code_size: s32;
    entry: *u8;
    uniform_blocks: [SG_MAX_SHADERSTAGE_UBS]sg_shader_uniform_block_desc;
    images: [SG_MAX_SHADERSTAGE_IMAGES]sg_shader_image_desc;
}

sg_shader_desc :: struct {
    _start_canary: u32;
    attrs: [SG_MAX_VERTEX_ATTRIBUTES]sg_shader_attr_desc;
    vs: sg_shader_stage_desc;
    fs: sg_shader_stage_desc;
    label: *u8;
    _end_canary: u32;
}

/*
    sg_pipeline_desc

    The sg_pipeline_desc struct defines all creation parameters
    for an sg_pipeline object, used as argument to the
    sg_make_pipeline() function:

    - the vertex layout for all input vertex buffers
    - a shader object
    - the 3D primitive type (points, lines, triangles, ...)
    - the index type (none, 16- or 32-bit)
    - depth-stencil state
    - alpha-blending state
    - rasterizer state

    If the vertex data has no gaps between vertex components, you can omit
    the .layout.buffers[].stride and layout.attrs[].offset items (leave them
    default-initialized to 0), sokol will then compute the offsets and strides
    from the vertex component formats (.layout.attrs[].offset). Please note
    that ALL vertex attribute offsets must be 0 in order for the the
    automatic offset computation to kick in.

    The default configuration is as follows:

    .layout:
        .buffers[]:         vertex buffer layouts
            .stride:        0 (if no stride is given it will be computed)
            .step_func      SG_VERTEXSTEP_PER_VERTEX
            .step_rate      1
        .attrs[]:           vertex attribute declarations
            .buffer_index   0 the vertex buffer bind slot
            .offset         0 (offsets can be omitted if the vertex layout has no gaps)
            .format         SG_VERTEXFORMAT_INVALID (must be initialized!)
    .shader:            0 (must be intilized with a valid sg_shader id!)
    .primitive_type:    SG_PRIMITIVETYPE_TRIANGLES
    .index_type:        SG_INDEXTYPE_NONE
    .depth_stencil:
        .stencil_front, .stencil_back:
            .fail_op:               SG_STENCILOP_KEEP
            .depth_fail_op:         SG_STENCILOP_KEEP
            .pass_op:               SG_STENCILOP_KEEP
            .compare_func           SG_COMPAREFUNC_ALWAYS
        .depth_compare_func:    SG_COMPAREFUNC_ALWAYS
        .depth_write_enabled:   false
        .stencil_enabled:       false
        .stencil_read_mask:     0
        .stencil_write_mask:    0
        .stencil_ref:           0
    .blend:
        .enabled:               false
        .src_factor_rgb:        SG_BLENDFACTOR_ONE
        .dst_factor_rgb:        SG_BLENDFACTOR_ZERO
        .op_rgb:                SG_BLENDOP_ADD
        .src_factor_alpha:      SG_BLENDFACTOR_ONE
        .dst_factor_alpha:      SG_BLENDFACTOR_ZERO
        .op_alpha:              SG_BLENDOP_ADD
        .color_write_mask:      SG_COLORMASK_RGBA
        .color_attachment_count 1
        .color_format           SG_PIXELFORMAT_RGBA8
        .depth_format           SG_PIXELFORMAT_DEPTHSTENCIL
        .blend_color:           { 0.0f, 0.0f, 0.0f, 0.0f }
    .rasterizer:
        .alpha_to_coverage_enabled:     false
        .cull_mode:                     SG_CULLMODE_NONE
        .face_winding:                  SG_FACEWINDING_CW
        .sample_count:                  1
        .depth_bias:                    0.0f
        .depth_bias_slope_scale:        0.0f
        .depth_bias_clamp:              0.0f
    .label  0       (optional string label for trace hooks)
*/
sg_buffer_layout_desc :: struct {
    stride: s32;
    step_func: sg_vertex_step;
    step_rate: s32;
}

sg_vertex_attr_desc :: struct {
    buffer_index: s32;
    offset: s32;
    format: sg_vertex_format;
}

sg_layout_desc :: struct {
    buffers: [SG_MAX_SHADERSTAGE_BUFFERS]sg_buffer_layout_desc;
    attrs: [SG_MAX_VERTEX_ATTRIBUTES]sg_vertex_attr_desc;
}

sg_stencil_state :: struct {
    fail_op: sg_stencil_op;
    depth_fail_op: sg_stencil_op;
    pass_op: sg_stencil_op;
    compare_func: sg_compare_func;
}

sg_depth_stencil_state :: struct {
    stencil_front: sg_stencil_state;
    stencil_back: sg_stencil_state;
    depth_compare_func: sg_compare_func;
    depth_write_enabled: bool;
    stencil_enabled: bool;
    stencil_read_mask: u8;
    stencil_write_mask: u8;
    stencil_ref: u8;
}

sg_blend_state :: struct {
    enabled: bool;
    src_factor_rgb: sg_blend_factor;
    dst_factor_rgb: sg_blend_factor;
    op_rgb: sg_blend_op;
    src_factor_alpha: sg_blend_factor;
    dst_factor_alpha: sg_blend_factor;
    op_alpha: sg_blend_op;
    color_write_mask: u8;
    color_attachment_count: s32;
    color_format: sg_pixel_format;
    depth_format: sg_pixel_format;
    blend_color: [4]float;
}

sg_rasterizer_state :: struct {
    alpha_to_coverage_enabled: bool;
    cull_mode: sg_cull_mode;
    face_winding: sg_face_winding;
    sample_count: s32;
    depth_bias: float;
    depth_bias_slope_scale: float;
    depth_bias_clamp: float;
}

sg_pipeline_desc :: struct {
    _start_canary: u32;
    layout: sg_layout_desc;
    shader: sg_shader;
    primitive_type: sg_primitive_type;
    index_type: sg_index_type;
    depth_stencil: sg_depth_stencil_state;
    blend: sg_blend_state;
    rasterizer: sg_rasterizer_state;
    label: *u8;
    _end_canary: u32;
}

/*
    sg_pass_desc

    Creation parameters for an sg_pass object, used as argument
    to the sg_make_pass() function.

    A pass object contains 1..4 color-attachments and none, or one,
    depth-stencil-attachment. Each attachment consists of
    an image, and two additional indices describing
    which subimage the pass will render: one mipmap index, and
    if the image is a cubemap, array-texture or 3D-texture, the
    face-index, array-layer or depth-slice.

    Pass images must fulfill the following requirements:

    All images must have:
    - been created as render target (sg_image_desc.render_target = true)
    - the same size
    - the same sample count

    In addition, all color-attachment images must have the same
    pixel format.
*/
sg_attachment_desc :: struct {
    image: sg_image;
    mip_level: s32;
    union {
        face: s32;
        layer: s32;
        slice: s32;
    };
}

sg_pass_desc :: struct {
    _start_canary: u32;
    color_attachments: [SG_MAX_COLOR_ATTACHMENTS]sg_attachment_desc;
    depth_stencil_attachment: sg_attachment_desc;
    label: *u8;
    _end_canary: u32;
}

/*
    sg_trace_hooks

    Installable callback functions to keep track of the sokol_gfx calls,
    this is useful for debugging, or keeping track of resource creation
    and destruction.

    Trace hooks are installed with sg_install_trace_hooks(), this returns
    another sg_trace_hooks struct with the previous set of
    trace hook function pointers. These should be invoked by the
    new trace hooks to form a proper call chain.
*/
sg_trace_hooks :: struct {
    user_data: *void;
    reset_state_cache : (user_data: *void);
    make_buffer : (desc: *sg_buffer_desc, result: sg_buffer, user_data: *void);
    make_image : (desc: *sg_image_desc, result: sg_image, user_data: *void);
    make_shader : (desc: *sg_shader_desc, result: sg_shader, user_data: *void);
    make_pipeline : (desc: *sg_pipeline_desc, result: sg_pipeline, user_data: *void);
    make_pass : (desc: *sg_pass_desc, result: sg_pass, user_data: *void);
    destroy_buffer : (buf: sg_buffer, user_data: *void);
    destroy_image : (img: sg_image, user_data: *void);
    destroy_shader : (shd: sg_shader, user_data: *void);
    destroy_pipeline : (pip: sg_pipeline, user_data: *void);
    destroy_pass : (pass: sg_pass, user_data: *void);
    update_buffer : (buf: sg_buffer, data_ptr: *void, data_size: s32, user_data: *void);
    update_image : (img: sg_image, data: *sg_image_content, user_data: *void);
    append_buffer : (buf: sg_buffer, data_ptr: *void, data_size: s32, result: s32, user_data: *void);
    begin_default_pass : (pass_action: *sg_pass_action, width: s32, height: s32, user_data: *void);
    begin_pass : (pass: sg_pass, pass_action: *sg_pass_action, user_data: *void);
    apply_viewport : (x: s32, y: s32, width: s32, height: s32, origin_top_left: bool, user_data: *void);
    apply_scissor_rect : (x: s32, y: s32, width: s32, height: s32, origin_top_left: bool, user_data: *void);
    apply_pipeline : (pip: sg_pipeline, user_data: *void);
    apply_bindings : (bindings: *sg_bindings, user_data: *void);
    apply_uniforms : (stage: sg_shader_stage, ub_index: s32, data: *void, num_bytes: s32, user_data: *void);
    draw : (base_element: s32, num_elements: s32, num_instances: s32, user_data: *void);
    end_pass : (user_data: *void);
    commit : (user_data: *void);
    alloc_buffer : (result: sg_buffer, user_data: *void);
    alloc_image : (result: sg_image, user_data: *void);
    alloc_shader : (result: sg_shader, user_data: *void);
    alloc_pipeline : (result: sg_pipeline, user_data: *void);
    alloc_pass : (result: sg_pass, user_data: *void);
    init_buffer : (buf_id: sg_buffer, desc: *sg_buffer_desc, user_data: *void);
    init_image : (img_id: sg_image, desc: *sg_image_desc, user_data: *void);
    init_shader : (shd_id: sg_shader, desc: *sg_shader_desc, user_data: *void);
    init_pipeline : (pip_id: sg_pipeline, desc: *sg_pipeline_desc, user_data: *void);
    init_pass : (pass_id: sg_pass, desc: *sg_pass_desc, user_data: *void);
    fail_buffer : (buf_id: sg_buffer, user_data: *void);
    fail_image : (img_id: sg_image, user_data: *void);
    fail_shader : (shd_id: sg_shader, user_data: *void);
    fail_pipeline : (pip_id: sg_pipeline, user_data: *void);
    fail_pass : (pass_id: sg_pass, user_data: *void);
    push_debug_group : (name: *u8, user_data: *void);
    pop_debug_group : (user_data: *void);
    err_buffer_pool_exhausted : (user_data: *void);
    err_image_pool_exhausted : (user_data: *void);
    err_shader_pool_exhausted : (user_data: *void);
    err_pipeline_pool_exhausted : (user_data: *void);
    err_pass_pool_exhausted : (user_data: *void);
    err_context_mismatch : (user_data: *void);
    err_pass_invalid : (user_data: *void);
    err_draw_invalid : (user_data: *void);
    err_bindings_invalid : (user_data: *void);
}

/*
    sg_buffer_info
    sg_image_info
    sg_shader_info
    sg_pipeline_info
    sg_pass_info

    These structs contain various internal resource attributes which
    might be useful for debug-inspection. Please don't rely on the
    actual content of those structs too much, as they are quite closely
    tied to sokol_gfx.h internals and may change more frequently than
    the other public API elements.

    The *_info structs are used as the return values of the following functions:

    sg_query_buffer_info()
    sg_query_image_info()
    sg_query_shader_info()
    sg_query_pipeline_info()
    sg_query_pass_info()
*/
sg_slot_info :: struct {
    state: sg_resource_state;    /* the current state of this resource slot */
    res_id: u32;        /* type-neutral resource if (e.g. sg_buffer.id) */
    ctx_id: u32;        /* the context this resource belongs to */
}

sg_buffer_info :: struct {
    slot: sg_slot_info;              /* resource pool slot info */
    update_frame_index: u32;    /* frame index of last sg_update_buffer() */
    append_frame_index: u32;    /* frame index of last sg_append_buffer() */
    append_pos: s32;                 /* current position in buffer for sg_append_buffer() */
    append_overflow: bool;           /* is buffer in overflow state (due to sg_append_buffer) */
    num_slots: s32;                  /* number of renaming-slots for dynamically updated buffers */
    active_slot: s32;                /* currently active write-slot for dynamically updated buffers */
}

sg_image_info :: struct {
    slot: sg_slot_info;              /* resource pool slot info */
    upd_frame_index: u32;       /* frame index of last sg_update_image() */
    num_slots: s32;                  /* number of renaming-slots for dynamically updated images */
    active_slot: s32;                /* currently active write-slot for dynamically updated images */
}

sg_shader_info :: struct {
    slot: sg_slot_info;              /* resoure pool slot info */
}

sg_pipeline_info :: struct {
    slot: sg_slot_info;              /* resource pool slot info */
}

sg_pass_info :: struct {
    slot: sg_slot_info;              /* resource pool slot info */
}

/*
    sg_desc

    The sg_desc struct contains configuration values for sokol_gfx,
    it is used as parameter to the sg_setup() call.

    The default configuration is:

    .buffer_pool_size:      128
    .image_pool_size:       128
    .shader_pool_size:      32
    .pipeline_pool_size:    64
    .pass_pool_size:        16
    .context_pool_size:     16

    GL specific:
    .gl_force_gles2
        if this is true the GL backend will act in "GLES2 fallback mode" even
        when compiled with SOKOL_GLES3, this is useful to fall back
        to traditional WebGL if a browser doesn't support a WebGL2 context

    Metal specific:
        (NOTE: All Objective-C object references are transferred through
        a bridged (const void*) to sokol_gfx, which will use a unretained
        bridged cast (__bridged id<xxx>) to retrieve the Objective-C
        references back. Since the bridge cast is unretained, the caller
        must hold a strong reference to the Objective-C object for the
        duration of the sokol_gfx call!

    .mtl_device
        a pointer to the MTLDevice object
    .mtl_renderpass_descriptor_cb
        a C callback function to obtain the MTLRenderPassDescriptor for the
        current frame when rendering to the default framebuffer, will be called
        in sg_begin_default_pass()
    .mtl_drawable_cb
        a C callback function to obtain a MTLDrawable for the current
        frame when rendering to the default framebuffer, will be called in
        sg_end_pass() of the default pass
    .mtl_global_uniform_buffer_size
        the size of the global uniform buffer in bytes, this must be big
        enough to hold all uniform block updates for a single frame,
        the default value is 4 MByte (4 * 1024 * 1024)
    .mtl_sampler_cache_size
        the number of slots in the sampler cache, the Metal backend
        will share texture samplers with the same state in this
        cache, the default value is 64

    D3D11 specific:
    .d3d11_device
        a pointer to the ID3D11Device object, this must have been created
        before sg_setup() is called
    .d3d11_device_context
        a pointer to the ID3D11DeviceContext object
    .d3d11_render_target_view_cb
        a C callback function to obtain a pointer to the current
        ID3D11RenderTargetView object of the default framebuffer,
        this function will be called in sg_begin_pass() when rendering
        to the default framebuffer
    .d3d11_depth_stencil_view_cb
        a C callback function to obtain a pointer to the current
        ID3D11DepthStencilView object of the default framebuffer,
        this function will be called in sg_begin_pass() when rendering
        to the default framebuffer
*/
sg_desc :: struct {
    _start_canary: u32;
    buffer_pool_size: s32;
    image_pool_size: s32;
    shader_pool_size: s32;
    pipeline_pool_size: s32;
    pass_pool_size: s32;
    context_pool_size: s32;
    /* GL specific */
    gl_force_gles2: bool;
    /* Metal-specific */
    mtl_device: *void;
    mtl_renderpass_descriptor_cb: () -> *void #c_call;
    mtl_drawable_cb: () -> *void #c_call;
    mtl_global_uniform_buffer_size: s32;
    mtl_sampler_cache_size: s32;
    /* D3D11-specific */
    d3d11_device: *void;
    d3d11_device_context: *void;
    d3d11_render_target_view_cb: () -> *void #c_call;
    d3d11_depth_stencil_view_cb: () -> *void #c_call;
    _end_canary: u32;
}

/* setup and misc functions */
sg_setup :: (desc: *sg_desc) #foreign sg_lib;
sg_shutdown :: () #foreign sg_lib;
sg_isvalid :: () -> bool #foreign sg_lib;
sg_reset_state_cache :: () #foreign sg_lib;
sg_install_trace_hooks :: (trace_hooks: *sg_trace_hooks) -> sg_trace_hooks #foreign sg_lib;
sg_push_debug_group :: (name: *u8) #foreign sg_lib;
sg_pop_debug_group :: () #foreign sg_lib;

/* resource creation, destruction and updating */
sg_make_buffer :: (desc: *sg_buffer_desc) -> sg_buffer #foreign sg_lib;
sg_make_image :: (desc: *sg_image_desc) -> sg_image #foreign sg_lib;
sg_make_shader :: (desc: *sg_shader_desc) -> sg_shader #foreign sg_lib;
sg_make_pipeline :: (desc: *sg_pipeline_desc) -> sg_pipeline #foreign sg_lib;
sg_make_pass :: (desc: *sg_pass_desc) -> sg_pass #foreign sg_lib;
sg_destroy_buffer :: (buf: sg_buffer) #foreign sg_lib;
sg_destroy_image :: (img: sg_image) #foreign sg_lib;
sg_destroy_shader :: (shd: sg_shader) #foreign sg_lib;
sg_destroy_pipeline :: (pip: sg_pipeline) #foreign sg_lib;
sg_destroy_pass :: (pass: sg_pass) #foreign sg_lib;
sg_update_buffer :: (buf: sg_buffer, data_ptr: *void, data_size: s32) #foreign sg_lib;
sg_update_image :: (img: sg_image, data: *sg_image_content) #foreign sg_lib;
sg_append_buffer :: (buf: sg_buffer, data_ptr: *void, data_size: s32) -> s32 #foreign sg_lib;
sg_query_buffer_overflow :: (buf: sg_buffer) -> bool #foreign sg_lib;

/* rendering functions */
sg_begin_default_pass :: (pass_action: *sg_pass_action, width: s32, height: s32) #foreign sg_lib;
sg_begin_pass :: (pass: sg_pass, pass_action: *sg_pass_action) #foreign sg_lib;
sg_apply_viewport :: (x: s32, y: s32, width: s32, height: s32, origin_top_left: bool) #foreign sg_lib;
sg_apply_scissor_rect :: (x: s32, y: s32, width: s32, height: s32, origin_top_left: bool) #foreign sg_lib;
sg_apply_pipeline :: (pip: sg_pipeline) #foreign sg_lib;
sg_apply_bindings :: (bindings: *sg_bindings) #foreign sg_lib;
sg_apply_uniforms :: (stage: sg_shader_stage, ub_index: s32, data: *void, num_bytes: s32) #foreign sg_lib;
sg_draw :: (base_element: s32, num_elements: s32, num_instances: s32) #foreign sg_lib;
sg_end_pass :: () #foreign sg_lib;
sg_commit :: () #foreign sg_lib;

/* getting information */
sg_query_desc :: () -> sg_desc #foreign sg_lib;
sg_query_backend :: () -> sg_backend #foreign sg_lib;
sg_query_features :: () -> sg_features #foreign sg_lib;
sg_query_limits :: () -> sg_limits #foreign sg_lib;
sg_query_pixelformat :: (fmt: sg_pixel_format) -> sg_pixelformat_info #foreign sg_lib;
/* get current state of a resource (INITIAL, ALLOC, VALID, FAILED, INVALID) */
sg_query_buffer_state :: (buf: sg_buffer) -> sg_resource_state #foreign sg_lib;
sg_query_image_state :: (img: sg_image) -> sg_resource_state #foreign sg_lib;
sg_query_shader_state :: (shd: sg_shader) -> sg_resource_state #foreign sg_lib;
sg_query_pipeline_state :: (pip: sg_pipeline) -> sg_resource_state #foreign sg_lib;
sg_query_pass_state :: (pass: sg_pass) -> sg_resource_state #foreign sg_lib;
/* get runtime information about a resource */
sg_query_buffer_info :: (buf: sg_buffer) -> sg_buffer_info #foreign sg_lib;
sg_query_image_info :: (img: sg_image) -> sg_image_info #foreign sg_lib;
sg_query_shader_info :: (shd: sg_shader) -> sg_shader_info #foreign sg_lib;
sg_query_pipeline_info :: (pip: sg_pipeline) -> sg_pipeline_info #foreign sg_lib;
sg_query_pass_info :: (pass: sg_pass) -> sg_pass_info #foreign sg_lib;
/* get resource creation desc struct with their default values replaced */
sg_query_buffer_defaults :: (desc: *sg_buffer_desc) -> sg_buffer_desc #foreign sg_lib;
sg_query_image_defaults :: (desc: *sg_image_desc) -> sg_image_desc #foreign sg_lib;
sg_query_shader_defaults :: (desc: *sg_shader_desc) -> sg_shader_desc #foreign sg_lib;
sg_query_pipeline_defaults :: (desc: *sg_pipeline_desc) -> sg_pipeline_desc #foreign sg_lib;
sg_query_pass_defaults :: (desc: *sg_pass_desc) -> sg_pass_desc #foreign sg_lib;

/* separate resource allocation and initialization (for async setup) */
sg_alloc_buffer :: () -> sg_buffer #foreign sg_lib;
sg_alloc_image :: () -> sg_image #foreign sg_lib;
sg_alloc_shader :: () -> sg_shader #foreign sg_lib;
sg_alloc_pipeline :: () -> sg_pipeline #foreign sg_lib;
sg_alloc_pass :: () -> sg_pass #foreign sg_lib;
sg_init_buffer :: (buf_id: sg_buffer, desc: *sg_buffer_desc) #foreign sg_lib;
sg_init_image :: (img_id: sg_image, desc: *sg_image_desc) #foreign sg_lib;
sg_init_shader :: (shd_id: sg_shader, desc: *sg_shader_desc) #foreign sg_lib;
sg_init_pipeline :: (pip_id: sg_pipeline, desc: *sg_pipeline_desc) #foreign sg_lib;
sg_init_pass :: (pass_id: sg_pass, desc: *sg_pass_desc) #foreign sg_lib;
sg_fail_buffer :: (buf_id: sg_buffer) #foreign sg_lib;
sg_fail_image :: (img_id: sg_image) #foreign sg_lib;
sg_fail_shader :: (shd_id: sg_shader) #foreign sg_lib;
sg_fail_pipeline :: (pip_id: sg_pipeline) #foreign sg_lib;
sg_fail_pass :: (pass_id: sg_pass) #foreign sg_lib;

/* rendering contexts (optional) */
sg_setup_context :: () -> sg_context #foreign sg_lib;
sg_activate_context :: (ctx_id: sg_context) #foreign sg_lib;
sg_discard_context :: (ctx_id: sg_context) #foreign sg_lib;

/* Debug functionality (not in sokol master) */
sg_print_struct_sizes :: () #foreign sg_lib;

sg_malloc_func :: #type (bytes: int) -> *void #c_call;
sg_free_func :: #type (ptr: *void) #c_call;
sg_assert_func :: #type (expr: *u8, filename: *u8, line_number: s32) #c_call;

sg_set_debug_funcs :: (my_malloc: sg_malloc_func, my_free: sg_free_func, sg_assert_func) #foreign sg_lib;