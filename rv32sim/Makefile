#

include site-config.sh
goal: test
CC=$(RISCV_PREFIX)-gcc
AS=$(RISCV_PREFIX)-as
LD=$(RISCV_PREFIX)-ld

SSFLAGS=-march=rv32i
CCFLAGS=-O1 -march=rv32i -Wno-builtin-declaration-mismatch -Ilibmc
LDFLAGS=--script ld.script
LDPOSTFLAGS= -Llibmc -lmc  -Llibmc -lmc -L$(RISCV_LIB) -lgcc

TEST_S=start.s func.s
TEST_C=test.c

.c.o:
	$(CC) $(CCFLAGS) -c $*.c

.s.o:
	$(AS) $(SSFLAGS) -c $*.s -o $*.o

test: $(TEST_S:.s=.o) $(TEST_C:.c=.o)
	$(LD) $(LDFLAGS) -o test $(TEST_S:.s=.o) $(TEST_C:.c=.o) $(LDPOSTFLAGS)
	 ./elftohex.sh test .

clean:
	rm -f *.o  *.hex test.bin

