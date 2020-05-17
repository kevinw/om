#define SOKOL_IMPL
#define SOKOL_DLL
#define SOKOL_D3D11
#define SOKOL_DEBUG
#define SOKOL_NO_DEPRECATED

#include <stdlib.h>

typedef void* (*malloc_func)(size_t bytes);
typedef void (*free_func)();
typedef void (*assert_func)(const char* expr, const char* filename, int line_number);

static malloc_func _my_sg_MALLOC = 0;
static free_func _my_sg_FREE = 0;
static assert_func _my_sg_ASSERT = 0;

#define SOKOL_ASSERT(expr) \
    if (expr) \
        {} \
    else if (_my_sg_ASSERT) \
        _my_sg_ASSERT(#expr, __FILE__, __LINE__); \
    else { \
        fprintf( stderr, "sokol_gfx assert failed: '%s' in %s:%d", #expr, __FILE__, __LINE__); \
        abort(); \
    }

//
// debug malloc/free
//
#define SOKOL_MALLOC my_debug_MALLOC
#define SOKOL_FREE   my_debug_FREE

void sg_set_debug_funcs(malloc_func my_malloc, free_func my_free, assert_func my_assert) {
    _my_sg_MALLOC = my_malloc;
    _my_sg_FREE = my_free;
    _my_sg_ASSERT = my_assert;
}

static void* my_debug_MALLOC(size_t bytes) {
    if (_my_sg_MALLOC != 0)
        return _my_sg_MALLOC(bytes);
    else
        return malloc(bytes);
}

static void my_debug_FREE(void* ptr) {
    if (_my_sg_FREE != 0)
        _my_sg_FREE(ptr);
    else
        free(ptr);
}


#include "sokol_gfx.h"
