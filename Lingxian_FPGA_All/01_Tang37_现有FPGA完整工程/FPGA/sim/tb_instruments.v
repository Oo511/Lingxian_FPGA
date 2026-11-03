`timescale 1ns/1ps
module tb_instruments;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0,gate=0;
 wire signed [15:0] piano,guitar;wire ap,ag;
 instrument_voice p(clk,rst,tick,gate,1'b0,1'b0,32'd23013299,piano,ap);
 instrument_voice g(clk,rst,tick,gate,1'b0,1'b1,32'd23013299,guitar,ag);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(12)@(negedge clk);end endtask
 integer i,fd,different;
 initial begin
  #100;rst=1;gate=1;different=0;fd=$fopen("instruments.txt","w");
  for(i=0;i<24000;i=i+1)begin step;$fdisplay(fd,"%d %d",piano,guitar);if(piano!=guitar)different=different+1;end
  if(different<1000 || ag || !ap)$fatal(1,"distinct pluck and piano decay");
  gate=0;repeat(300)step;if(ap || ag)$fatal(1,"release");
  $fclose(fd);$display("PASS distinct harmonic instruments, autonomous decay, note-off release");$finish;
 end
endmodule
