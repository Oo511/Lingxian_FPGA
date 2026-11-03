`timescale 1ns/1ps
module tb_organ_keys;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;reg [23:0] keys=0;
 wire signed [15:0] pcm;wire [31:0] active;
 poly32_engine engine(clk,rst,tick,keys,2'd2,2'd3,1'b0,8'd0,7'd60,pcm,active);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(100)@(negedge clk);end endtask
 integer k,i;reg [31:0] expected,phase_before,change;
 initial begin
  #100;
  for(k=0;k<24;k=k+1)begin
   rst=0;keys=0;repeat(4)@(negedge clk);rst=1;keys=24'd1<<k;repeat(20)step;
   expected=$rtoi(440.0*(2.0**((60+k-69)/12.0))*4294967296.0/48828.125+0.5);
   if(engine.gates!==1 || engine.VOICE[0].unit.shape!==2 || engine.VOICE[0].unit.adsr.level!==60000)
    $fatal(1,"organ key allocation or sustain k=%d",k);
   for(i=0;i<16;i=i+1)begin
    phase_before=engine.VOICE[0].unit.phase;step;change=engine.VOICE[0].unit.phase-phase_before;
    if(change!==expected)$fatal(1,"organ pitch mapping k=%d expected=%d got=%d",k,expected,change);
   end
  end
  $display("PASS all 24 organ keys C4-B5 independently calculated phase advances and sustained envelope");$finish;
 end
endmodule
