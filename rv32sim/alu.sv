// Module that performs logical and arithmetic operations on two operands and selects one to output.
`include "riscv.sv"

module alu (inst_out, inst_valid_out, pc_out, alu_result_out, branch_condition_out, rs1_value_out, rs2_value_out,
	    clk, rst, inst_in, inst_valid_in, pc_in, rs1_value_in, rs2_value_in, flush_alu_in);

	// Circuit inputs.
	input         clk, rst;

	// Calculation stage.
	output reg [BITS-1:0] alu_result_out;
	output reg [BITS-1:0] rs1_value_out, rs2_value_out;
	output reg            branch_condition_out;
	input      [BITS-1:0] rs1_value_in, rs2_value_in;

	// Instruction.
	output reg [BITS-1:0]  inst_out, pc_out;
	output reg             inst_valid_out;
	input      [BITS-1:0]  inst_in, pc_in;
	input                  inst_valid_in;
	logic      [4:0]       rs1_sel, rs2_sel, rd_sel;
	logic      [BITS-1:0]  imm, shamt;
	           opcode      alu_opcode;
	           branch_type alu_branch_type;
	           op_imm_type alu_op_imm_type;
	           op_reg_type alu_op_reg_type;
	           sr_i_type   alu_sr_i_type;
	           add_type    alu_add_type;
	           sr_type     alu_sr_type;

	// Pipeline stuff.
	input                  flush_alu_in;
	reg        [BITS-1:0]  last_result [3:0];
	reg        [4:0]       last_rd_sel [3:0];
	
	function void save_result;
		input [BITS-1:0] result;
		input [4:0]      rd_sel;
		begin
			last_result[3] <= last_result[2];
			last_result[2] <= last_result[1];
			last_result[1] <= last_result[0];
			last_result[0] <= result;

			last_rd_sel[3] <= last_rd_sel[2];
			last_rd_sel[2] <= last_rd_sel[1];
			last_rd_sel[1] <= last_rd_sel[0];
			last_rd_sel[0] <= rd_sel;
		end
	endfunction

	function void flush_results;
		begin
			if (DEBUG) $display("ALU: Flushing stored results");
			last_result[0] <= ZERO_32;
			last_result[1] <= ZERO_32;
			last_result[2] <= ZERO_32;
			last_result[3] <= ZERO_32;

			last_rd_sel[0] <= 5'b00000;
			last_rd_sel[1] <= 5'b00000;
			last_rd_sel[2] <= 5'b00000;
			last_rd_sel[3] <= 5'b00000;
		end
	endfunction

	function [BITS-1:0] real_rs_value;
		input [BITS-1:0] loaded_rs_value;
		input [4:0]      rs_sel;
		input            print;
		begin
			if (last_rd_sel[0] == rs_sel && rs_sel != 5'b00000) begin
				real_rs_value = last_result[0];
				if (DEBUG && print) $display("ALU: Register x%0d's value loaded from 1 stage ahead.", rs_sel);
			end else if (last_rd_sel[1] == rs_sel && rs_sel != 5'b00000) begin
				real_rs_value = last_result[1];
				if (DEBUG && print) $display("ALU: Register x%0d's value loaded from 2 stages ahead.", rs_sel);
			end else if (last_rd_sel[2] == rs_sel && rs_sel != 5'b00000) begin
				real_rs_value = last_result[2];
				if (DEBUG && print) $display("ALU: Register x%0d's value loaded from 3 stages ahead.", rs_sel);
			end else if (last_rd_sel[3] == rs_sel && rs_sel != 5'b00000) begin
				real_rs_value = last_result[3];
				if (DEBUG && print) $display("ALU: Register x%0d's value loaded from 4 stages ahead.", rs_sel);
			end else begin
				real_rs_value = loaded_rs_value;
			end		
		end
	endfunction

	// Instruction decode.
	assign alu_opcode      =      get_opcode(inst_in);

	assign rs1_sel         =         get_rs1(inst_in);
	assign rs2_sel         =         get_rs2(inst_in);
	assign rd_sel          =          get_rd(inst_in);

	assign alu_branch_type = get_branch_type(inst_in);
	assign alu_op_imm_type = get_op_imm_type(inst_in);
	assign alu_op_reg_type = get_op_reg_type(inst_in);

	assign alu_sr_i_type   =   get_sr_i_type(inst_in);
	assign alu_add_type    =    get_add_type(inst_in);
	assign alu_sr_type     =     get_sr_type(inst_in);

	assign imm             =         get_imm(inst_in);
	assign shamt           =       get_shamt(inst_in);

	initial begin
		alu_result_out = ZERO_32;
		rs1_value_out = ZERO_32;
		rs2_value_out = ZERO_32;
		branch_condition_out = ZERO_1;
		inst_out = NOP;
		inst_valid_out = ZERO_1;
		pc_out = ZERO_32;
	end

	always @(inst_out) begin
		if (DEBUG && inst_valid_in) $display("PC at Stage 3          = 0x%8h", pc_out);
		if (DEBUG && inst_valid_in) $display("Instruction at Stage 3 = 0x%8h", inst_out);
	end

	always @(posedge clk) begin
		if (rst) begin
			alu_result_out <= ZERO_32;
			rs1_value_out <= ZERO_32;
			rs2_value_out <= ZERO_32;
			branch_condition_out <= ZERO_1;
			inst_out <= NOP;
			inst_valid_out <= ZERO_1;
			pc_out <= ZERO_32;
		end else if (flush_alu_in) begin
			flush_results();
			inst_out <= inst_in;
			pc_out <= pc_in;
		end else if (inst_valid_in) begin
			rs1_value_out <= real_rs_value(rs1_value_in, rs1_sel, ONE_1);	
			rs2_value_out <= real_rs_value(rs2_value_in, rs2_sel, ONE_1);
			inst_out <= inst_in;
			pc_out <= pc_in;

			case (alu_opcode)
				LUI   : begin
					alu_result_out <= imm;
					branch_condition_out <= ZERO_1;
					save_result(imm, rd_sel);
					if (DEBUG) $display("LUI: Loaded value 0x%8h", imm);
				end
				AUIPC : begin
					alu_result_out <= imm + pc_in;
					branch_condition_out <= ZERO_1;
					save_result(imm + pc_in, rd_sel);
					if (DEBUG) $display("AUIPC: Loaded value 0x%8h", imm + pc_in);
				end
				JAL   : begin
					alu_result_out <= pc_in + 4;
					branch_condition_out <= ZERO_1;
					save_result(pc_in + 4, rd_sel);
					if (DEBUG) $display("JAL: Return address = 0x%8h", pc_in + 4);
				end
				JALR  : begin
					alu_result_out <= pc_in + 4;
					branch_condition_out <= ZERO_1;
					save_result(pc_in + 4, rd_sel);
					if (DEBUG) $display("JALR: Return address = 0x%8h", pc_in + 4);
				end
				BRANCH: begin
					case (alu_branch_type)
						    BEQ : begin
							branch_condition_out <= (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) == real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
							if (DEBUG) $display("BEQ: (%8h == %8h) = %1b",
								 real_rs_value(rs1_value_in, rs1_sel, ZERO_1), real_rs_value(rs2_value_in, rs2_sel, ZERO_1), (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) == real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end BNE : begin 
							branch_condition_out <= (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) != real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
							if (DEBUG) $display("BNE: (%8h != %8h) = %1b",
								 real_rs_value(rs1_value_in, rs1_sel, ZERO_1), real_rs_value(rs2_value_in, rs2_sel, ZERO_1), (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) != real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end BLT : begin 
							branch_condition_out <= signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) <  signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
							if (DEBUG) $display("BLT: (%8h < %8h) = %1b",
								 real_rs_value(rs1_value_in, rs1_sel, ZERO_1), real_rs_value(rs2_value_in, rs2_sel, ZERO_1), signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end BGE : begin 
							branch_condition_out <= signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >= signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
							if (DEBUG) $display("BGE: (%8h >= %8h) = %1b",
								 real_rs_value(rs1_value_in, rs1_sel, ZERO_1), real_rs_value(rs2_value_in, rs2_sel, ZERO_1), signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >= signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end BLTU: begin 
							branch_condition_out <= unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) <  unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
							if (DEBUG) $display("BLTU: (%8h < %8h) = %1b",
								 real_rs_value(rs1_value_in, rs1_sel, ZERO_1), real_rs_value(rs2_value_in, rs2_sel, ZERO_1), unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) <  unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end BGEU: begin
							branch_condition_out <= unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >= unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
							if (DEBUG) $display("BGEU: (%8h >= %8h) = %1b",
								 real_rs_value(rs1_value_in, rs1_sel, ZERO_1), real_rs_value(rs2_value_in, rs2_sel, ZERO_1), unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >= unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end default: branch_condition_out <= ZERO_1;
					endcase
					alu_result_out <= ZERO_32;
					save_result(32'h13572468, 5'b00000); // Should never read this value.
				end
				LOAD  : begin
					alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) + imm;
					branch_condition_out <= ZERO_1;
					// Should never read this value (correct value is in memory and needs to stall).
					save_result(32'h13572468, 5'b00000);
					if (DEBUG) $display("LOAD: Calculated address 0x%8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1) + imm);
				end
				STORE : begin
					alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) + imm;
					branch_condition_out <= ZERO_1;
					save_result(32'h13572468, 5'b00000); // Should never read this value.
					if (DEBUG) $display("STORE: Calculated address 0x%8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1) + imm);
				end
				OP_IMM: begin
					case (alu_op_imm_type)
						    ADDI : begin
							alu_result_out <= signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) + signed'(imm);
							if (DEBUG) $display("ADDI: (%8h + %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 imm, signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) + signed'(imm));
							save_result(signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) + signed'(imm), rd_sel);
						end SLTI : begin 
							if (signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < signed'(imm)) begin
								alu_result_out <= ONE_32;
								save_result(ONE_32, rd_sel);
							end else begin
								alu_result_out <= ZERO_32;
								save_result(ZERO_32, rd_sel);
							end if (DEBUG) $display("SLTI: (%8h < %8h) = %1b", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 imm, signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < signed'(imm));
						end SLTIU: begin
							if (unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < unsigned'(imm)) begin
								alu_result_out <= ONE_32;
								save_result(ONE_32, rd_sel);
							end else begin 
								alu_result_out <= ZERO_32;
								save_result(ZERO_32, rd_sel);
							end if (DEBUG) $display("SLTIU: (%8h < %8h) = %1b", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 imm, unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < unsigned'(imm));
						end XORI : begin 
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) ^ imm;
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) ^ imm, rd_sel);
							if (DEBUG) $display("XORI: (%8h ^ %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 imm, (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) ^ imm));
						end ORI  : begin 
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) | imm;
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) | imm, rd_sel);
							if (DEBUG) $display("ORI: (%8h | %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 imm, (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) | imm));
						end ANDI : begin 
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) & imm;
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) & imm, rd_sel);
							if (DEBUG) $display("ANDI: (%8h & %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 imm, (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) & imm));
						end SLLI : begin 
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) << shamt;
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) << imm, rd_sel);
							if (DEBUG) $display("XORI: (%8h << %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 imm, (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) << imm));
						end SR_I : begin 
							if (alu_sr_i_type == SRLI) begin
								alu_result_out <= unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >> unsigned'(shamt);
								save_result(unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >> unsigned'(shamt), rd_sel);
								if (DEBUG) $display("SRLI: (%8h >> %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 imm, unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >> unsigned'(imm));
							end else begin
								alu_result_out <=   signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >>>   signed'(shamt);
								save_result(signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >>> signed'(shamt), rd_sel);
								if (DEBUG) $display("SRAI: (%8h >> %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 imm, signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >>> unsigned'(imm));
							end
						end default: begin
							alu_result_out <= ZERO_32;
							save_result(ZERO_32, 5'b00000);
						end
					endcase
					branch_condition_out <= ZERO_1;
				end
				OP_REG: begin
					case (alu_op_reg_type)
						    ADD_: begin if (alu_add_type == ADD) begin
								alu_result_out <= signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) + signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
								save_result(signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) + signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)), rd_sel);
								if (DEBUG) $display("ADD: (%8h + %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) + signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						        end else begin
								alu_result_out <= signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) - signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
								save_result(signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) - signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)), rd_sel);
								if (DEBUG) $display("SUB: (%8h - %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) - signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
							end
						end SLL : begin 
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) << real_rs_value(rs2_value_in, rs2_sel, ZERO_1);
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) << real_rs_value(rs2_value_in, rs2_sel, ZERO_1), rd_sel);
							if (DEBUG) $display("SLL: (%8h << %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) << real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end SLT : begin if (  signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1))) begin
									alu_result_out <= ONE_32;
									save_result(ONE_32, rd_sel);
								end else begin
									alu_result_out <= ZERO_32;
									save_result(ZERO_32, rd_sel);
								end if (DEBUG) $display("SLT: (%8h < %8h) = %1b", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end SLTU: begin if (unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1))) begin
									alu_result_out <= ONE_32;
									save_result(ONE_32, rd_sel);
								end else begin
									alu_result_out <= ZERO_32;
									save_result(ZERO_32, rd_sel);
								end if (DEBUG) $display("SLTU: (%8h < %8h) = %1b", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) < unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end XOR : begin
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) ^ real_rs_value(rs2_value_in, rs2_sel, ZERO_1);
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) ^ real_rs_value(rs2_value_in, rs2_sel, ZERO_1), rd_sel);
							if (DEBUG) $display("XOR: (%8h < %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) ^ real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end SR_ : begin if (alu_sr_type == SRL) begin
								alu_result_out <= unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >> unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
								save_result(unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >> unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)), rd_sel);
								if (DEBUG) $display("SRL: (%8h >> %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), unsigned'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >> unsigned'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
							end else begin
								alu_result_out <=   signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >>> signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1));
								save_result(signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >>> signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)), rd_sel);
								if (DEBUG) $display("SRA: (%8h >> %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
									 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), signed'(real_rs_value(rs1_value_in, rs1_sel, ZERO_1)) >>> signed'(real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
							end
						end OR  : begin
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) | real_rs_value(rs2_value_in, rs2_sel, ZERO_1);
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) | real_rs_value(rs2_value_in, rs2_sel, ZERO_1), rd_sel);
							if (DEBUG) $display("OR: (%8h < %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) | real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end AND : begin
							alu_result_out <= real_rs_value(rs1_value_in, rs1_sel, ZERO_1) & real_rs_value(rs2_value_in, rs2_sel, ZERO_1);
							save_result(real_rs_value(rs1_value_in, rs1_sel, ZERO_1) & real_rs_value(rs2_value_in, rs2_sel, ZERO_1), rd_sel);
							if (DEBUG) $display("AND: (%8h < %8h) = %8h", real_rs_value(rs1_value_in, rs1_sel, ZERO_1),
								 real_rs_value(rs2_value_in, rs2_sel, ZERO_1), (real_rs_value(rs1_value_in, rs1_sel, ZERO_1) & real_rs_value(rs2_value_in, rs2_sel, ZERO_1)));
						end default: begin
							alu_result_out <= ZERO_32;
							save_result(ZERO_32, 5'b00000);
						end
					endcase
					branch_condition_out <= ZERO_1;
				end
				default: begin
					alu_result_out <= ZERO_32;
					save_result(ZERO_32, 5'b00000);
					branch_condition_out <= ZERO_1;
				end
			endcase
		end else begin
			save_result(ZERO_32, 5'b00000);
		end
		if (!rst) inst_valid_out <= inst_valid_in;
	end
endmodule
