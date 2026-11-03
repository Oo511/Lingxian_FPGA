`timescale 1ns/1ps
module tb_vibrato_range;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0;reg [7:0] depth=0;
 wire signed [15:0] pcm;wire [31:0] active;
 poly32_engine engine(clk,rst,tick,24'd1,2'd0,2'd3,1'b0,depth,7'd60,pcm,active);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(100)@(negedge clk);end endtask
 real frequency,base_frequency;reg [31:0] base;
 task check_change;input real low_hz,high_hz;begin
  repeat(3)step;
  frequency=$itor(engine.VOICE[0].unit.increment)*48828.125/4294967296.0-base_frequency;
  if(frequency<low_hz || frequency>high_hz)$fatal(1,"actual engine vibrato depth out of bounds: depth=%d change=%f",depth,frequency);
  if(engine.triggers!==0)$fatal(1,"depth change retriggered a voice");
 end endtask
 initial begin
  #100;rst=1;repeat(12)step;
  base=engine.VOICE[0].unit.increment;base_frequency=$itor(base)*48828.125/4294967296.0;
  if(base_frequency<261.62 || base_frequency>261.64)$fatal(1,"C4 baseline");
  force engine.lfo_phase=32'h40000000;
  depth=32;check_change(0.90,1.05);
  depth=64;check_change(1.90,2.05);
  depth=128;check_change(3.95,4.15);
  depth=255;check_change(7.95,8.20);
  force engine.lfo_phase=32'hc0000000;
  check_change(-8.30,-8.0);
  depth=128;check_change(-4.20,-4.0);
  depth=64;check_change(-2.10,-1.95);
  depth=32;check_change(-1.10,-0.95);
  depth=0;check_change(-0.0001,0.0001);
  if(engine.VOICE[0].unit.increment!==base)$fatal(1,"zero depth changed pitch");
  release engine.lfo_phase;
  $display("PASS actual engine C4: depth32 about +/-1Hz, depth128 about +/-4Hz, MAX about +/-8Hz, signed symmetry and exact zero-depth pitch");$finish;
 end
endmodule
