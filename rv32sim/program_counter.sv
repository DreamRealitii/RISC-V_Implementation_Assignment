// Module that receives, stores, and sends the next instruction address.
// Resetting sets program counter to reset_pc.
`include "riscv.sv"

module program_counter (pc_out, inst_valid_out, clk, rst, new_pc_in, write_enable, stall_in);
	// Circuit inputs.
	input             clk, rst;

	// Instruction load stage.
	output reg [BITS-1:0] pc_out;
	output reg            inst_valid_out;

	// Write stage.
	input      [BITS-1:0] new_pc_in;
	input                 write_enable;

	// Pipeline stuff.
	input                 stall_in;
	reg                   stall_start; // Needed to set back PC by 4 at beginning of pipeline stall.

	initial begin
		pc_out = RESET_PC;
		inst_valid_out = ONE_1;
		stall_start = ZERO_1;
		$display("Starting processor\n");
	end
		
	// Update pc on write stage.
	always @(posedge clk) begin
		if (rst) begin
			if (DEBUG) $display("Reseting PC to 0x%8h", RESET_PC);
			pc_out <= RESET_PC;
			inst_valid_out <= ONE_1;
			stall_start <= ZERO_1;
		end else if (write_enable) begin
			if (DEBUG) $display("Setting PC to 0x%8h", new_pc_in);
			pc_out <= new_pc_in;
			inst_valid_out <= ONE_1;
			stall_start <= ZERO_1; // In case of stall right after jump.
		end else if (stall_in) begin
			if (stall_start) begin
				pc_out <= pc_out - 4;
				stall_start <= ZERO_1;
			end else begin
				pc_out <= pc_out;
			end
			inst_valid_out <= ZERO_1;
		end else begin
			pc_out <= pc_out + 4;
			if (PIPELINED) begin
				if (DEBUG) $display("PC advances to 0x%8h", pc_out + 4);
				inst_valid_out <= ONE_1;
			end else inst_valid_out <= ZERO_1;
			stall_start <= ONE_1;
		end
	end 
	
endmodule
