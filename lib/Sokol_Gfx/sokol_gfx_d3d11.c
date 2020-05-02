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

#include "sokol_gfx.h"
