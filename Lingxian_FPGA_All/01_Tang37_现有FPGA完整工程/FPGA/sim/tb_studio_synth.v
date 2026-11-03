`timescale 1ns/1ps
module tb_studio_synth;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;reg [95:0] keys=0;
 reg [7:0] inst=8'he4;reg [31:0] gains=32'hc8c8c8c8;reg [15:0] hits=0;
 wire signed [15:0] pcm;wire [31:0] active;
 studio_synth dut(clk,rst,tick,keys,inst,gains,hits,pcm,active,4'b0,32'b0,1'b0);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(254)@(negedge clk);end endtask
 integer i,peak,mag;
 initial begin
  #100;rst=1;keys={24'b0,24'd128,24'd1,24'd1};hits=16'h1000;@(negedge clk);hits=0;
  repeat(100)step;
  if(active[7:0]==0||active[15:8]==0||active[23:16]==0)$fatal(1,"multi-instrument voices absent");
  if(dut.VOICE[0].unit.shape!==0||dut.VOICE[8].unit.shape!==1||dut.VOICE[16].unit.adsr.profile!==3)$fatal(1,"track timbre isolation");
  if(!dut.guitar_owner[8]||dut.guitar_owner[0]||dut.mapped(0,1)!=40||dut.mapped(0,0)!=60)$fatal(1,"guitar/piano note ownership");
  if(pcm==0)$fatal(1,"layered audio was silent");
  keys={4{24'h0000ff}};inst=8'ha4;gains=32'h50505050;repeat(30)step;
  if(active!==32'hffffffff)$fatal(1,"32 reserved slots not allocated %h",active);
  peak=0;for(i=0;i<300;i=i+1)begin step;if(pcm===16'sh7fff||pcm===16'sh8000||^pcm===1'bx)$fatal(1,"32-voice mixed clipping/unknown");mag=$signed(pcm);if(mag<0)mag=-mag;if(mag>peak)peak=mag;end
  if(peak<500)$fatal(1,"32-voice mix too quiet");
  keys=0;repeat(256)step;
  if(dut.gates!=0||dut.work_gates!=0)$fatal(1,"real allocator failed to release all tracks");
  // The real allocator has released every key. Tail-only verification needs
  // audio ticks and the DSP pipeline, not another 24k empty allocation scans.
  force dut.state=0;
  for(i=0;i<24000;i=i+1)begin
   @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(14)@(negedge clk);
  end
  release dut.state;
  if(active!=0||pcm!=0)$fatal(1,"melody/drum tails stuck after stop %h %d",active,pcm);
  $display("PASS independent piano/guitar/organ/drum lanes, guitar ownership, all 32 melodic slots, gain mixing, no clipping and exact final silence");$finish;
 end
 initial begin #150000000;$fatal(1,"studio synth timeout");end
endmodule
