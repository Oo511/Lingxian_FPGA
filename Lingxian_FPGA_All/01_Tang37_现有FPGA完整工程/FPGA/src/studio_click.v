`timescale 1ns/1ps
module studio_click(input wire clk,rst_n,tick,fire,output reg signed [15:0] sample);
 reg pending;reg [9:0] left;reg [31:0] phase;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin pending<=0;left<=0;phase<=0;sample<=0;end
 else begin
  pending<=pending|fire;
  if(tick)begin
   pending<=0;phase<=phase+32'd87960930;
   if(pending||fire)begin left<=960;phase<=0;end else if(left!=0)left<=left-1'b1;
   sample<=left!=0?(phase[31]?-$signed({6'b0,left}):$signed({6'b0,left})):16'sd0;
  end
 end
endmodule
