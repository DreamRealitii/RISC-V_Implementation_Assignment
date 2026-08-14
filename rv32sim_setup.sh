#!/bin/bash
# This script will instal RISC-V GNU toolchain along with a RISC-V simulator on a UW CSE wi21 VM

cd /home/auser
git clone https://github.com/riscv/riscv-gnu-toolchain
sudo yum install autoconf automake python3 libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv32 --with-arch=rv32i
sudo make
cd /home/auser
wget https://courses.cs.washington.edu/courses/cse469/21wi/vm_rv32sim.tar
tar -xvf vm_rv32sim.tar
cd rv32sim/libmc
make
cd ..
make
test=$(./sim)
if [[ "$test" == *"Hello"* ]]; then
        echo "SUCCESS! Setup is complete, have fun with HW 1"
fi

