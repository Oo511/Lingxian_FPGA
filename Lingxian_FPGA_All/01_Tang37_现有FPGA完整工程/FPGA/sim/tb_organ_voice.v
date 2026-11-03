`timescale 1ns/1ps
module tb_organ_voice;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0,gate=0;
 wire signed [15:0] piano,guitar,organ;wire ap,ag,ao;
 voice_ex p(clk,rst,tick,gate,1'b0,32'd23012828,2'd0,2'd0,1'b0,1'b0,9'sd0,piano,ap);
 voice_ex g(clk,rst,tick,gate,1'b0,32'd7248587,2'd1,2'd1,1'b0,1'b0,9'sd0,guitar,ag);
 voice_ex o(clk,rst,tick,gate,1'b0,32'd23012828,2'd2,2'd3,1'b0,1'b0,9'sd0,organ,ao);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(18)@(negedge clk);end endtask
 integer i,fd,late_nonzero;
 initial begin
  #100;rst=1;gate=1;late_nonzero=0;
  fd=$fopen("three_instruments.csv","w");$fdisplay(fd,"sample,piano_C4,guitar_E2,organ_C4");
  for(i=0;i<65536;i=i+1)begin
   step;$fdisplay(fd,"%d,%d,%d,%d",i,piano,guitar,organ);
   if(i>50000 && organ!=0)late_nonzero=late_nonzero+1;
   if(i>50000 && (o.adsr.level!==60000 || !ao))$fatal(1,"organ did not sustain");
   if(organ===16'sh7fff || organ===16'sh8000)$fatal(1,"organ voice clipped");
  end
  $fclose(fd);
  if(late_nonzero<14000 || ap || ag)$fatal(1,"three instruments are not distinguishable by sustain");
  gate=0;repeat(300)step;
  if(ao || organ!==0)$fatal(1,"organ release did not reach exact silence");
  gate=1;repeat(20)step;if(!ao || o.adsr.level!==60000)$fatal(1,"organ restrike failed");
  $display("PASS organ sustains beyond piano/guitar decay, no single-voice clipping, note-off silence and restrike");$finish;
 end
endmodule
