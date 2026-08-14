// Memory where data is read and stored, can read or store once per instruction.
`include "riscv.sv"

module data_memory (data_load_out, inst_out, inst_valid_out, pc_out, rs1_value_out, rs2_value_out, alu_result_out, branch_condition_out,
		    clk, rst, inst_in, inst_valid_in, pc_in, rs1_value_in, rs2_value_in, alu_result_in, branch_condition_in, 
		    data_store_addr, data_store_in, data_store_type, data_store_enable);
	// Circuit inputs.
	input                 clk, rst;

	// Instruction.
	output reg [BITS-1:0] inst_out, pc_out;
	output reg            inst_valid_out;
	input      [BITS-1:0] inst_in, pc_in;
	input                 inst_valid_in;
	           opcode     data_opcode;
	           load_type  data_load_type;


	// Data read stage.
	output reg [BITS-1:0] data_load_out;
	output reg [BITS-1:0] rs1_value_out;  //   Value in JALR  instruction  written to pc.
	output reg [BITS-1:0] rs2_value_out;  //   Value in store instruction.
	output reg [BITS-1:0] alu_result_out; //   Value in other instructions written to rd.
	output reg            branch_condition_out;
	input      [BITS-1:0] rs1_value_in, rs2_value_in;
	input      [BITS-1:0] alu_result_in;  // Address in load  instruction.
	input                 branch_condition_in;

	// Data write stage.
	input      [BITS-1:0] data_store_addr, data_store_in;
	input      store_type data_store_type;
	input                 data_store_enable;

	// Memory.
	reg    [BYTE_SIZE-1:0] memory [DATA_MEMORY_BYTES-1:0];

	// Instruction decode.
	assign data_opcode    =    get_opcode(inst_in);
	assign data_load_type = get_load_type(inst_in);
	
	// Load data on start.
	reg    [BYTE_SIZE-1:0] load_mem [0:2047];
	initial begin
		$readmemh("test0.hex", load_mem);
		for (int i = 1024; i < 2047; i++)
			memory[(i*4)+0-DATA_MEMORY_ADDR_START] = load_mem[i];
		$readmemh("test1.hex", load_mem);
		for (int i = 1024; i < 2047; i++)
			memory[(i*4)+1-DATA_MEMORY_ADDR_START] = load_mem[i];
		$readmemh("test2.hex", load_mem);
		for (int i = 1024; i < 2047; i++)
			memory[(i*4)+2-DATA_MEMORY_ADDR_START] = load_mem[i];
		$readmemh("test3.hex", load_mem);
		for (int i = 1024; i < 2047; i++)
			memory[(i*4)+3-DATA_MEMORY_ADDR_START] = load_mem[i];

		data_load_out = ZERO_32;
		inst_out = NOP;
		inst_valid_out = ZERO_1;
		pc_out = ZERO_32;
		rs1_value_out = ZERO_32;
		rs2_value_out = ZERO_32;
		alu_result_out = ZERO_32;
		branch_condition_out = ZERO_1;
	end

	always @(inst_out) begin
		if (DEBUG) $display("PC at Stage 4          = 0x%8h", pc_out);
		if (DEBUG) $display("Instruction at Stage 4 = 0x%8h", inst_out);
	end

	// Read from data memory.
	always @(posedge clk) begin
		if (rst) begin
			data_load_out <= ZERO_32;
			inst_out <= NOP;
			inst_valid_out <= ZERO_1;
			pc_out <= ZERO_32;
			rs1_value_out <= ZERO_32;
			rs2_value_out <= ZERO_32;
			alu_result_out <= ZERO_32;
			branch_condition_out <= ZERO_1;
		end else if (inst_valid_in) begin
			inst_out <= inst_in;
			pc_out <= pc_in;
			rs1_value_out <= rs1_value_in;
			rs2_value_out <= rs2_value_in;
			alu_result_out <= alu_result_in;
			branch_condition_out <= branch_condition_in;

			// Read from memory.
			if (data_opcode == LOAD) begin
				// Read 8/16/32 bits depending on load_type_in.
				case(data_load_type)
					LB : begin
						if (alu_result_in >= DATA_MEMORY_ADDR_START) begin
							data_load_out[31:8] <= {24{memory[alu_result_in - DATA_MEMORY_ADDR_START + 0][0]}};
							data_load_out[7: 0] <=     memory[alu_result_in - DATA_MEMORY_ADDR_START + 0];
							/*if (DEBUG) $display("LB: Reading from address 0x%8h = 0x%8h", alu_result_in,
								{{24{memory[alu_result_in - DATA_MEMORY_ADDR_START][0]}},
								memory[alu_result_in - DATA_MEMORY_ADDR_START]});*/
						end
					end
					LH : begin
						if (alu_result_in >= DATA_MEMORY_ADDR_START) begin
							data_load_out[31:16] <= {16{memory[alu_result_in - DATA_MEMORY_ADDR_START + 1][0]}};
							data_load_out[15: 0] <=    {memory[alu_result_in - DATA_MEMORY_ADDR_START + 1],
								                    memory[alu_result_in - DATA_MEMORY_ADDR_START + 0]};
							/*if (DEBUG) $display("LH: Reading from address 0x%8h = 0x%8h", alu_result_in,
								{{16{memory[alu_result_in - DATA_MEMORY_ADDR_START + 1][0]}},
								{memory[alu_result_in - DATA_MEMORY_ADDR_START + 1],
								memory[alu_result_in - DATA_MEMORY_ADDR_START + 0]}});*/
						end
					end
					LW : begin
						if (alu_result_in >= DATA_MEMORY_ADDR_START) begin
							data_load_out <= {memory[alu_result_in - DATA_MEMORY_ADDR_START+3],
								          memory[alu_result_in - DATA_MEMORY_ADDR_START+2],
								          memory[alu_result_in - DATA_MEMORY_ADDR_START+1],
								          memory[alu_result_in - DATA_MEMORY_ADDR_START+0]};
						/*if (DEBUG) $display("LW: Reading from address 0x%8h = 0x%8h", alu_result_in,
							{memory[alu_result_in - DATA_MEMORY_ADDR_START+3],
						       memory[alu_result_in - DATA_MEMORY_ADDR_START+2],
						       memory[alu_result_in - DATA_MEMORY_ADDR_START+1],
						       memory[alu_result_in - DATA_MEMORY_ADDR_START+0]});*/
						end
					end
					LBU:
						if (alu_result_in >= DATA_MEMORY_ADDR_START) begin
							data_load_out <= {{24{1'b0}}, memory[alu_result_in - DATA_MEMORY_ADDR_START]};
							/*if (DEBUG) $display("LBU: Reading from address 0x%8h = 0x%8h", alu_result_in,
								{{24{1'b0}}, memory[alu_result_in - DATA_MEMORY_ADDR_START]});*/
						end
					LHU:
						if (alu_result_in >= DATA_MEMORY_ADDR_START) begin
							data_load_out <= {{16{1'b0}}, memory[alu_result_in - DATA_MEMORY_ADDR_START+1],
								                      memory[alu_result_in - DATA_MEMORY_ADDR_START+0]};
							/*if (DEBUG) $display("LHU: Reading from address 0x%8h = 0x%8h", alu_result_in,
								{{16{1'b0}}, memory[alu_result_in - DATA_MEMORY_ADDR_START+1],
								memory[alu_result_in - DATA_MEMORY_ADDR_START+0]});*/
						end
					default: begin
						data_load_out <= ZERO_32;
						//if (DEBUG) $display("Unknown LOAD type");
					end
				endcase
			end
		end else begin
			data_load_out <= ZERO_32;
		end

		if (!rst) inst_valid_out <= inst_valid_in;

		// Write to memory
		if (data_store_enable) begin
			// Data access out of bounds.
			if (data_store_addr > DATA_MEMORY_ADDR_START + DATA_MEMORY_BYTES) begin
				$display("Out of bounds data write to 0x%8h. Ending Program.", data_store_addr);
				$finish;			
			end
			case(data_store_type)
				SB: if (data_store_addr >= DATA_MEMORY_ADDR_START) begin
					memory[data_store_addr - DATA_MEMORY_ADDR_START]   <= data_store_in[7 : 0];
					if (DEBUG) $display("SB: Writing 0x%8h into address 0x%8h", data_store_in[7:0], data_store_addr);
				end
				SH: if (data_store_addr >= DATA_MEMORY_ADDR_START) begin
					memory[data_store_addr - DATA_MEMORY_ADDR_START+1] <= data_store_in[15: 8];
					memory[data_store_addr - DATA_MEMORY_ADDR_START+0] <= data_store_in[7 : 0];
					if (DEBUG) $display("SH: Writing 0x%8h into address 0x%8h", data_store_in[15:0], data_store_addr);
				end
				SW: if (data_store_addr >= DATA_MEMORY_ADDR_START) begin
					memory[data_store_addr - DATA_MEMORY_ADDR_START+3] <= data_store_in[31:24];
					memory[data_store_addr - DATA_MEMORY_ADDR_START+2] <= data_store_in[23:16];
					memory[data_store_addr - DATA_MEMORY_ADDR_START+1] <= data_store_in[15: 8];
					memory[data_store_addr - DATA_MEMORY_ADDR_START+0] <= data_store_in[7 : 0];
					if (DEBUG) $display("SW: Writing 0x%8h into address 0x%8h", data_store_in[31:0], data_store_addr);
				end
				default: if (DEBUG) $display("Unknown STORE type");
			endcase
		end

		// Check for putc()/halt() activity.
		if (data_store_addr == {{17{1'b0}}, PUTC_ADDR} && data_store_enable) begin
			if (data_store_in == ZERO_32) begin // Set to ZERO_32 by halt().
				$display("halt(): Null character written to 0x4E20. Ending program.\n");
				$finish;
			end else begin // Set to anything else by putc().
				$display("putc(): New character written to 0x4E20 is %s", data_store_in);
			end
		end
	end
endmodule
