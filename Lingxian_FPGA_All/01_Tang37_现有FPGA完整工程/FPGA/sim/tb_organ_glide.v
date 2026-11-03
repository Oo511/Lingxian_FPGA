`timescale 1ns/1ps
module tb_organ_glide;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;
 reg [23:0] keys=1;wire signed [15:0] pcm;wire [31:0] active;
 poly32_engine engine(clk,rst,tick,keys,2'd2,2'd3,1'b1,8'd0,7'd60,pcm,active);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(100)@(negedge clk);end endtask
 integer i,fd;reg [31:0] previous,current;
 initial begin
  #100;rst=1;repeat(20)step;
  if(engine.VOICE[0].unit.shape!==2 || engine.VOICE[0].unit.adsr.level!==60000 || engine.guitar_owner!==0)
   $fatal(1,"organ mapped to guitar or wrong envelope");
  fd=$fopen("organ_glide.csv","w");$fdisplay(fd,"sample,step,pcm");
  keys=24'h000080;repeat(8)step;
  previous=engine.VOICE[0].unit.step;
  if(previous<=23012828 || previous>=34480283)$fatal(1,"organ did not start a smooth C4-G4 transition");
  for(i=0;i<4096;i=i+1)begin
   step;current=engine.VOICE[0].unit.step;
   if(current<previous || current>34480283 || engine.gates!==1 || engine.triggers!==0 || engine.VOICE[0].unit.adsr.level!==60000)
    $fatal(1,"organ legato broke sustain or monotonic glide");
   previous=current;$fdisplay(fd,"%d,%d,%d",i,current,pcm);
  end
  if(current<34200000)$fatal(1,"organ up-glide too slow");
  keys=1;repeat(8)step;previous=engine.VOICE[0].unit.step;
  for(i=0;i<4096;i=i+1)begin
   step;current=engine.VOICE[0].unit.step;
   if(current>previous || current<23012828 || engine.gates!==1 || engine.triggers!==0 || engine.VOICE[0].unit.adsr.level!==60000)
    $fatal(1,"organ return glide restarted or jumped");
   previous=current;$fdisplay(fd,"%d,%d,%d",4096+i,current,pcm);
  end
  $fclose(fd);
  if(current>23250000)$fatal(1,"organ down-glide too slow");
  keys=0;repeat(300)step;if(active!==0 || pcm!==0)$fatal(1,"organ glide stuck after release");
  $display("PASS sustained organ legato C4-G4-C4: monotonic audible glide, no envelope retrigger, correct map and final silence");$finish;
 end
endmodule
