// Module representing a full CPU core by creating a program counter, instruction memory, ALU, and data memory, then connecting them together.
`include "riscv.sv"

module core (clk, rst);
	input clk, rst;

	// Split the clock.
	/*reg clk1, clk2, clk3, clk4, clk5, clk6;
	initial begin
		clk1 = 0;
		clk2 = 0;
		clk3 = 0;
		clk4 = 0;
		clk5 = 0;
		clk6 = 0;
	end
	always @(posedge clk) begin
		    if (rst ) begin
			//if (DEBUG) $display("Reset");
			clk1 <= 0;
			clk2 <= 0;
			clk3 <= 0;
			clk4 <= 0;
			clk5 <= 0;
			clk6 <= 0;
		end else if (!rst && !clk1 && !clk2 && !clk3 && !clk4 && !clk5 && !clk6) begin
			if (DEBUG) $display("\nClock");
			clk1 <= 1;
			clk2 <= 0;
			clk3 <= 0;
			clk4 <= 0;
			clk5 <= 0;
			clk6 <= 0;
		end else if (clk1) begin
			//if (DEBUG) $display("Clock 2");
			clk1 <= 0;
			clk2 <= 1;
			clk3 <= 0;
			clk4 <= 0;
			clk5 <= 0;
			clk6 <= 0;
		end else if (clk2) begin
			if (DEBUG) $display("\nClock");
			clk1 <= 1;
			clk2 <= 0;
			clk3 <= 0;
			clk4 <= 0;
			clk5 <= 0;
			clk6 <= 0;
		end else if (clk3) begin
			//if (DEBUG) $display("Clock 4");
			clk1 <= 0;
			clk2 <= 0;
			clk3 <= 0;
			clk4 <= 1;
			clk5 <= 0;
		end else if (clk4) begin
			//if (DEBUG) $display("Clock 5");
			clk1 <= 0;
			clk2 <= 0;
			clk3 <= 0;
			clk4 <= 0;
			clk5 <= 1;
			clk6 <= 0;
		end else if (clk5) begin
			//if (DEBUG) $display("Clock 6");
			clk1 <= 0;
			clk2 <= 0;
			clk3 <= 0;
			clk4 <= 0;
			clk5 <= 0;
			clk6 <= 1;
		end else if (clk6) begin
			if (DEBUG) $display("\nClock 1");
			clk1 <= 1;
			clk2 <= 0;
			clk3 <= 0;
			clk4 <= 0;
			clk5 <= 0;
			clk6 <= 0;
		end
	end*/

	always @(posedge clk)
		if (DEBUG) $display("\nClock");

	// Wires and modules.
	wire [BITS-1:0] pc_to_instmem, pc_to_regfile, pc_to_alu, pc_to_datamem, pc_to_writer, new_pc_to_pc;
	wire [BITS-1:0] inst_to_regfile, inst_to_alu, inst_to_bothmem, inst_to_writer;
	wire [BITS-1:0] rs1_value_to_alu, rs1_value_to_datamem, rs1_value_to_writer;
	wire [BITS-1:0] rs2_value_to_alu, rs2_value_to_datamem, rs2_value_to_writer;
	wire [BITS-1:0] alu_result_to_bothmem, alu_result_to_writer;
	wire [BITS-1:0] inst_load_to_writer, data_load_to_writer;
	wire [BITS-1:0] rd_value_to_regfile, store_addr_to_bothmem, store_value_to_bothmem;
	wire [4:0]      rd_sel_to_regfile;
	wire [2:0]      stall_time_to_writer;
	wire store_type store_type_to_bothmem;
	wire            write_enable_to_regfile, write_enable_to_pc, store_enable_to_bothmem;
	wire            branch_condition_to_datamem, branch_condition_to_writer;
	wire            inst_valid_to_instmem, inst_valid_to_regfile, inst_valid_to_alu, inst_valid_to_bothmem, inst_valid_to_writer;
	wire		stall_to_pc, flush_alu, no_stall_to_instmem;

	program_counter progcou (.pc_out(pc_to_instmem), .inst_valid_out(inst_valid_to_instmem), .clk(clk), .rst(rst),
				 .new_pc_in(new_pc_to_pc), .write_enable(write_enable_to_pc), .stall_in(stall_to_pc));
	instruction_memory instmem (.inst_out(inst_to_regfile), .inst_valid_out(inst_valid_to_regfile), .pc_out(pc_to_regfile),
				    .inst_load_out(inst_load_to_writer), .stall_out(stall_to_pc), .stall_time(stall_time_to_writer), .pc_in(pc_to_instmem),
				    .inst_valid_in(inst_valid_to_instmem), .alu_inst_in(inst_to_bothmem), .alu_inst_valid(inst_valid_to_bothmem),
				    .inst_load_addr(alu_result_to_bothmem), .inst_store_enable(store_enable_to_bothmem),
				    .inst_store_type(store_type_to_bothmem), .inst_store_addr(store_addr_to_bothmem),
				    .inst_store_in(store_value_to_bothmem), .no_stall_in(no_stall_to_instmem), .clk(clk), .rst(rst));
	register_file regfile (.inst_out(inst_to_alu), .inst_valid_out(inst_valid_to_alu), .pc_out(pc_to_alu), .rs1_value_out(rs1_value_to_alu),
			       .rs2_value_out(rs2_value_to_alu), .clk(clk), .rst(rst),
			       .inst_in(inst_to_regfile), .inst_valid_in(inst_valid_to_regfile), .pc_in(pc_to_regfile), .rd_write_enable(write_enable_to_regfile),
			       .rd_sel_in(rd_sel_to_regfile), .rd_value_in(rd_value_to_regfile));
	alu alunit (.inst_out(inst_to_bothmem), .inst_valid_out(inst_valid_to_bothmem), .pc_out(pc_to_datamem), .alu_result_out(alu_result_to_bothmem), 
		    .branch_condition_out(branch_condition_to_datamem), .rs1_value_out(rs1_value_to_datamem),
		    .rs2_value_out(rs2_value_to_datamem), .clk(clk), .rst(rst), .inst_in(inst_to_alu), .inst_valid_in(inst_valid_to_alu),
		    .pc_in(pc_to_alu), .rs1_value_in(rs1_value_to_alu), .rs2_value_in(rs2_value_to_alu), .flush_alu_in(flush_alu));
	data_memory datamem (.data_load_out(data_load_to_writer), .inst_out(inst_to_writer), .inst_valid_out(inst_valid_to_writer), .pc_out(pc_to_writer),
			     .rs1_value_out(rs1_value_to_writer), .rs2_value_out(rs2_value_to_writer),
			     .alu_result_out(alu_result_to_writer), .branch_condition_out(branch_condition_to_writer),
			     .clk(clk), .rst(rst), .inst_in(inst_to_bothmem), .inst_valid_in(inst_valid_to_bothmem), .pc_in(pc_to_datamem),
			     .rs1_value_in(rs1_value_to_datamem), .rs2_value_in(rs2_value_to_datamem),
			     .alu_result_in(alu_result_to_bothmem), .branch_condition_in(branch_condition_to_datamem), 
			     .data_store_addr(store_addr_to_bothmem), .data_store_in(store_value_to_bothmem),
			     .data_store_type(store_type_to_bothmem), .data_store_enable(store_enable_to_bothmem));
	le_writer writer (.new_pc_out(new_pc_to_pc), .pc_write_enable(write_enable_to_pc), .rd_write_enable(write_enable_to_regfile),
			  .rd_value_out(rd_value_to_regfile), .store_enable(store_enable_to_bothmem),
			  .write_store_type(store_type_to_bothmem), .store_addr(store_addr_to_bothmem),
			  .store_value_out(store_value_to_bothmem), .rd_sel_out(rd_sel_to_regfile), .flush_alu_out(flush_alu), .no_stall_out(no_stall_to_instmem),
			  .clk(clk), .rst(rst), .inst_in(inst_to_writer), .inst_valid_in(inst_valid_to_writer), .pc_in(pc_to_writer),
			  .rs1_value_in(rs1_value_to_writer), .rs2_value_in(rs2_value_to_writer),
			  .alu_result_in(alu_result_to_writer), .inst_load_in(inst_load_to_writer),
			  .data_load_in(data_load_to_writer), .branch_condition_in(branch_condition_to_writer), .stall_time_in(stall_time_to_writer));

endmodule
