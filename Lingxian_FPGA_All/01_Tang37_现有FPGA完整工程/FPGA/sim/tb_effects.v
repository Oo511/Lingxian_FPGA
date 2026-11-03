`timescale 1ns/1ps
module tb_effects;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;reg signed [15:0] dry=0;
 wire signed [15:0] left,right,chorus,wet_left,wet_right;
 audio_fx #(.ADDRESS_BITS(4),.REVERB0(7),.REVERB1(11),.REVERB2(13)) delay(
  clk,rst,tick,dry,8'd255,1'b0,1'b0,1'b1,left,right);
 audio_fx #(.ADDRESS_BITS(4),.REVERB0(7),.REVERB1(11),.REVERB2(13)) reverb(
  clk,rst,tick,dry,8'd255,1'b0,1'b1,1'b0,wet_left,wet_right);
 chorus_fx moddelay(clk,rst,tick,1'b1,dry,chorus);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(8)@(negedge clk);end endtask
 integer i;reg echo,reverberated;
 initial begin
 #100;rst=1;
 for(i=0;i<1100;i=i+1)step;
 dry=10000;step;dry=0;
 for(i=0;i<15;i=i+1)begin step;if(left!==0 || right!==0)$fatal(1,"early delay");end
 step;if(left<2400 || right<4900)$fatal(1,"stereo delayed impulse");
 echo=0;reverberated=0;
 for(i=0;i<60;i=i+1)begin step;if(wet_left!=0 && dry==0)reverberated=1;end
 if(!reverberated)$fatal(1,"feedback reverb tail");
 for(i=0;i<800;i=i+1)begin step;if(chorus!=0)echo=1;end
 if(!echo)$fatal(1,"modulated chorus tap");
 $display("PASS dry startup, exact delay impulse, stereo gains and modulated chorus echo");$finish;
 end
endmodule
