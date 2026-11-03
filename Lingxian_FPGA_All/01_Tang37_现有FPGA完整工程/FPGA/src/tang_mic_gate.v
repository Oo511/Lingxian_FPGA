`timescale 1ns/1ps
// Comparator DO only: microphone power, ground and signal are all on Tang.
// Learn quiet polarity at boot, synchronize the asynchronous input, and retain
// short sound pulses for HOLD_MS. No pitch detection or audio sampling.
module tang_mic_gate #(
 parameter integer TICK_CYCLES=50000,
 parameter integer CAL_MS=1000,
 parameter integer HOLD_MS=45
)(input wire clk,rst_n,mic_do,output reg ready,output wire sound);
 localparam integer TW=TICK_CYCLES>1?$clog2(TICK_CYCLES):1;
 localparam integer CW=CAL_MS>1?$clog2(CAL_MS+1):1;
 localparam integer HW=HOLD_MS>1?$clog2(HOLD_MS+1):1;
 (* syn_keep=1 *) reg [2:0] sync_do;
 reg previous_do,idle_level;
 reg [TW-1:0] timer;
 reg [CW-1:0] calibration,high_count;
 reg [HW-1:0] remaining;
 wire ms_tick=timer==TICK_CYCLES-1;
 assign sound=ready && remaining!=0;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  sync_do<=3'b111;previous_do<=1;idle_level<=1;
  timer<=0;calibration<=0;high_count<=0;remaining<=0;ready<=0;
 end else begin
  sync_do<={sync_do[1:0],mic_do};previous_do<=sync_do[2];
  if(ms_tick)timer<=0;else timer<=timer+1'b1;
  if(!ready)begin
   remaining<=0;
   if(ms_tick)begin
    if(calibration==CAL_MS-1)begin
     idle_level<=high_count+(sync_do[2]?1:0)>CAL_MS/2;
     ready<=1;
    end else begin
     calibration<=calibration+1'b1;
     if(sync_do[2])high_count<=high_count+1'b1;
    end
   end
  end else begin
   if(sync_do[2]!=previous_do || sync_do[2]!=idle_level)remaining<=HOLD_MS;
   else if(ms_tick && remaining!=0)remaining<=remaining-1'b1;
  end
 end
endmodule
