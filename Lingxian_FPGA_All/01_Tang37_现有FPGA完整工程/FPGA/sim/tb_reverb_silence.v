`timescale 1ns/1ps
module tb_reverb_silence;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0;reg signed [15:0] dry=0;
 wire signed [15:0] left,right;
 audio_fx #(.ADDRESS_BITS(4),.REVERB0(7),.REVERB1(11),.REVERB2(13)) dut(
  clk,rst,tick,dry,8'd255,1'b0,1'b1,1'b0,left,right);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(8)@(negedge clk);end endtask
 integer i;
 initial begin
  #100;rst=1;repeat(270)step;
  dry=-16000;step;
  if(left>=0)$fatal(1,"negative impulse lost its sign: %d",left);
  dry=0;
  for(i=0;i<400;i=i+1)begin
   step;
   if(left>0)$fatal(1,"negative reverb tail changed sign at %d: left=%d taps=%d,%d,%d",i,left,dut.comb0_read,dut.comb1_read,dut.comb2_read);
  end
  repeat(40)begin
   step;
   if(left!==0 || right!==0)
    $fatal(1,"negative reverb impulse never reaches silence: left=%d taps=%d,%d,%d",left,dut.comb0_read,dut.comb1_read,dut.comb2_read);
  end
  dry=16000;step;dry=0;repeat(400)step;
  if(left!==0 || right!==0)$fatal(1,"positive impulse never reaches silence");
  $display("PASS positive/negative feedback tails decay to exact silence");$finish;
 end
endmodule
