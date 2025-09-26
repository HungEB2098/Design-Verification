`timescale 1ps/1ps
module fifo(full,empty,wrclk,rdclk,data_in,data_out,clr,wr,rd);
parameter width=32;
parameter depth=16;
input wrclk,rdclk,clr,wr,rd;
wire [3:0]waddr,raddr;
input [width-1:0]data_in;
output reg[width-1:0]data_out;
output full,empty;
wire [4:0]wptr,rptr,wptr_sync,rptr_sync;
wire wr_en,rd_en;
reg [width-1:0]mem[depth-1:0];
integer i;

assign full=({~wptr[4],wptr[3:0]}==rptr_sync);
assign empty=(rptr==wptr_sync);
assign wr_en=(!full && wr)?1:0;
assign rd_en=(!empty && rd)?1:0;

always @(posedge wrclk)
begin
if(!full && wr && !clr)
mem[waddr]<=data_in;
end

always @(posedge rdclk)
begin
if(!empty && rd && !clr)
data_out<=mem[raddr];
end

always @(clr)
begin
if(clr)
begin
for(i=0; i<depth; i=i+1)
mem[i]=0;
data_out=mem[0];
end
end

counter_1 c1(rptr,clr,rdclk,rd_en);
counter_1 c2(wptr,clr,wrclk,wr_en);
counter_2 c3(waddr,clr,wrclk,wr_en);
counter_2 c4(raddr,clr,rdclk,rd_en);
sync s1(wptr,rdclk,wptr_sync);
sync s2(rptr,wrclk,rptr_sync);

endmodule

module counter_1(out,clr,clk,en);
input clr,clk,en;
output reg[4:0]out;

always @(posedge clk or posedge clr)
if(clr)
out<=0;
else if(en)
out<=out+1;
endmodule

module counter_2(out,clr,clk,en);
input clr,clk,en;
output reg[3:0]out;

always @(posedge clk or posedge clr)
if(clr)
out<=0;
else if(en)
out<=out+1;
endmodule

module sync(in,clk,q2);
input [4:0]in;
input clk;
output reg[4:0]q2;
reg [4:0]q1;

always @(posedge clk)
begin
q1<=in;
q2<=q1;
end
endmodule

module fifo_test;
reg [31:0]data_in;
reg wrclk,rdclk,clr,wr,rd;
wire [31:0]data_out;
wire full,empty;

fifo f1(full,empty,wrclk,rdclk,data_in,data_out,clr,wr,rd); 

initial rdclk=0;
always #1000 rdclk=~rdclk;

initial wrclk=0;
always #625 wrclk=~wrclk;

initial begin
clr=1;
#2000 clr=0;
#65000 $finish;
end

initial begin
data_in=1;
repeat(30)
@(posedge wrclk)
data_in=data_in+1;
#65000 $finish;
end

initial begin
wr=1; 
#30000 wr=0;
#65000 $finish;
end

initial begin
rd=0; 
#30000 rd=1;
#65000 $finish;
end
endmodule  
