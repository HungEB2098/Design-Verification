module DMA (
    input         clk,
    input         rst,
    input [31:0]  addr,
    input [31:0]  wdata,
    input         we, //write enable
    output        re, //read enable
    output        ack
    output [31:0] rdata,
);
    reg [31:0] intr;
    reg [31:0] ctrl;
    reg [31:0] io_addr;
    reg [31:0] mem_addr;

    

    always @(posedge clk) begin

    end



endmodule