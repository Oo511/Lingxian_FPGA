`timescale 1ns/1ps
// Standard I2S, 16-bit words in 32-bit slots; one BCLK delay after LRCLK.
// 50MHz/(2*8*64) = 48828.125Hz, same sample rate as the PT8211 path.
module i2s_tx #(parameter HALF_CYCLES=8)(input wire clk,rst_n,
 input wire signed [15:0] sample_left,sample_right,
 output wire sample_tick,output reg bck,ws,output reg din);
 reg [15:0] divider,left_word,right_word;reg [5:0] position;
 assign sample_tick=rst_n && divider==HALF_CYCLES-1 && bck && position==63;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin divider<=0;position<=63;bck<=0;ws<=1;din<=0;left_word<=0;right_word<=0;end
 else if(divider==HALF_CYCLES-1) begin
  divider<=0;bck<=!bck;
  if(bck) begin
   position<=position+1;
   if(position==63) begin ws<=0;din<=0;left_word<=sample_left;right_word<=sample_right;end
   else if(position==31) begin ws<=1;din<=0;end
   else if(position<16) din<=left_word[15-position];
   else if(position>=32 && position<48) din<=right_word[47-position];
   else din<=0;
  end
 end else divider<=divider+1;
endmodule
