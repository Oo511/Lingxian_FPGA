`timescale 1ns/1ps
// Two RAM banks: interrupted/bad downloads cannot corrupt the playing score.
// The original fixed guide remains the fallback until a complete commit.
module smart_guide #(parameter BEAT_CYCLES=25000000)(
 input wire clk,rst_n,practice,input wire [23:0] keys,input wire [31:0] active,
 output wire [7:0] leds_n,output wire matched,
 input wire cfg_valid,input wire [7:0] cfg_command,input wire [31:0] cfg_data,
 output reg [7:0] cfg_token,output reg cfg_loaded,
 input wire autoplay,output reg [23:0] playback_keys,
 output wire cfg_committed,output wire score_done);
 reg [2:0] notes[0:127];reg [4:0] lengths[0:127];
 reg bank,staging,valid_stage,have_tempo;
 reg [7:0] pending_token;reg [6:0] wanted,received,score_count;
 reg [31:0] tick_cycles,pending_cycles;
 reg [15:0] crc;
 function [15:0] crc_byte;input [15:0] c;input [7:0] b;integer i;reg [15:0] x;begin
  x=c^{b,8'b0};for(i=0;i<8;i=i+1)x=x[15]?(x<<1)^16'h1021:x<<1;crc_byte=x;
 end endfunction
 wire [6:0] write_address={~bank,cfg_data[5:0]};
 reg [31:0] count;reg [5:0] position;reg [4:0] elapsed;
 wire [6:0] read_address={bank,position};
 wire [2:0] expected=notes[read_address];
 wire [4:0] duration=lengths[read_address];
 function [3:0] key_index;input [2:0] note;begin
  case(note)0:key_index=0;1:key_index=2;2:key_index=4;3:key_index=5;
   4:key_index=7;5:key_index=9;6:key_index=11;default:key_index=15;endcase
 end endfunction
 wire [7:0] legacy_leds;wire legacy_matched;
 performance_led #(.BEAT_CYCLES(BEAT_CYCLES)) fallback(clk,rst_n,practice,keys,active,legacy_leds,legacy_matched);
 wire target_hit=expected<7 && keys[key_index(expected)];
 wire [7:0] targets=expected<7?((8'b1<<expected)|(target_hit?8'h80:8'h00)):8'h00;
 assign matched=cfg_loaded?target_hit:legacy_matched;
 assign leds_n=(cfg_loaded&&practice)?~targets:legacy_leds;
 wire commit=cfg_valid && cfg_command==8'h43 && staging && valid_stage && have_tempo &&
  received==wanted && cfg_data[7:0]==pending_token && cfg_data[15:8]==wanted && cfg_data[31:16]==crc;
 assign cfg_committed=commit;
 assign score_done=practice && cfg_loaded && !commit && count==tick_cycles-1 && elapsed+1>=duration && position+1>=score_count;
 wire [31:0] release_gap=(tick_cycles>>3)!=0?(tick_cycles>>3):32'd1;
 wire note_gate=expected<7 && (elapsed+1<duration || count<tick_cycles-release_gap);
 // A release gap separates identical consecutive notes; no extra DSP voices.
 always @(posedge clk or negedge rst_n)
 if(!rst_n)playback_keys<=0;
 else if(!autoplay || !practice || !cfg_loaded || commit)playback_keys<=0;
 else playback_keys<=note_gate?(24'b1<<key_index(expected)):24'b0;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  bank<=0;staging<=0;valid_stage<=0;have_tempo<=0;wanted<=0;received<=0;score_count<=0;
  cfg_token<=0;cfg_loaded<=0;pending_token<=0;tick_cycles<=12500000;pending_cycles<=0;crc<=16'hffff;
 end else if(cfg_valid)begin
  case(cfg_command)
   8'h40:begin
    staging<=1;valid_stage<=cfg_data[7:0]!=0 && cfg_data[15:8]>=1 && cfg_data[15:8]<=64 && cfg_data[31:16]==0;
    pending_token<=cfg_data[7:0];wanted<=cfg_data[14:8];received<=0;have_tempo<=0;
    crc<=crc_byte(16'hffff,cfg_data[15:8]);
   end
   8'h41:if(staging)begin
    if(have_tempo || received!=0 || cfg_data<6250000 || cfg_data>37500000)valid_stage<=0;
    have_tempo<=1;pending_cycles<=cfg_data;
    crc<=crc_byte(crc_byte(crc_byte(crc_byte(crc,cfg_data[7:0]),cfg_data[15:8]),cfg_data[23:16]),cfg_data[31:24]);
   end
   8'h42:if(staging)begin
    if(!have_tempo || received>=wanted || cfg_data[7:0]!=received || cfg_data[31:24]!=0 ||
      (cfg_data[15:8]>6 && cfg_data[15:8]!=255) || cfg_data[23:16]<1 || cfg_data[23:16]>16)valid_stage<=0;
    else begin
     notes[write_address]<=cfg_data[15:8]==255?3'd7:cfg_data[10:8];lengths[write_address]<=cfg_data[20:16];
     received<=received+1'b1;crc<=crc_byte(crc_byte(crc,cfg_data[15:8]),cfg_data[23:16]);
    end
   end
   8'h43:begin
    staging<=0;
    if(commit)begin bank<=~bank;score_count<=wanted;tick_cycles<=pending_cycles;cfg_token<=pending_token;cfg_loaded<=1;end
   end
   default:begin end
  endcase
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin count<=0;position<=0;elapsed<=0;end
 else if(!practice || !cfg_loaded || commit)begin count<=0;position<=0;elapsed<=0;end
 else if(count==tick_cycles-1)begin
  count<=0;
  if(elapsed+1>=duration)begin elapsed<=0;position<=position+1>=score_count?0:position+1'b1;end
  else elapsed<=elapsed+1'b1;
 end else count<=count+1'b1;
endmodule
