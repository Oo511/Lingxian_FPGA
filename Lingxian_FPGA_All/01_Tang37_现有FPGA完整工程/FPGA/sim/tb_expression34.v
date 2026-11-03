`timescale 1ns/1ps
module tb_expression34;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;reg [95:0] keys=0;reg [3:0] glide=0;
 reg [31:0] depth=0;wire signed [15:0] pcm;wire [31:0] active;
 studio_synth dut(clk,rst,tick,keys,8'h02,32'hc8c8c8c8,16'b0,pcm,active,glide,depth,1'b0);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(254)@(negedge clk);end endtask
 reg [31:0] old_step,new_step;integer i;reg [7:0] original_gate;
 initial begin
  #100;rst=1;keys=1;repeat(80)step;
  old_step=dut.VOICE[0].unit.step;original_gate=dut.gates[7:0];if(original_gate!=1||dut.VOICE[0].unit.adsr.level<50000)$fatal(1,"organ setup");
  glide=1;keys=128;repeat(20)step;new_step=dut.VOICE[0].unit.step;
  if(dut.gates[7:0]!=original_gate||dut.owners[4:0]!=7||dut.triggers[7:0]!=0)$fatal(1,"legato changed voice or retriggered envelope");
  if(new_step<=old_step||new_step>=dut.pitch_steps[0])$fatal(1,"glide did not interpolate pitch");
  if(dut.VOICE[0].unit.adsr.level<50000)$fatal(1,"glide restarted envelope");
  keys=1;repeat(10)step;new_step=dut.VOICE[0].unit.step;repeat(20)step;if(dut.VOICE[0].unit.step>=new_step)$fatal(1,"downward glide failed");
  glide=0;keys=128;repeat(20)step;if(dut.VOICE[0].unit.step!=dut.pitch_steps[0])$fatal(1,"glide off failed to settle");
  depth=32'h000000ff;force dut.lfo_wave=13'sd2047;repeat(10)step;
  if(dut.lfo_depth[0]<=0||dut.VOICE[0].unit.increment<=dut.VOICE[0].unit.step)$fatal(1,"positive depth/LFO not routed");
  if(dut.lfo_depth[1]!=0||dut.VOICE[8].unit.increment!=dut.VOICE[8].unit.step)$fatal(1,"vibrato leaked into other track");
  force dut.lfo_wave=-13'sd2048;repeat(10)step;
  if(dut.VOICE[0].unit.increment>=dut.VOICE[0].unit.step||dut.VOICE[0].unit.increment<dut.VOICE[0].unit.step*9/10)$fatal(1,"negative vibrato signed arithmetic");
  release dut.lfo_wave;depth=0;repeat(10)step;
  if(dut.VOICE[0].unit.increment!=dut.VOICE[0].unit.step)$fatal(1,"depth zero not neutral");
  keys=0;repeat(300)step;if(active!=0)$fatal(1,"organ release stuck");
  $display("PASS restored per-track legato voice ownership, up/down glide, envelope continuity, signed vibrato depth, track isolation and note-off");$finish;
 end
 initial begin #10000000;$fatal(1,"expression timeout");end
endmodule
