`timescale 1ns/1ps
// A sustained four-note chord can drive effect buffers harder than a pluck.
module tb_organ_chord;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;reg [23:0] keys=0;
 wire signed [15:0] pcm,chorus,left,right;wire [31:0] active;
 poly32_engine engine(clk,rst,tick,keys,2'd2,2'd3,1'b0,8'd0,7'd60,pcm,active);
 chorus_fx c(clk,rst,tick,1'b1,pcm,chorus);
 audio_fx #(.ADDRESS_BITS(14)) effects(clk,rst,tick,chorus,8'd230,1'b0,1'b1,1'b1,left,right);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(100)@(negedge clk);end endtask
 integer i,peak,magnitude;
 initial begin
  #100;rst=1;peak=0;repeat(18000)step;keys=24'h001091;
  for(i=0;i<22000;i=i+1)begin
   step;
   if(i>30 && (engine.gates!==15 || active!==15))$fatal(1,"organ four-voice chord allocation");
   if(left===16'sh7fff || left===16'sh8000 || right===16'sh7fff || right===16'sh8000)$fatal(1,"organ four-note full-effect chord clipped");
   magnitude=$signed(right);if(magnitude<0)magnitude=-magnitude;if(magnitude>peak)peak=magnitude;
  end
  if(peak<1000)$fatal(1,"organ chord was silent");
  keys=0;repeat(60000)step;
  if(active!==0 || left!==0 || right!==0)$fatal(1,"organ full-effect chord tail failed to reach exact silence");
  $display("PASS organ four-note sustained chord at gain230 with chorus/reverb/delay: no digital clipping, exact tail silence, peak=%d",peak);$finish;
 end
endmodule
