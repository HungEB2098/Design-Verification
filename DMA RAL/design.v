module DMA
  #( parameter ADDR_WIDTH = 32,
     parameter DATA_WIDTH = 32 ) (
    input clk,
    input reset,
    
    input [ADDR_WIDTH-1:0]  addr,
    input                   wr_en,
    input                   valid,
    
    input  [DATA_WIDTH-1:0] wdata,
    output reg [DATA_WIDTH-1:0] rdata
  ); 
   
  reg [DATA_WIDTH-1:0] intr;
  reg [DATA_WIDTH-1:0] ctrl;
  reg [DATA_WIDTH-1:0] io_addr;
  reg [DATA_WIDTH-1:0] mem_addr;
  reg [DATA_WIDTH-1:0] extra_info;

  always @(posedge clk) begin
    if (reset) begin
      intr       <= 0;
      ctrl       <= 0;
      io_addr    <= 0;
      mem_addr   <= 0;
      extra_info <= 0;
      rdata      <= 0;        
    end
    else begin
      if (wr_en & valid) begin
             if (addr == 32'h800) intr       <= wdata;
        else if (addr == 32'h804) ctrl       <= wdata;
        else if (addr == 32'h808) io_addr    <= wdata;
        else if (addr == 32'h80C) mem_addr   <= wdata;
        else if (addr == 32'h810) extra_info <= wdata;
        $display("Design WR addr %0h Data %0h", addr, wdata);
      end 
      else if (!wr_en & valid) begin
             if (addr == 32'h800) rdata <= intr;
        else if (addr == 32'h804) rdata <= ctrl;
        else if (addr == 32'h808) rdata <= io_addr;
        else if (addr == 32'h80C) rdata <= mem_addr;
        else if (addr == 32'h810) rdata <= extra_info;
        else                      rdata <= 32'hDEADBEEF;
        $display("Design RD addr %0h Data %0h", addr, rdata);
      end
    end
  end
endmodule

interface dma_if ();
    logic clk;
    logic reset;
    
  	logic [31:0]  addr;
    logic                   wr_en;
    logic                   valid;
    
  	logic [31:0] wdata;
  	logic [31:0] rdata;

endinterface