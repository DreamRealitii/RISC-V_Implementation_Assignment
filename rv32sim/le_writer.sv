// Stores the write-back data for the write stage of an instruction.
// Despite being called le_writer, this is one out of only two modules that doesn't activate during the write stage.
`include "riscv.sv"

module le_writer (new_pc_out, pc_write_enable, rd_write_enable, rd_value_out, store_enable,
		  write_store_type, store_addr, store_value_out, rd_sel_out, flush_alu_out, no_stall_out,
		  clk, rst, inst_in, inst_valid_in, pc_in, rs1_value_in, rs2_value_in,
		  alu_result_in, inst_load_in, data_load_in, branch_condition_in, stall_time_in);
	// Circuit inputs.
	input clk, rst;

	// Instruction.
	input      [BITS-1:0] inst_in, pc_in;
	input                 inst_valid_in;
	reg        [BITS-1:0] imm;
	reg        [BITS-1:0] inst, pc;
	           opcode     write_opcode;

	// Write setup stage.
	output reg [BITS-1:0] new_pc_out, rd_value_out, store_addr, store_value_out;
	output reg [4:0]      rd_sel_out;
	output     store_type write_store_type;
	output reg            store_enable;
	output reg            rd_write_enable;
	output reg            pc_write_enable;
	input      [BITS-1:0] rs1_value_in, rs2_value_in, alu_result_in, inst_load_in, data_load_in;
	input                 branch_condition_in;

	// Instruction decode.
	assign write_opcode     =     get_opcode(inst_in);
      //assign rd_sel_out       =         get_rd(inst_in);
      //assign write_store_type = get_store_type(inst_in);
      //assign imm              =        get_imm(inst_in);

	// Pipeline stuff.
	output reg            flush_alu_out, no_stall_out;
	input      [2:0]      stall_time_in; // Needed in case invalid instruction after jump is a load.
	reg        [3:0]      squash_time;

	initial begin
		new_pc_out = RESET_PC;
		rd_write_enable = ZERO_1;
		rd_value_out = ZERO_32;
		store_enable = ZERO_1;
		store_value_out = ZERO_32;
		store_addr = ZERO_32;
		write_store_type = SB;
		pc_write_enable = ZERO_1;
		inst = NOP;
		pc = RESET_PC;
		squash_time = 4'b0000;
		flush_alu_out = ZERO_1;
		no_stall_out = ZERO_1;
	end

	always @(inst) begin
		if (DEBUG) $display("PC at Stage 5          = 0x%8h", pc);
		if (DEBUG) $display("Instruction at Stage 5 = 0x%8h", inst);
	end

	// Setup write-back data.
	always @(posedge clk) begin
		if (rst) begin
			new_pc_out <= RESET_PC;
			rd_write_enable <= ZERO_1;
			rd_value_out <= ZERO_32;
			store_enable <= ZERO_1;
			store_value_out <= ZERO_32;
			store_addr <= ZERO_32;
			pc_write_enable <= ZERO_1;
			inst <= NOP;
			pc <= ZERO_32;
			squash_time <= 4'b0000;
			flush_alu_out <= ZERO_1;
			no_stall_out <= ZERO_1;
		end else if (squash_time > 4'b0000) begin
			if (DEBUG) $display("JUMP: Squashing %0d instructions", squash_time);
			squash_time <= squash_time - 1;
			pc_write_enable <= ZERO_1;
			rd_write_enable <= ZERO_1;
			store_enable <= ZERO_1;
			if (squash_time == 4'b0011) // When valid instructions reach ALU.
				flush_alu_out <= ZERO_1;
			no_stall_out <= ZERO_1;
		end else if (inst_valid_in) begin
			inst <= inst_in;
			pc <= pc_in;
			rd_sel_out <= get_rd(inst_in);
			write_store_type = get_store_type(inst_in);
			imm = get_imm(inst_in);

			// Squash invalid instructions if there is a jump.
			if ((write_opcode == JAL || write_opcode == JALR || (write_opcode == BRANCH && branch_condition_in)) && PIPELINED) begin
				if (DEBUG) $display("JUMP: Beginning squash of %0d instructions", 4'b0101);
				squash_time <= 4'b0101;
				flush_alu_out <= ONE_1;
				no_stall_out <= ONE_1;
			end

			case(write_opcode)
				LUI: begin
					if (DEBUG) $display("LUI: Writing 0x%8h to register x%0d", alu_result_in, get_rd(inst_in));
					if (PIPELINED) begin
						pc_write_enable <= ZERO_1;
					end else begin
						new_pc_out <= pc_in + 4;
						pc_write_enable <= ONE_1;
					end
					rd_write_enable <= ONE_1;
					rd_value_out <= alu_result_in;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				AUIPC: begin
					if (DEBUG) $display("AUIPC: Writing 0x%8h to register x%0d", alu_result_in, get_rd(inst_in));
					if (PIPELINED) begin
						pc_write_enable <= ZERO_1;
					end else begin
						new_pc_out <= pc_in + 4;
						pc_write_enable <= ONE_1;
					end
					rd_write_enable <= ONE_1;
					rd_value_out <= alu_result_in;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				JAL: begin
					if (DEBUG) $display("JAL: Jumping to address = 0x%8h", pc_in + get_imm(inst_in));
					new_pc_out <= pc_in + imm;
					pc_write_enable <= ONE_1;
					rd_write_enable <= ONE_1;
					rd_value_out <= alu_result_in;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				JALR: begin
					if (DEBUG) $display("JALR: Jumping to address = 0x%8h", get_imm(inst_in) + rs1_value_in);
					new_pc_out <= imm + rs1_value_in;
					pc_write_enable <= ONE_1;
					rd_write_enable <= ONE_1;
					rd_value_out <= alu_result_in;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				BRANCH: begin
					if (branch_condition_in) begin
						if (DEBUG) $display("Branch taken: Jumping to address = 0x%8h", pc_in + get_imm(inst_in));
						new_pc_out <= pc_in + imm;
						pc_write_enable <= ONE_1;
					end else begin
						if (DEBUG) $display("Branch not taken: Advancing to address = 0x%8h", pc_in + 4);
						if (PIPELINED) begin
							pc_write_enable <= ZERO_1;
						end else begin
							new_pc_out <= pc_in + 4;
							pc_write_enable <= ONE_1;
						end
					end
					rd_write_enable <= ZERO_1;
					rd_value_out <= ZERO_32;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				LOAD: begin
					if (DEBUG) $display("LOAD: Writing 0x%8h to register x%0d", (inst_load_in | data_load_in), get_rd(inst_in));
					if (PIPELINED) begin
						pc_write_enable <= ZERO_1;
					end else begin
						new_pc_out <= pc_in + 4;
						pc_write_enable <= ONE_1;
					end
					rd_write_enable <= ONE_1;
					rd_value_out <= inst_load_in | data_load_in;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				STORE: begin
					if (DEBUG) $display("STORE: Writing 0x%8h to address 0x%8h", rs2_value_in, alu_result_in);
					if (PIPELINED) begin
						pc_write_enable <= ZERO_1;
					end else begin
						new_pc_out <= pc_in + 4;
						pc_write_enable <= ONE_1;
					end
					rd_write_enable <= ZERO_1;
					rd_value_out <= ZERO_32;
					store_enable <= ONE_1;
					store_value_out <= rs2_value_in;
					store_addr <= alu_result_in;
				end
				OP_IMM: begin
					if (DEBUG) $display("OP_IMM: Writing 0x%8h to register x%0d", alu_result_in, get_rd(inst_in));
					if (PIPELINED) begin
						pc_write_enable <= ZERO_1;
					end else begin
						new_pc_out <= pc_in + 4;
						pc_write_enable <= ONE_1;
					end
					rd_write_enable <= ONE_1;
					rd_value_out <= alu_result_in;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				OP_REG: begin
					if (DEBUG) $display("OP_REG: Writing 0x%8h to register x%0d", alu_result_in, get_rd(inst_in));
					if (PIPELINED) begin
						pc_write_enable <= ZERO_1;
					end else begin
						new_pc_out <= pc_in + 4;
						pc_write_enable <= ONE_1;
					end
					rd_write_enable <= ONE_1;
					rd_value_out <= alu_result_in;
					store_enable <= ZERO_1;
					store_value_out <= ZERO_32;
					store_addr <= ZERO_32;
				end
				default;
			endcase
		end else begin
			pc_write_enable <= ZERO_1;
			rd_write_enable <= ZERO_1;
			store_enable <= ZERO_1;
		end
	end
endmodule
