#include "libmc.h"

int putc(char ch) {
    mmio_write32((void *)0x4E20, ch);
    return 0;
}

