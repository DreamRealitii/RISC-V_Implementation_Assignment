// Instruction memory and instruction load/decode.
`include "riscv.sv"

module instruction_memory (inst_out, inst_valid_out, pc_out, inst_load_out, stall_out, stall_time,
	                   pc_in, inst_valid_in, alu_inst_in, alu_inst_valid,
			   inst_load_addr, inst_store_enable, inst_store_type, inst_store_addr, inst_store_in, no_stall_in,
	                   clk, rst);

	// Circuit inputs.
	input                 clk, rst;

	// Instruction load stage.
	output reg [BITS-1:0] inst_out;
	output reg [BITS-1:0] pc_out;
	output reg            inst_valid_out;
	input      [BITS-1:0] pc_in;
	input                 inst_valid_in;

	// Data load stage.
	output reg [BITS-1:0] inst_load_out;
	input      [BITS-1:0] alu_inst_in;
	input                 alu_inst_valid;
	reg        [BITS-1:0] alu_inst;
	input      [BITS-1:0] inst_load_addr;
		   opcode     inst_load_opcode;
	           load_type  inst_load_type;

	// Write stage.
	input      [BITS-1:0] inst_store_addr, inst_store_in;
	input      store_type inst_store_type;
	input                 inst_store_enable;
	
	// The memory.
	reg [BYTE_SIZE-1:0] memory [0:INSTRUCTION_MEMORY_BYTES-1];

	// Pipeline stuff.
	input               no_stall_in;
	output reg          stall_out;
	output reg    [2:0] stall_time;

	// Instruction decoding.
	assign inst_load_type   = get_load_type(alu_inst);
	assign inst_load_opcode =    get_opcode(alu_inst);

	// Load instructions into memory on start.
	reg [BYTE_SIZE-1:0] load_mem [0:2047];
	initial begin
		$readmemh("test0.hex", load_mem);
		for (int i = 0; i < 1023; i++)
			memory[(i*4)+0] = load_mem[i];
		$readmemh("test1.hex", load_mem);
		for (int i = 0; i < 1023; i++)
			memory[(i*4)+1] = load_mem[i];
		$readmemh("test2.hex", load_mem);
		for (int i = 0; i < 1023; i++)
			memory[(i*4)+2] = load_mem[i];
		$readmemh("test3.hex", load_mem);
		for (int i = 0; i < 1023; i++)
			memory[(i*4)+3] = load_mem[i];

		inst_out = NOP;
		inst_valid_out = ZERO_1;
		pc_out = ZERO_32;
		inst_load_out = ZERO_32;
		alu_inst = NOP;
		stall_time = 3'b000;
		stall_out = ZERO_1;
	end

	always @(inst_out) begin
		if (DEBUG) $display("PC at Stage 1          = 0x%8h", pc_out);
		if (DEBUG) $display("Instruction at Stage 1 = 0x%8h", inst_out);
		if (DEBUG) $display("Destination register is x%0d",   get_rd(inst_out));
		if (DEBUG) $display("Immediate is 0x%8h",             get_imm(inst_out));
	end

	// Load instruction on instruction read stage.
	always @(posedge clk) begin
		if (rst) begin
			inst_out <= NOP;
			inst_valid_out <= ZERO_1;
			pc_out <= ZERO_32;
			inst_load_out <= ZERO_32;
			alu_inst <= NOP;
			stall_time <= 3'b000;
			stall_out <= ZERO_1;
		end else if (stall_time > 3'b000) begin
			if (stall_time == 3'b001 || no_stall_in)
				stall_out <= ZERO_1;
			if (no_stall_in) begin
				if (DEBUG) $display("LOAD: Ending stall because of squash.");
				stall_time <= 3'b000;
			end else begin
				if (DEBUG) $display("LOAD: Stalling for %0d more cycles", stall_time);
				stall_time <= stall_time - 1;
			end
		end else if (inst_valid_in) begin
			// End program if PC is out of bounds.
			if (pc_in+3 > INSTRUCTION_MEMORY_BYTES || pc_in < RESET_PC) begin
				$display("Program counter out of bounds. Ending Program");
				$finish;			
			end

			// Load instruction. End program if empty instruction detected.
			if (memory[pc_in  ] == {8{1'b0}} && memory[pc_in+1] == {8{1'b0}} &&
			    memory[pc_in+2] == {8{1'b0}} && memory[pc_in+3] == {8{1'b0}}) begin
				$display("\nEmpty instruction at 0x%8h. Ending Program.", pc_in);
				$finish;
			end else
				inst_out <= {memory[pc_in+3], memory[pc_in+2], memory[pc_in+1], memory[pc_in+0]};
			pc_out <= pc_in;

			// Stall for five cycles on loads, one cycle for stores.
			if (get_opcode({memory[pc_in+3], memory[pc_in+2], memory[pc_in+1], memory[pc_in+0]}) == LOAD && PIPELINED && !no_stall_in) begin
				if (DEBUG) $display("LOAD: Beginning stall for 4 cycles.");
				stall_time <= 3'b100;
				stall_out <= ONE_1;
			end else stall_out <= ZERO_1;
		end

		if (!rst) inst_valid_out <= inst_valid_in;

		if (alu_inst_valid) begin
			// Read from memory.
			alu_inst <= alu_inst_in;
			if (inst_load_opcode == LOAD) begin
				case(inst_load_type)
					LB : begin
						if (inst_load_addr   < DATA_MEMORY_ADDR_START) begin
							inst_load_out[31:8] <= {24{memory[inst_load_addr+0][0]}};
							inst_load_out[7 :0] <=     memory[inst_load_addr+0];
							///if (DEBUG) $display("LB: Reading from instruction address 0x%0h", inst_load_addr);
						end else inst_load_out <= ZERO_32;
					end
					LH : begin
						if (inst_load_addr+1 < DATA_MEMORY_ADDR_START) begin
							inst_load_out[31:16]  <= {16{memory[inst_load_addr+1][0]}};
							inst_load_out[15:0 ]  <=    {memory[inst_load_addr+1],
								                     memory[inst_load_addr+0]};
							//if (DEBUG) $display("LH: Reading from instruction address 0x%0h", inst_load_addr);
						end else inst_load_out <= ZERO_32;
					end
					LW : begin
						if (inst_load_addr+3 < DATA_MEMORY_ADDR_START) begin
							inst_load_out <= {memory[inst_load_addr+0],
								          memory[inst_load_addr+1],
								          memory[inst_load_addr+2],
								          memory[inst_load_addr+3]};
							//if (DEBUG) $display("LW: Reading from instruction address 0x%0h", inst_load_addr);
						end else inst_load_out <= ZERO_32;
					end
					LBU:
						if (inst_load_addr   < DATA_MEMORY_ADDR_START) begin
							inst_load_out <= {{24{1'b0}}, memory[inst_load_addr+0]};
							//if (DEBUG) $display("LBU: Reading from instruction address 0x%0h", inst_load_addr);
						end else inst_load_out <= ZERO_32;
					LHU:
						if (inst_load_addr+1 < DATA_MEMORY_ADDR_START) begin
							inst_load_out <= {{16{1'b0}}, memory[inst_load_addr+1],
								                      memory[inst_load_addr+0]};
							//if (DEBUG) $display("LHU: Reading from instruction address 0x%0h", inst_load_addr);
						end else inst_load_out <= ZERO_32;
					default: begin
						inst_load_out <= ZERO_32;
						//if (DEBUG) $display("Unknown LOAD type");
					end
				endcase
			end
		end else inst_load_out <= ZERO_32;

		if (inst_valid_in) begin
			// Write to memory.
			if (inst_store_enable) begin
				// Write 8/16/32 bits depending on inst_store_type.
				case (inst_store_type)
					    SB: begin
						if (inst_store_addr   < DATA_MEMORY_ADDR_START)
							memory[inst_store_addr+0] <= inst_store_in[ 7: 0];
							if (DEBUG) $display("SB: Writing 0x%0h into address 0x%0h", inst_store_in[7:0], inst_store_addr);
					end SH: begin
						if (inst_store_addr+1 < DATA_MEMORY_ADDR_START) begin
							memory[inst_store_addr+1] <= inst_store_in[15: 8];
							memory[inst_store_addr+0] <= inst_store_in[ 7: 0];
							if (DEBUG) $display("SH: Writing 0x%0h into address 0x%0h", inst_store_in[15:0], inst_store_addr);
						end
					end SW: begin
						if (inst_store_addr+3 < DATA_MEMORY_ADDR_START) begin
							memory[inst_store_addr+3] <= inst_store_in[31:24];
							memory[inst_store_addr+2] <= inst_store_in[23:16];
							memory[inst_store_addr+1] <= inst_store_in[15: 8];
							memory[inst_store_addr+0] <= inst_store_in[ 7: 0];
							if (DEBUG) $display("SW: Writing 0x%0h into address 0x%0h", inst_store_in[31:0], inst_store_addr);
						end
					end default: if (DEBUG) $display("Unknown STORE type");
				endcase
			end
		end
	end
endmodule
