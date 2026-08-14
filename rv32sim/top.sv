// Module that creates CPU cores?
module top(
    input logic       clk,
    input logic      reset

    // For those doing the HW option, you may / will want to expose some I/O here
    // perhaps a serial port?
    );

    /*logic           instruction_valid;
    logic [31:0]    instruction_addr;
    logic [31:0]    instruction_read;
    logic           instruction_ready;
    logic           instruction_ack;

    logic           data_read_valid;
    logic           data_write_valid;
    logic [31:0]    data_addr;
    logic [31:0]    data_read;
    logic [31:0]    data_write;
    logic [3:0]     data_write_byte;
    logic           data_ready;
    logic           data_ack;*/

    // You can adjust these however you like, but here are some suggested pins for your processor
    core riscv32 (
        .clk(clk),
        .rst(reset) /*,
        
        .instruction_valid(instruction_valid),          // instruction fetch?
        .instruction_addr(instruction_addr),            // instruction fetch address?
        .instruction_read(instruction_read),            // data returned from memory
        .instruction_ready(instruction_ready),          // data returned is valid this clock cycle
        .instruction_ack(instruction_ack),              // request for fetch ack'ed

        .data_read_valid(data_read_valid),              // do read?
        .data_write_valid(data_write_valid),            // do write?
        .data_addr(data_addr),                          // address
        .data_read(data_read),                          // data read back from memory
        .data_write(data_write),                        // data to be written to memory
        .data_write_byte(data_write_byte),              // which bytes of the data should be written
        .data_ready(data_ready),                        // data memory has finished R/W this cycle
        .data_ack(data_ack),                            // data memory acks the R/W request*/
        );

endmodule
