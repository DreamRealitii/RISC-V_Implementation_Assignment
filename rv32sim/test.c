#include "libmc/libmc.h"

extern void my_func();
int _double(int);

int test(char *s) {
    printf("%s\n", s);
    int x = _double(5);
}

typedef unsigned int uint32_t;
typedef signed int int32_t;

int f() {
    uint32_t    i_j;
    int32_t     i_s;
    int     i;
    for(i = 0; i < 10; i++)
          printf("%d\n", i);
}

int main() {
    printf("Hello world\n");
    printf("%x\n", 1000); //3E8
    my_func();
    return 0;
}

