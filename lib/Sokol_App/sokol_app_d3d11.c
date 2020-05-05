#define SOKOL_IMPL
#define SOKOL_NO_ENTRY
#define SOKOL_DLL
#define SOKOL_DEBUG
#define SOKOL_D3D11

#include <stdlib.h>

typedef void* (*calloc_func)(size_t num, size_t size);
typedef void (*free_func)();

static calloc_func _my_sapp_CALLOC = 0;
static free_func _my_sapp_FREE = 0;

void sapp_set_debug_funcs(calloc_func my_calloc, free_func my_free) {
    _my_sapp_CALLOC = my_calloc;
    _my_sapp_FREE = my_free;
}

static void* my_debug_CALLOC(size_t num, size_t size) {
    if (_my_sapp_CALLOC != 0)
        return _my_sapp_CALLOC(num, size);
    else
        return calloc(num, size);
}

static void my_debug_FREE(void* ptr) {
    if (_my_sapp_FREE != 0)
        _my_sapp_FREE(ptr);
    else
        free(ptr);
}

#define SOKOL_CALLOC my_debug_CALLOC
#define SOKOL_FREE   my_debug_FREE

#include "sokol_app.h"
