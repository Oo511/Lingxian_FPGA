`timescale 1ns/1ps
module tb_master_dac31;
 reg clk=0;always #10 clk=~clk;reg rst=0,mute=0;reg [6:0] percent=100;
 reg signed [15:0] fx_left=16000,fx_right=-12000;
 wire signed [15:0] scaled_left,scaled_right;wire tick,bck,ws,din;
 master_volume #(.RESET_GAIN(256)) master(clk,rst,tick,percent,mute,fx_left,fx_right,scaled_left,scaled_right);
 pt8211_tx dac(clk,rst,scaled_left,scaled_right,tick,bck,ws,din);
 task word;output [15:0] result;integer i;begin
  result=0;
  for(i=0;i<16;i=i+1)begin @(posedge bck);result={result[14:0],din};end
 end endtask
 task check_frame;input signed [15:0] left,right;reg [15:0] got_left,got_right;begin
  @(negedge ws);word(got_right);word(got_left);
  if(got_left!==left||got_right!==right)$fatal(1,"serialized master PCM L/R=%d/%d expected=%d/%d",$signed(got_left),$signed(got_right),left,right);
 end endtask
 initial begin
  #100;rst=1;repeat(4)@(posedge ws);check_frame(16000,-12000);
  percent=60;repeat(110)@(posedge ws);check_frame(9625,-7219);
  mute=1;repeat(170)@(posedge ws);check_frame(0,0);
  fx_left=-32768;fx_right=32767;repeat(3)@(posedge ws);check_frame(0,0);
  percent=100;mute=0;repeat(260)@(posedge ws);check_frame(-32768,32767);
  $display("PASS bit-decoded physical PT8211 stream: 100%% unity, 60%% signed stereo, mute over ongoing FX output, unmute and full-scale endpoints");$finish;
 end
 initial begin #20000000;$fatal(1,"master DAC timeout");end
endmodule
