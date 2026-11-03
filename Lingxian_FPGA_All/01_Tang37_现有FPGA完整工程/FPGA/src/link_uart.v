`timescale 1ns/1ps
// 3.3V UART 115200 8N1. Control state is sent as a complete snapshot:
// A5 5A instrument keys[7:0] keys[15:8] keys[23:16] gain xor(bytes0..6).
// A valid snapshot renews a 200ms lease. Host must send at least every 20ms.
module link_uart_rx #(parameter DIV=434,LEASE_CYCLES=10000000)(
 input wire clk,rst_n,rx,output reg [23:0] keys,output reg [7:0] gain,
 output reg [1:0] instrument,output reg online,valid,output reg [15:0] errors);
 reg [1:0] sync;reg [2:0] state;reg [15:0] timer;
 reg [2:0] bitno,index;reg [7:0] shift,checksum,inst,k0,k1,k2,vol;
 reg [31:0] lease,gap;
 task consume;input [7:0] b;begin
  case(index)
   0:if(b==8'ha5) begin index<=1;checksum<=b;end
   1:if(b==8'h5a) begin index<=2;checksum<=checksum^b;end
     else if(b==8'ha5) begin index<=1;checksum<=b;end else index<=0;
   2:begin inst<=b;checksum<=checksum^b;index<=3;end
   3:begin k0<=b;checksum<=checksum^b;index<=4;end
   4:begin k1<=b;checksum<=checksum^b;index<=5;end
   5:begin k2<=b;checksum<=checksum^b;index<=6;end
   6:begin vol<=b;checksum<=checksum^b;index<=7;end
   7:begin
    index<=0;
    if(b==checksum && inst<=2) begin
     keys<={k2,k1,k0};gain<=vol;instrument<=inst[1:0];online<=1;valid<=1;lease<=0;
    end else errors<=errors+1'b1;
   end
  endcase
 end endtask
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin
  sync<=3;state<=0;timer<=0;bitno<=0;index<=0;shift<=0;checksum<=0;
  keys<=0;gain<=0;instrument<=0;online<=0;valid<=0;errors<=0;lease<=0;gap<=0;
  inst<=0;k0<=0;k1<=0;k2<=0;vol<=0;
 end else begin
  sync<={sync[0],rx};valid<=0;
  if(lease<LEASE_CYCLES) lease<=lease+1'b1;
  else begin keys<=0;online<=0;end
  // A 4-character gap discards an incomplete frame, without clearing notes.
  if(index!=0) begin
   if(gap>=DIV*40) begin index<=0;gap<=0;end else gap<=gap+1'b1;
  end else gap<=0;
  case(state)
   0:if(!sync[1]) begin timer<=DIV/2;state<=1;end
   1:if(timer==0) begin
    if(!sync[1]) begin timer<=DIV-1;bitno<=0;state<=2;end else state<=0;
   end else timer<=timer-1'b1;
   2:if(timer==0) begin
    shift[bitno]<=sync[1];timer<=DIV-1;
    if(bitno==7) state<=3;else bitno<=bitno+1'b1;
   end else timer<=timer-1'b1;
   3:if(timer==0) begin
    state<=0;gap<=0;
    if(sync[1]) consume(shift);
    else begin index<=0;errors<=errors+1'b1;end
   end else timer<=timer-1'b1;
   default:state<=0;
  endcase
 end
endmodule

// Instrument state: send changes immediately, plus a periodic heartbeat.
// The instrument is latched per complete frame, even if it changes mid-frame.
module link_uart_tx #(parameter DIV=434,PERIOD=1000000)(
 input wire clk,rst_n,input wire [1:0] instrument,output reg tx);
 reg [31:0] period_count;reg [15:0] timer;reg [3:0] bitno;
 reg [2:0] index;reg busy;reg [1:0] latched;reg [9:0] bits;reg [7:0] b;
 always @* case(index)
  0:b=8'ha5;1:b=8'h5a;2:b=8'h53;3:b={6'b0,latched};
  default:b=8'ha5^8'h5a^8'h53^{6'b0,latched};
 endcase
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin tx<=1;period_count<=PERIOD-1;timer<=0;bitno<=0;index<=0;busy<=0;bits<=10'h3ff;latched<=0;end
 else if(!busy) begin
  tx<=1;
  if(instrument!=latched || period_count>=PERIOD-1) begin
   period_count<=0;latched<=instrument;index<=0;busy<=1;bitno<=0;timer<=0;
  end else period_count<=period_count+1'b1;
 end else if(timer==0) begin
  timer<=DIV-1;
  if(bitno==0) begin bits<={1'b1,b,1'b0};tx<=0;bitno<=1;end
  else if(bitno<10) begin tx<=bits[bitno];bitno<=bitno+1'b1;end
  else begin
   tx<=1;bitno<=0;
   if(index==4) busy<=0;else index<=index+1'b1;
  end
 end else timer<=timer-1'b1;
endmodule
