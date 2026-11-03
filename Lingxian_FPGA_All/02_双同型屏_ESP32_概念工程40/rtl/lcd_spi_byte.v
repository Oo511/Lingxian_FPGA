`timescale 1ns/1ps
module lcd_spi_byte #(parameter HALF_CYCLES=4)(
 input wire clk,rst_n,start,dc_in,input wire [7:0] data,
 output reg busy,done,output reg sck,mosi,dc);
 reg [7:0] shift;reg [2:0] bitno;reg [15:0] divider;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin busy<=0;done<=0;sck<=0;mosi<=0;dc<=0;shift<=0;bitno<=0;divider<=0;end
 else begin
  done<=0;
  if(!busy && start) begin
   busy<=1;shift<=data;bitno<=7;divider<=0;sck<=0;mosi<=data[7];dc<=dc_in;
  end else if(busy) begin
   if(divider==HALF_CYCLES-1) begin
    divider<=0;sck<=!sck;
    if(sck) begin
     if(bitno==0) begin busy<=0;done<=1;end
     else begin bitno<=bitno-1;shift<={shift[6:0],1'b0};mosi<=shift[6];end
    end
   end else divider<=divider+1;
  end
 end
endmodule
