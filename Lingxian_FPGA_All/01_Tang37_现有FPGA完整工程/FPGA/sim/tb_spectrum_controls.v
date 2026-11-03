`timescale 1ns/1ps
module tb_spectrum_controls;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0;
 reg [1:0] timbre=1,preset=0;reg glide=1;reg [7:0] vibrato=255;
 wire signed [15:0] sample;wire [31:0] active;
 integer samples=0;
 always @(posedge clk)if(rst&&tick)samples<=samples+1;
 poly32_engine #(.TEST_MODE(1)) dut(clk,rst,tick,24'hffffff,timbre,preset,glide,vibrato,7'd0,sample,active);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(40)@(negedge clk);end endtask
 genvar v;generate for(v=0;v<32;v=v+1)begin:CHECK
  always @(negedge clk)if(rst && samples>8 && active[v])begin
   if(dut.VOICE[v].unit.shape!==0 || dut.VOICE[v].unit.adsr.profile!==3)
    $fatal(1,"spectrum mode inherited live timbre/envelope, voice=%d",v);
   if(dut.VOICE[v].unit.increment!==dut.pitch_steps[v])
    $fatal(1,"spectrum mode inherited live glide/vibrato, voice=%d",v);
   if(dut.VOICE[v].unit.wave!==$signed(dut.VOICE[v].unit.fundamental))
    $fatal(1,"spectrum tone contains instrument harmonics, voice=%d",v);
  end
 end endgenerate
 initial begin
  #100;rst=1;repeat(40)step;
  timbre=3;preset=1;vibrato=128;repeat(40)step;
  timbre=2;preset=2;glide=0;repeat(40)step;
  if(active!==32'hffffffff)$fatal(1,"32 independent test voices");
  $display("PASS 32 fundamental test tones ignore live timbre/envelope/glide/vibrato controls");$finish;
 end
endmodule
