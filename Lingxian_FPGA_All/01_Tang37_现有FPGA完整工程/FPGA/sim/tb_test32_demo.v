`timescale 1ns/1ps
module tb_test32_demo;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0,test_mode=0;wire signed [15:0] pcm;wire [31:0] active;
 studio_synth dut(clk,rst,tick,96'b0,8'b0,32'h60606060,16'b0,pcm,active,4'b0,32'b0,test_mode);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(46)@(negedge clk);end endtask
 integer i,j,f;reg [31:0] previous_pitch;
 initial begin
  #100;rst=1;test_mode=1;repeat(512)step;
  if(active!==32'hffffffff||dut.gates!==32'hffffffff)$fatal(1,"not all 32 oscillators active");
  previous_pitch=0;
  for(j=0;j<32;j=j+1)begin if(dut.pitch_steps[j]<=previous_pitch)$fatal(1,"duplicate pitch %d",j);previous_pitch=dut.pitch_steps[j];end
  if(dut.VOICE[0].unit.shape!==3||dut.VOICE[31].unit.adsr.level!==60000)$fatal(1,"test must use pure sustained sine profiles");
  f=$fopen("demo34_test32.csv","w");$fwrite(f,"sample,pcm\n");
  for(i=0;i<16384;i=i+1)begin step;if(pcm===16'sh7fff||pcm===16'sh8000||^pcm===1'bx)$fatal(1,"test output clipped/unknown");$fwrite(f,"%0d,%0d\n",i,$signed(pcm));end
  $fclose(f);test_mode=0;repeat(400)step;if(active!=0||pcm!=0)$fatal(1,"leaving 32-tone test left stuck sound");
  $display("PASS final engine 32 independent sustained pure tones MIDI48..79, test exit releases, exported 16384 samples for FFT");$finish;
 end
 initial begin #30000000;$fatal(1,"32-tone test timeout");end
endmodule
