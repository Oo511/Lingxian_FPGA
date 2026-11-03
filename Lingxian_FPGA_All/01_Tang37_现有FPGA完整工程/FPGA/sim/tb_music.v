`timescale 1ns/1ps
// Exercise the voice_ex path actually instantiated by poly32_engine.
module tb_music;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,gate=0;
 wire signed [15:0] piano,guitar;
 wire ap,ag;wire [15:0] ep,eg;
 wire aep,aeg;wire [15:0] sustained;wire sustained_active;
 voice_ex p(clk,rst,tick,gate,1'b0,32'd23012828,2'd0,2'd0,1'b0,1'b0,9'sd0,piano,ap);
 voice_ex g(clk,rst,tick,gate,1'b0,32'd7248587,2'd1,2'd1,1'b0,1'b0,9'sd0,guitar,ag);
 envelope_ex pe(clk,rst,tick,gate,1'b0,2'd0,ep,aep);
 envelope_ex ge(clk,rst,tick,gate,1'b0,2'd1,eg,aeg);
 envelope_ex held(clk,rst,tick,gate,1'b0,2'd3,sustained,sustained_active);
 task step;begin
  @(negedge clk);tick=1;@(negedge clk);tick=0;
  repeat(18)@(negedge clk);
 end endtask
 integer fd,i,early_p,early_g,late_p,late_g;
 initial begin
  #100;rst=1;gate=1;
  fd=$fopen("music_samples.txt","w");
  for(i=0;i<65536;i=i+1)begin
   step;$fdisplay(fd,"%d %d",piano,guitar);
   if(i==4096)begin early_p=ep;early_g=eg;end
   if(i==24000)begin late_p=ep;late_g=eg;end
  end
  $fclose(fd);
  if(late_p>=early_p/2 || late_g>=early_g/4 || ag)
   $fatal(1,"string decay regressed: piano %d -> %d, guitar %d -> %d, guitar active %b",early_p,late_p,early_g,late_g,ag);
  if(!sustained_active || sustained!=60000)$fatal(1,"organ profile must sustain (32-tone test)");
  gate=0;repeat(600)step;
  if(ap || ag || piano!=0 || guitar!=0)$fatal(1,"note-off silence");
  gate=1;repeat(80)step;
  if(!ap || !ag || ep<50000 || eg<50000)$fatal(1,"restrike after natural decay");
  gate=0;repeat(600)step;
  if(ap || ag)$fatal(1,"early release");
  $display("PASS live voice piano/guitar decay, note-off silence and restrike");$finish;
 end
endmodule
