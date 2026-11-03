`timescale 1ns/1ps
// FT6x36 raw portrait coordinates are transformed to landscape.
module touch_controls #(parameter SWAP_XY=1,INVERT_X=0,INVERT_Y=1)(
 input wire clk,rst_n,frame_valid,healthy,chord_mode,
 input wire [1:0] count,input wire [11:0] x0,y0,x1,y1,
 output reg [23:0] keys,output reg [7:0] gain);
 wire [11:0] ax0=SWAP_XY?y0:x0, ay0=SWAP_XY?x0:y0;
 wire [11:0] ax1=SWAP_XY?y1:x1, ay1=SWAP_XY?x1:y1;
 wire bounds0=ax0<320 && ay0<240,bounds1=ax1<320 && ay1<240;
 wire [8:0] px0=INVERT_X?319-ax0:ax0,py0=INVERT_Y?239-ay0:ay0;
 wire [8:0] px1=INVERT_X?319-ax1:ax1,py1=INVERT_Y?239-ay1:ay1;
 wire v0,v1,b0,b1;wire [3:0] n0,n1;
 piano_geometry g0(px0,py0,v0,n0,b0),g1(px1,py1,v1,n1,b1);
 reg [23:0] next_keys;reg [7:0] next_gain;
 always @* begin
  next_keys=0;next_gain=gain;
  if(count!=0 && bounds0 && v0) begin
   next_keys[n0]=1;
   // Y is expression, not pressure: move vertically within the same key.
   next_gain=32+py0-32;
   if(chord_mode) begin
    next_keys[n0+4]=1;next_keys[n0+7]=1;next_keys[n0+12]=1;
   end
  end
  if(!chord_mode && count>=2 && bounds1 && v1) next_keys[n1]=1;
 end
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin keys<=0;gain<=128;end
  else if(!healthy) keys<=0;
  else if(frame_valid) begin keys<=next_keys;gain<=next_gain;end
endmodule
