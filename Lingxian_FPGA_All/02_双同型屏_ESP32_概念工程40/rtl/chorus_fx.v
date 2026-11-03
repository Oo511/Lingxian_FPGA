`timescale 1ns/1ps
// 10..15ms modulated tap, plus a separate 84ms delay in audio_fx.
module chorus_fx(input wire clk,rst_n,tick,enable,
 input wire signed [15:0] dry,output reg signed [15:0] wet);
 reg signed [15:0] buffer[0:1023];reg [9:0] wr;
 reg [10:0] filled;reg [15:0] phase;
 wire [7:0] triangle=phase[15]?~phase[14:7]:phase[14:7];
 wire [9:0] rd=wr-10'd480-{2'b0,triangle};
 reg signed [15:0] delayed;
 always @(posedge clk)begin
  delayed<=buffer[rd];
  if(rst_n&&tick)buffer[wr]<=dry;
 end
 // Ramp only the effect contribution; the dry sound keeps its sample timing.
 reg [8:0] mix_gain;
 reg signed [25:0] wet_product;
 always @(posedge clk)wet_product<=($signed(delayed)>>>2)*$signed({1'b0,mix_gain});
 wire signed [17:0] contribution=wet_product>>>8;
 wire signed [17:0] sum=$signed(dry)+contribution;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin wr<=0;filled<=0;phase<=0;wet<=0;mix_gain<=0;end
 else if(tick)begin
  wr<=wr+1'b1;phase<=phase+1'b1;if(filled<1024)filled<=filled+1'b1;
  if(enable&&filled>=1024)begin if(mix_gain<256)mix_gain<=mix_gain+1'b1;end
  else if(mix_gain!=0)mix_gain<=mix_gain-1'b1;
  if(mix_gain==0||filled<1024)wet<=dry;
  else if(sum>32767)wet<=32767;else if(sum< -32768)wet<=-32768;else wet<=sum[15:0];
 end
endmodule
