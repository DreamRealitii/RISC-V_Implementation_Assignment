// Registers of a processor, can load up to two and store up to one per instruction.
`include "riscv.sv"

module register_file (inst_out, inst_valid_out, pc_out, rs1_value_out, rs2_value_out, clk, rst,
		      inst_in, inst_valid_in, pc_in, rd_write_enable, rd_sel_in, rd_value_in);

	// Circuit inputs.
	input                 clk, rst;

	// Instruction.
	output reg [BITS-1:0] inst_out, pc_out;
	output reg            inst_valid_out;
	input      [BITS-1:0] inst_in, pc_in;
	input                 inst_valid_in;

	// Register load stage.
	output reg [BITS-1:0] rs1_value_out, rs2_value_out;
	logic      [4:0]      rs1_sel, rs2_sel;
	           opcode     opcode_in;

	// Write stage.
	input      [4:0]      rd_sel_in;
	input      [BITS-1:0] rd_value_in;
	input                 rd_write_enable;

	// Instruction decode.
	assign opcode_in = get_opcode(inst_in);
	assign rs1_sel   =    get_rs1(inst_in);
	assign rs2_sel   =    get_rs2(inst_in);

	// 32 32-bit registers.
	reg    [BITS-1:0] registers [31:0];

	// Initialize registers to zero.
	initial begin
		for(int i = 0; i < 32; i = i + 1)
			registers[i] = ZERO_32;

		inst_out = NOP;
		inst_valid_out = ZERO_1;
		pc_out = ZERO_32;
		rs1_value_out = ZERO_32;
		rs2_value_out = ZERO_32;
	end

	always @(inst_out) begin
		if (DEBUG) $display("PC at Stage 2          = 0x%8h", pc_out);
		if (DEBUG) $display("Instruction at Stage 2 = 0x%8h", inst_out);
	end

	always @(posedge clk) begin
		if (rst) begin
			rs1_value_out <= ZERO_32;
			rs2_value_out <= ZERO_32;
			inst_out <= NOP;
			inst_valid_out <= ZERO_1;
			pc_out <= ZERO_32;
			for(int i = 0; i < 32; i = i + 1)
				registers[i] <= ZERO_32;
		end else if (inst_valid_in) begin
			inst_out <= inst_in;
			pc_out <= pc_in;
	
			// Register read.
			if (opcode_in != LUI && opcode_in != AUIPC && opcode_in != JAL) begin
				rs1_value_out <= registers[rs1_sel];
				if (DEBUG) $display("Loading register rs1 x%0d with value 0x%8h", rs1_sel, registers[rs1_sel]);
			end
			if (opcode_in == BRANCH || opcode_in == STORE || opcode_in == OP_REG) begin
				rs2_value_out <= registers[rs2_sel];
				if (DEBUG) $display("Loading register rs2 x%0d with value 0x%8h", rs2_sel, registers[rs2_sel]);
			end
		end

		if (!rst) inst_valid_out <= inst_valid_in;

		// Register write.
		if (rd_write_enable && rd_sel_in != 0) begin
			// Check that stack grows downwards.				
			if (rd_sel_in == 2 && rd_value_in > 16'h7530) begin
				$display("Something went wrong. Stack register shouldn't be negative or higher than 0x7530.");
				$finish;				
			end
			registers[rd_sel_in] <= rd_value_in;
			if (DEBUG) $display("Writing 0x%8h to register x%0d", rd_value_in, rd_sel_in);
		end else if (DEBUG && rd_write_enable && rd_sel_in == 0) $display("Blocked write to register x0.");
	end
endmodule
