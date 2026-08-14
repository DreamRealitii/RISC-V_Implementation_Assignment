make
verilator --cc --exe --build -j 0 test_riscv32_tb.cpp top.sv core.sv program_counter.sv instruction_memory.sv register_file.sv alu.sv data_memory.sv le_writer.sv
./dumphex -i test -o test -size 8192 -strip -byte
/opt/riscv32/bin/riscv32-unknown-elf-objdump -D test > test.dis
./obj_dir/Vtop
