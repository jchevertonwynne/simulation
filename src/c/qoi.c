#define QOI_IMPLEMENTATION
#include "qoi/qoi.h"
#include <stdlib.h>

void qoi_free(void* p) {
    free(p);
}