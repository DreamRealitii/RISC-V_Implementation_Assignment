// Helper file that defines parameters, enums, and helper functions for building a RISC-V CPU.
// Execution stages are instruction read, register read, calculate, memory read, write-prep, and write, labeled as clk1-6.
// This CPU apparently has to be little-endian.

// Possible pipeline conflicts and how I solve them:
// Unconditional jumps = Squash next 5 instructions.
// Conditional jumps = Squash next 5 instructions if jumping, do nothing if not jumping.
// Store to address followed by load from same address = Stall for up to 2 cycles.
// Load from address to register followed by read from same register = Stall for up to 4 cycles.
// Write to register followed by read from same register = Remember previous 4 rd/calculation values in ALU and check if this rs1/rs2 matchs a previous rd.
// Squash means turning off the write-enable signals at the writer so the effects of the instructions next to the jump are never written to the CPU state.
// Stall means telling PC to stop advancing and marking the duplicate instruction as invalid.

// I want to finish in time so I'm just going to stall 4 cycles for all loads.
// Because of how I implemented squash/stall, I also have end an active stall if a squash begins.

`ifndef RISC
`define RISC

// Print debug information if set = 1.
localparam DEBUG = 0;

// Run multiple instructions at once if set = 1.
localparam PIPELINED = 1;

// Main bit size of cpu.
localparam BITS = 32;

// Number of bits in a byte.
localparam BYTE_SIZE = 8;

// Bit length of various instruction components.
//localparam OPCODE_SIZE = 7;
//localparam REG_SIZE =    5;
//localparam FUNCT3_SIZE = 3;
//localparam FUNCT7_SIZE = 7;

// Size of memory in bytes.
localparam INSTRUCTION_MEMORY_BYTES = 4096; // 4kB
localparam DATA_MEMORY_BYTES = 32768; // 32kB.

// Addresses 0-4095 refer to instruction memory, while addresses >4096 refer to data memory.
localparam DATA_MEMORY_ADDR_START = 4096; // 0x1000

// Operation that should do nothing.
localparam NOP = 32'b00000000000000000000000000010011; // addi x0, x0, 0

// Zero/one 32-bit value.
localparam ZERO_32 = 32'b00000000000000000000000000000000;
localparam ONE_32  = 32'b00000000000000000000000000000001;

// Zero/one 1-bit value.
localparam ZERO_1 = 1'b0;
localparam ONE_1  = 1'b1;

// Starting point of a program.
localparam RESET_PC = 32'h00000100;

// Where putc() is set to write value.
localparam PUTC_ADDR = 15'b100111000100000;

// Opcode and operation types.
// Operation type.
typedef enum bit[6:0] {
	LUI    = 7'b0110111, // rd = big immediate
	AUIPC  = 7'b0010111, // rd = big immediate + pc
	JAL    = 7'b1101111, // pc = old pc + immediate | rd = old pc + 4
	JALR   = 7'b1100111, // pc = immediate + rs1    | rd = old pc + 4
	BRANCH = 7'b1100011, // See branch_type
	LOAD   = 7'b0000011, // See load_type
	STORE  = 7'b0100011, // See store_type
	OP_IMM = 7'b0010011, // See op_imm_type
	OP_REG = 7'b0110011  // See op_reg_type
} opcode;

// Instruction format.
typedef enum bit[2:0] {
	r_type, // Reg-Reg
	i_type, // Reg-Imm and also Load and also JALR (weird)
	s_type, // Store
	b_type, // Branch
	u_type, // Big immediate
	j_type, // JAL
	unknown_type
} inst_type;

// Branch type by funct3.
typedef enum bit[2:0] {
	BEQ  = 3'b000, // pc = old pc + immediade if rs1 == rs2
	BNE  = 3'b001, // pc = old pc + immediade if rs1 != rs2
	BLT  = 3'b100, // pc = old pc + immediade if rs1 <  rs2
	BGE  = 3'b101, // pc = old pc + immediade if rs1 >= rs2
	BLTU = 3'b110, // pc = old pc + immediade if unsigned rs1 <  unsigned rs2
	BGEU = 3'b111  // pc = old pc + immediade if unsigned rs1 >= unsigned rs2
} branch_type;

// Load type by funct3.
typedef enum bit[2:0] {
	LB  = 3'b000, // rd = sign-extend 8-bit  read from address rs1 + immediate
	LH  = 3'b001, // rd = sign-extend 16-bit read from address rs1 + immediate
	LW  = 3'b010, // rd = sign-extend 32-bit read from address rs1 + immediate
	LBU = 3'b100, // rd = zero-extend 8-bit  read from address rs1 + immediate
	LHU = 3'b101  // rd = zero-extend 16-bit read from address rs1 + immediate
} load_type;

// Store type by funct3.
typedef enum bit[2:0] {
	SB = 3'b000, // address rs1 + immediate = 8-bit  rs2
	SH = 3'b001, // address rs1 + immediate = 16-bit rs2
	SW = 3'b010  // address rs1 + immediate = 32-bit rs2
} store_type;

// Immediate operation type by funct3.
typedef enum bit[2:0] {
	ADDI  = 3'b000, // rd = rs1 + imm
	SLTI  = 3'b010, // rd = 1 if rst < imm, 0 otherwise
	SLTIU = 3'b011, // rd = 1 if unsigned rs1 < unsigned sign-extended imm, 0 otherwise
	XORI  = 3'b100, // rd = rs1 ^ imm
	ORI   = 3'b110, // rd = rs1 | imm
	ANDI  = 3'b111, // rd = rs1 & imm
	SLLI  = 3'b001, // rd = rs1 << shamt
	SR_I  = 3'b101  // rd = rs1 >> shamt
} op_imm_type;

// Immediate shift-right type by funct7.
typedef enum bit[6:0] {
	SRLI = 7'b0000000, // Zero-extend right-shift
	SRAI = 7'b0100000  // Sign-extend right-shift
} sr_i_type;

// Register operation type by funct3.
typedef enum bit[2:0] {
	ADD_ = 3'b000, // rd = rs1 +/- rs2
	SLL  = 3'b001, // rd = rs1 << rs2
	SLT  = 3'b010, // rd = 1 if rs1 < rs2, 0 otherwise
	SLTU = 3'b011, // rd = 1 if unsigned rs1 < unsigned sign-extended rs2, 0 otherwise
	XOR  = 3'b100, // rd = rs1 ^ rs2
	SR_  = 3'b101, // rd = rs1 >> rs2
	OR   = 3'b110, // rd = rs1 | rs2
	AND  = 3'b111  // rd = rs1 & rs2
} op_reg_type;

// Register add type by funct7.
typedef enum bit[6:0] {
	ADD = 7'b0000000, // Add
	SUB = 7'b0100000  // Subtract
} add_type;

// Register shift-right type by funct7
typedef enum bit[6:0] {
	SRL = 7'b0000000, // Zero-extend right-shift
	SRA = 7'b0100000  // Sign-extend right-shift
} sr_type;

// Instruction-reading helper functions.

// opcode and instruction type
function automatic opcode get_opcode (input [31:0] instruction);
	begin
		get_opcode = opcode'(instruction[6:0]);
	end
endfunction

function automatic inst_type get_inst_type (input [31:0] instruction);
	begin
		case(get_opcode(instruction))
			LUI:    get_inst_type = u_type;
			AUIPC:  get_inst_type = u_type;
			JAL:    get_inst_type = j_type;
			JALR:   get_inst_type = i_type;
			BRANCH: get_inst_type = b_type;
			LOAD:   get_inst_type = i_type;
			STORE:  get_inst_type = s_type;
			OP_IMM: get_inst_type = i_type;
			OP_REG: get_inst_type = r_type;
			default: get_inst_type = unknown_type;
		endcase
	end
endfunction

// register family
function automatic [4:0] get_rs1 (input [31:0] instruction);
	begin
		get_rs1 = instruction[19:15];	
	end
endfunction

function automatic [4:0] get_rs2 (input [31:0] instruction);
	begin
		get_rs2 = instruction[24:20];	
	end
endfunction

function automatic [4:0] get_rd (input [31:0] instruction);
	begin
		get_rd = instruction[11:7];	
	end
endfunction

// funct3 family
function automatic [2:0] get_funct3 (input [31:0] instruction);
	begin
		get_funct3 = instruction[14:12];	
	end
endfunction

function automatic branch_type get_branch_type (input [31:0] instruction);
	begin
		get_branch_type = branch_type'(get_funct3(instruction));
	end
endfunction

function automatic load_type get_load_type (input [31:0] instruction);
	begin
		get_load_type = load_type'(get_funct3(instruction));
	end
endfunction

function automatic store_type get_store_type (input [31:0] instruction);
	begin
		get_store_type = store_type'(get_funct3(instruction));
	end
endfunction

function automatic op_imm_type get_op_imm_type (input [31:0] instruction);
	begin
		get_op_imm_type = op_imm_type'(get_funct3(instruction));
	end
endfunction

function automatic op_reg_type get_op_reg_type (input [31:0] instruction);
	begin
		get_op_reg_type = op_reg_type'(get_funct3(instruction));
	end
endfunction

// funct7 family
function automatic [6:0] get_funct7 (input [31:0] instruction);
	begin
		get_funct7 = instruction[31:25];	
	end
endfunction

function automatic sr_i_type get_sr_i_type (input [31:0] instruction);
	begin
		get_sr_i_type = sr_i_type'(get_funct7(instruction));
	end
endfunction

function automatic add_type get_add_type (input [31:0] instruction);
	begin
		get_add_type = add_type'(get_funct7(instruction));
	end
endfunction

function automatic sr_type get_sr_type (input [31:0] instruction);
	begin
		get_sr_type = sr_type'(get_funct7(instruction));
	end
endfunction

// immediate family
function automatic [31:0] get_imm (input [31:0] inst);
	begin
		case (get_inst_type(inst))
			r_type: get_imm = {32{1'b0}};
			i_type: get_imm = get_imm_itype(inst);
			s_type: get_imm = get_imm_stype(inst);
			b_type: get_imm = get_imm_btype(inst);
			u_type: get_imm = get_imm_utype(inst);
			j_type: get_imm = get_imm_jtype(inst);
			default: get_imm = {32{1'b0}};
		endcase
	end
endfunction

function automatic [31:0] get_imm_itype (input [31:0] inst);
	begin
		get_imm_itype = {{21{inst[31]}}, inst[30:20]};
	end
endfunction

function automatic [31:0] get_imm_stype (input [31:0] inst);
	begin
		get_imm_stype = {{21{inst[31]}}, inst[30:25], inst[11:7]};
	end
endfunction

function automatic [31:0] get_imm_btype (input [31:0] inst);
	begin
		get_imm_btype = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], {1{1'b0}}};
	end
endfunction

function automatic [31:0] get_imm_utype (input [31:0] inst);
	begin
		get_imm_utype = {inst[31:12], {12{1'b0}}};
	end
endfunction

function automatic [31:0] get_imm_jtype (input [31:0] inst);
	begin
		get_imm_jtype = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], {1{1'b0}}};
	end
endfunction

// Shift amount for SLLI, SRLI, and SRAI.
function automatic [31:0] get_shamt (input [31:0] inst);
	begin
		get_shamt = {{27{1'b0}}, inst[24:20]};
	end
endfunction

`endif // RISC
