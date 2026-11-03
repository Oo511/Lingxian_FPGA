`timescale 1ns/1ps
module tb_modulation;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0;reg signed [8:0] lfo=200;
 wire signed [15:0] pcm,mixed;wire active;wire [31:0] active32;
 reg [23:0] keys=1;reg [7:0] depth=0;
 voice_ex voice(clk,rst,tick,1'b1,1'b0,32'd40000000,2'd0,2'd3,1'b0,1'b1,lfo,pcm,active);
 poly32_engine engine(clk,rst,tick,keys,2'd1,2'd1,1'b1,depth,7'd60,mixed,active32);
 task step;begin
  @(negedge clk);tick=1;@(negedge clk);tick=0;
  repeat(100)@(negedge clk);
 end endtask
 task check_scale(input [7:0] amount,input signed [8:0] expected);begin
  depth=amount;repeat(2)@(negedge clk);#1;
  if($signed(engine.lfo_depth_q)!==expected)
   $fatal(1,"continuous vibrato scale: depth=%0d expected=%0d got=%0d",amount,expected,$signed(engine.lfo_depth_q));
 end endtask
 integer i;reg [31:0] before_phase,movement;reg restarted=0;
 always @(negedge clk)if(tick && engine.triggers!=0)restarted=1;
 task check_pitch;begin
  before_phase=voice.phase;step;movement=voice.phase-before_phase;
  // This direct voice stress input is +/-200, larger than the engine's +/-128.
  if(movement<38000000 || movement>42000000)
   $fatal(1,"vibrato exceeds direct-input +/-5 percent: lfo=%d, phase advance=%d",lfo,movement);
  if((lfo==200 && movement!==32'd41953125) ||
     (lfo==-200 && movement!==32'd38046875) ||
     (lfo==0 && movement!==32'd40000000))
   $fatal(1,"signed modulation golden phase advance mismatch: lfo=%d movement=%d",lfo,movement);
 end endtask
 initial begin
  #100;rst=1;repeat(8)step;
  for(i=0;i<8;i=i+1)check_pitch;
  lfo=-200;repeat(3)step;
  for(i=0;i<8;i=i+1)check_pitch;
  lfo=0;repeat(3)step;check_pitch;
  force engine.lfo_q=9'sd100;
  check_scale(0,9'sd0);check_scale(64,9'sd25);check_scale(128,9'sd50);check_scale(255,9'sd99);
  force engine.lfo_q=-9'sd100;
  check_scale(64,-9'sd25);check_scale(128,-9'sd50);check_scale(255,-9'sd100);
  release engine.lfo_q;
  // Stub voice-completion feedback: a held pluck has finished naturally.
  // A subsequent slide must produce a fresh note instead of reusing silence.
  force engine.active=32'b0;
  restarted=0;keys=2;repeat(6)step;
  if(!restarted)$fatal(1,"glide reused a silent, naturally finished voice");
  release engine.active;
  $display("PASS signed vibrato pitch bounds, continuous depth scale and glide after natural decay");$finish;
 end
endmodule
