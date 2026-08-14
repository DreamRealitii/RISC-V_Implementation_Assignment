#!/bin/bash

source site-config.sh


$RISCV_PREFIX-objcopy -O binary $1 $1.bin

./dumphex -i $1.bin -o code -base 0 -size 4096 -strip -byte
./dumphex -i $1.bin -o data -base 4096 -size 4096 -strip -byte
