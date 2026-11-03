`timescale 1ns/1ps
module tb_effect_switch;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,enable=0;reg signed [15:0] dry=8000;
 wire signed [15:0] chorus,left,right;
 chorus_fx c(clk,rst,tick,enable,dry,chorus);
 audio_fx #(.ADDRESS_BITS(4),.REVERB0(7),.REVERB1(11),.REVERB2(13)) fx(
  clk,rst,tick,dry,8'd255,1'b0,enable,enable,left,right);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(12)@(negedge clk);end endtask
 integer i,pc,pl,pr,dc,dl,dr;
 task smooth_step;begin
  pc=chorus;pl=left;pr=right;step;
  dc=$signed(chorus)-pc;dl=$signed(left)-pl;dr=$signed(right)-pr;
  if(dc>300 || dc< -300 || dl>300 || dl< -300 || dr>300 || dr< -300)
   $fatal(1,"effect switch caused abrupt sample jump: chorus=%d left=%d right=%d",dc,dl,dr);
 end endtask
 initial begin
  #100;rst=1;repeat(1200)step;
  enable=1;repeat(600)smooth_step;
  if(chorus<=8000 || left<=8000 || right<=8000)$fatal(1,"effects never enabled");
  enable=0;repeat(600)smooth_step;
  if(chorus!==8000 || left!==7968 || right!==7968)$fatal(1,"dry signal not restored after fade");
  // Repeated rapid toggles must reverse the fade, not jump back to either end.
  for(i=0;i<8;i=i+1)begin enable=~enable;repeat(30)smooth_step;end
  enable=0;repeat(600)smooth_step;
  $display("PASS chorus/reverb/stereo-delay switches fade smoothly and rapid toggles retain dry path");$finish;
 end
endmodule
