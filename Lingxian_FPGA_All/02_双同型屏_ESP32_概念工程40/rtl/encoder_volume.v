`timescale 1ns/1ps
// Incremental EC11/KY-040: all signals enter Tang, never the STM32.
// Sync in the clock domain, then sample at 1ms. A complete legal phase cycle
// changes volume by 2%; bounce reversals cancel, diagonal jumps are discarded.
module encoder_volume #(
 parameter SAMPLE_CYCLES=50000,SW_TICKS=20,EDGES_PER_DETENT=4,REVERSE=0,
 parameter [6:0] RESET_PERCENT=60
)(input wire clk,rst_n,encoder_clk,encoder_dt,encoder_sw_n,
 output reg [6:0] percent,output reg muted,
 output reg [15:0] detents,invalid_edges,output wire [2:0] pins);
 reg [2:0] sync0,sync1;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin sync0<=3'b111;sync1<=3'b111;end
 else begin sync0<={encoder_sw_n,encoder_clk,encoder_dt};sync1<=sync0;end
 assign pins=sync1;
 localparam COUNT_BITS=SAMPLE_CYCLES<=1?1:$clog2(SAMPLE_CYCLES);
 localparam SW_BITS=SW_TICKS<=1?1:$clog2(SW_TICKS+1);
 reg [COUNT_BITS-1:0] counter;
 reg [2:0] startup;reg [1:0] previous;reg signed [3:0] partial;
 reg switch_high;reg [SW_BITS-1:0] switch_count;
 wire sample=counter==SAMPLE_CYCLES-1;
 wire [1:0] changed=previous^sync1[1:0];
 reg signed [3:0] delta;wire signed [4:0] next_partial=$signed(partial)+$signed(delta);
 always @*begin
  case({previous,sync1[1:0]})
   4'b0010,4'b0100,4'b1011,4'b1101:delta=1;
   4'b0001,4'b0111,4'b1000,4'b1110:delta=-1;
   default:delta=0;
  endcase
 end
 wire completed=next_partial>=EDGES_PER_DETENT || next_partial<=-EDGES_PER_DETENT;
 wire positive=(next_partial>0)^REVERSE;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  counter<=0;startup<=0;previous<=3;partial<=0;switch_high<=1;switch_count<=0;
  percent<=RESET_PERCENT;muted<=0;detents<=0;invalid_edges<=0;
 end else begin
  counter<=sample?0:counter+1'b1;
  if(sample)begin
   // Establish the actual resting state; a held boot button is not a press.
   if(startup<4)begin
    startup<=startup+1'b1;previous<=sync1[1:0];switch_high<=sync1[2];partial<=0;switch_count<=0;
   end else begin
    previous<=sync1[1:0];
    if(changed==3)begin partial<=0;invalid_edges<=invalid_edges+1'b1;end
    else if(changed!=0)begin
     if(completed)begin
      partial<=0;detents<=detents+1'b1;
      if(positive)percent<=percent>=98?7'd100:percent+7'd2;
      else percent<=percent<=2?7'd0:percent-7'd2;
     end else partial<=next_partial[3:0];
    end
    if(sync1[2]==switch_high)switch_count<=0;
    else if(switch_count>=SW_TICKS-1)begin
     switch_count<=0;switch_high<=sync1[2];if(!sync1[2])muted<=!muted;
    end else switch_count<=switch_count+1'b1;
   end
  end
 end
endmodule
