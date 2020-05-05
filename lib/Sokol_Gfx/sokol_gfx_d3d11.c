#define SOKOL_IMPL
#define SOKOL_DLL
#define SOKOL_D3D11
#define SOKOL_DEBUG
#define SOKOL_NO_DEPRECATED

typedef void (*assert_failed_func)(const char* expr, const char* file, int line);

static assert_failed_func _assert_failed;

void set_assert_func(assert_failed_func func) {
    _assert_failed = func;
}

#define SOKOL_ASSERT(expr) \
    if (expr) \
        {} \
    else if (_assert_failed) \
        _assert_failed(#expr, __FILE__, __LINE__); \
    else { \
        fprintf( stderr, "sokol_gfx assert failed: '%s' in %s:%d", #expr, __FILE__, __LINE__); \
        abort(); \
    }

//
// debug malloc/free
//
#define SOKOL_MALLOC my_debug_MALLOC
#define SOKOL_FREE   my_debug_FREE

#include <stdlib.h>

typedef void* (*malloc_func)(size_t bytes);
typedef void (*free_func)();

static malloc_func _my_sg_MALLOC = 0;
static free_func _my_sg_FREE = 0;

void sg_set_debug_funcs(malloc_func my_malloc, free_func my_free) {
    _my_sg_MALLOC = my_malloc;
    _my_sg_FREE = my_free;
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
