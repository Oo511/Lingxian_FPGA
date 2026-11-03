`timescale 1ns/1ps
// Sample-domain one-pole lowpass + optional feed-forward stereo delay.
// Uninitialized RAM is masked until a full ring has been written.
module audio_fx #(parameter ADDRESS_BITS=12,REVERB0=1493,REVERB1=1601,REVERB2=1759)(input wire clk,rst_n,tick,
 input wire signed [15:0] dry,input wire [7:0] gain,
 input wire filter_enable,reverb_enable,delay_enable,
 output reg signed [15:0] left,right);
 localparam DEPTH=1<<ADDRESS_BITS;
 localparam REVERB_MAX=REVERB0>REVERB1?(REVERB0>REVERB2?REVERB0:REVERB2):(REVERB1>REVERB2?REVERB1:REVERB2);
 reg signed [15:0] memory[0:DEPTH-1];reg [ADDRESS_BITS-1:0] wr;
 reg [ADDRESS_BITS:0] filled;reg signed [19:0] lowpass;
 reg [7:0] smooth_gain;
 wire signed [19:0] delta={{4{dry[15]}},dry}-lowpass;
 wire signed [15:0] selected=filter_enable?lowpass[15:0]:dry;
 wire signed [24:0] product=selected*$signed({1'b0,smooth_gain});
 wire signed [15:0] scaled=product>>>8;
 // Three incommensurate feedback combs create a dense, decaying reverb tail.
 reg signed [15:0] comb0[0:REVERB0-1],comb1[0:REVERB1-1],comb2[0:REVERB2-1];
 reg [10:0] comb0_wr,comb1_wr,comb2_wr,reverb_filled;
 reg [8:0] reverb_gain,delay_gain;
 wire reverb_running=reverb_enable || reverb_gain!=0;
 reg signed [15:0] comb0_read,comb1_read,comb2_read;
 // Truncate feedback toward zero in both polarities. Arithmetic shift alone
 // leaves -1 circulating forever, producing a periodic low-level DC tail.
 function signed [15:0] half_decay;input signed [15:0] value;begin
  half_decay=(value>>>1)+((value[15]&&value[0])?16'sd1:16'sd0);
 end endfunction
 wire signed [17:0] feedback0=$signed(scaled)+(reverb_filled>=REVERB0?half_decay(comb0_read):16'sd0);
 wire signed [17:0] feedback1=$signed(scaled)+(reverb_filled>=REVERB1?half_decay(comb1_read):16'sd0);
 wire signed [17:0] feedback2=$signed(scaled)+(reverb_filled>=REVERB2?half_decay(comb2_read):16'sd0);
 wire reverb_ready=reverb_filled>=REVERB_MAX;
 wire signed [17:0] reverb_sum=($signed(comb0_read)>>>2)+($signed(comb1_read)>>>2)+($signed(comb2_read)>>>2);
 reg signed [27:0] reverb_product;
 always @(posedge clk)reverb_product<=reverb_sum*$signed({1'b0,reverb_gain});
 wire signed [17:0] reverb_wet=reverb_product>>>8;
 wire signed [17:0] reverb_mix=$signed(scaled)+reverb_wet;
 wire signed [15:0] processed=(reverb_gain!=0&&reverb_ready)?limit(reverb_mix):scaled;
 // Prefetch next read address after each audio tick. Synchronous RAM read
 // enables Gowin BSRAM inference instead of spending LUTs on delay storage.
 reg signed [15:0] ram_read;
 always @(posedge clk)begin
  ram_read<=memory[wr];
  comb0_read<=comb0[comb0_wr];comb1_read<=comb1[comb1_wr];comb2_read<=comb2[comb2_wr];
 end
 wire signed [15:0] delayed=filled==DEPTH?ram_read:16'sd0;
 reg signed [25:0] delay_product;
 always @(posedge clk)delay_product<=$signed(delayed)*$signed({1'b0,delay_gain});
 wire signed [17:0] delay_left=delay_product>>>10,delay_right=delay_product>>>9;
 wire signed [17:0] mixleft=$signed(processed)+delay_left;
 wire signed [17:0] mixright=$signed(processed)+delay_right;
 function [15:0] limit;input signed [17:0] value;begin
  if(value>32767) limit=16'h7fff;else if(value<-32768) limit=16'h8000;else limit=value[15:0];
 end endfunction
 // RAM is not reset: this block can infer distributed/block RAM.
 always @(posedge clk) if(rst_n && tick) begin
  memory[wr]<=processed;
  comb0[comb0_wr]<=reverb_running?limit(feedback0):16'sd0;
  comb1[comb1_wr]<=reverb_running?limit(feedback1):16'sd0;
  comb2[comb2_wr]<=reverb_running?limit(feedback2):16'sd0;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin
  wr<=0;filled<=0;lowpass<=0;smooth_gain<=0;left<=0;right<=0;
  comb0_wr<=0;comb1_wr<=0;comb2_wr<=0;reverb_filled<=0;
  reverb_gain<=0;delay_gain<=0;
 end
 else if(tick) begin
  wr<=wr+1'b1;if(filled<DEPTH) filled<=filled+1'b1;
  comb0_wr<=comb0_wr==REVERB0-1?0:comb0_wr+1'b1;
  comb1_wr<=comb1_wr==REVERB1-1?0:comb1_wr+1'b1;
  comb2_wr<=comb2_wr==REVERB2-1?0:comb2_wr+1'b1;
  if(reverb_running)begin if(reverb_filled<REVERB_MAX)reverb_filled<=reverb_filled+1'b1;end
  else reverb_filled<=0;
  if(reverb_enable&&reverb_ready)begin if(reverb_gain<256)reverb_gain<=reverb_gain+1'b1;end
  else if(reverb_gain!=0)reverb_gain<=reverb_gain-1'b1;
  if(delay_enable&&filled==DEPTH)begin if(delay_gain<256)delay_gain<=delay_gain+1'b1;end
  else if(delay_gain!=0)delay_gain<=delay_gain-1'b1;
  lowpass<=lowpass+(delta>>>3);
  if(smooth_gain<gain) smooth_gain<=smooth_gain+1'b1;
  else if(smooth_gain>gain) smooth_gain<=smooth_gain-1'b1;
  left<=delay_gain!=0?limit(mixleft):processed;
  right<=delay_gain!=0?limit(mixright):processed;
 end
endmodule
