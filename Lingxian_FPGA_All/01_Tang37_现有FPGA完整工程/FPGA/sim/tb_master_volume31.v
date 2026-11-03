`timescale 1ns/1ps
module tb_master_volume31;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0,mute=0;reg [6:0] pct=100;
 reg signed [15:0] left=0,right=0;wire signed [15:0] outl,outr;
 master_volume #(.RESET_GAIN(256)) dut(clk,rst,tick,pct,mute,left,right,outl,outr);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(4)@(negedge clk);end endtask
 integer p,v,k,expected,previous;reg [8:0] before_gain;
 initial begin
  #100;rst=1;
  for(v=-32768;v<=32767;v=v+257)begin
   left=v;right=-v-1;repeat(3)@(negedge clk);
   if(outl!==left||outr!==right)$fatal(1,"100%% must be bit-exact, including negatives");
  end
  for(p=100;p>=0;p=p-1)begin
   pct=p;
   for(k=0;k<4;k=k+1)step;
   expected=(p*256+50)/100;if(dut.smooth_gain!==expected)$fatal(1,"percent coefficient");
   for(v=-32768;v<=32767;v=v+4095)begin
    left=v;right=-v-1;repeat(3)@(negedge clk);
    if(outl!==((v*expected)>>>8) || outr!==(((-v-1)*expected)>>>8))$fatal(1,"signed gain mismatch p=%d v=%d",p,v);
   end
  end
  if(outl!==0||outr!==0)$fatal(1,"zero gain not exact silence");
  pct=100;for(k=0;k<256;k=k+1)begin before_gain=dut.smooth_gain;step;if(dut.smooth_gain!==before_gain+1)$fatal(1,"up ramp jump");end
  mute=1;left=20000;right=-12000;
  for(k=0;k<256;k=k+1)begin before_gain=dut.smooth_gain;step;if(dut.smooth_gain!==before_gain-1)$fatal(1,"mute ramp jump");end
  if(outl!==0||outr!==0)$fatal(1,"mute must silence nonzero post-effect tails");
  pct=60;repeat(10)step;if(outl!==0)$fatal(1,"turning while muted unmuted");
  mute=0;repeat(154)step;if(dut.smooth_gain!==154||outl!==12031||outr!==-7219)$fatal(1,"restore target or stereo sign");
  $display("PASS output-stage stereo signed multiply, exact 0/100, 101 levels and signed sample cases, monotonic 256-sample ramps, mute over nonzero FX tails and restore");$finish;
 end
 initial begin #10000000;$fatal(1,"master timeout");end
endmodule
