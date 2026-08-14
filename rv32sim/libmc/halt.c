#include "libmc.h"

int halt() {
    mmio_write32((void *)0x4E20, 0);
}

