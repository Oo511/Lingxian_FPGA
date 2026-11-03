`timescale 1ns/1ps
// Production 5Hz LFO and depth scaling feed old/new real voice implementations.
module tb_vibrato_audition;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,gate=0,vibrato=0;reg [31:0] phase=0;
 wire signed [12:0] sine;wire signed [8:0] lfo=sine[12:4];
 wire signed [17:0] scaled=$signed(lfo)*9'sd255;
 wire signed [8:0] amount=scaled>>>8;
 sine_lut source(phase[31:24],sine);
 wire signed [15:0] old_pcm,new_pcm;wire old_active,new_active;
 voice_ex_baseline25 old(clk,rst,tick,gate,1'b0,32'd23012828,2'd0,2'd0,1'b0,vibrato,amount,old_pcm,old_active);
 voice_ex candidate(clk,rst,tick,gate,1'b0,32'd23012828,2'd0,2'd0,1'b0,vibrato,amount,new_pcm,new_active);
 always @(posedge clk)if(rst&&tick)phase<=phase+32'd439805;
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(18)@(negedge clk);end endtask
 integer i,fd;
 initial begin
  #100;rst=1;repeat(4)step;
  gate=1;repeat(200)begin step;if(old_pcm!==new_pcm)$fatal(1,"vibrato OFF changed PCM");end
  gate=0;repeat(600)step;gate=1;vibrato=1;
  fd=$fopen("vibrato_audition.csv","w");
  $fdisplay(fd,"sample,baseline25,candidate26");
  for(i=0;i<65536;i=i+1)begin
   step;$fdisplay(fd,"%d,%d,%d",i,old_pcm,new_pcm);
   if(new_pcm===16'sh7fff || new_pcm===16'sh8000)$fatal(1,"candidate single voice clipped");
  end
  $fclose(fd);
  gate=0;repeat(600)step;
  if(old_active || new_active || old_pcm!==0 || new_pcm!==0)$fatal(1,"release did not reach exact silence");
  $display("PASS real 5Hz LFO old/new voice PCM, zero-depth identity, unclipped audition and release silence");$finish;
 end
endmodule
