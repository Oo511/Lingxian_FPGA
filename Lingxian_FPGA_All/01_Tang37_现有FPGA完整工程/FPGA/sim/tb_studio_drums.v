`timescale 1ns/1ps
module tb_studio_drums;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;reg [3:0] fire=0;wire signed [15:0] pcm;
 studio_drums dut(clk,rst,tick,fire,pcm);
 integer f,pad,n,peak,magnitude,nonzero,crossings,last_sign;
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(14)@(negedge clk);end endtask
 initial begin
  f=$fopen("studio_drums.csv","w");$fwrite(f,"pad,sample,pcm\n");
  for(pad=0;pad<4;pad=pad+1)begin
   rst=0;repeat(4)@(negedge clk);rst=1;repeat(5)step;fire=1<<pad;@(negedge clk);fire=0;
   peak=0;nonzero=0;crossings=0;last_sign=0;
   for(n=0;n<24000;n=n+1)begin
    step;$fwrite(f,"%0d,%0d,%0d\n",pad,n,$signed(pcm));
    if(pcm===16'sh7fff||pcm===16'sh8000||^pcm===1'bx)$fatal(1,"drum clipped or unknown");
    magnitude=$signed(pcm);if(magnitude<0)magnitude=-magnitude;if(magnitude>peak)peak=magnitude;
    if(magnitude>0)begin nonzero=nonzero+1;if(last_sign!=pcm[15])crossings=crossings+1;last_sign=pcm[15];end
   end
   if(peak<250||nonzero<100||pcm!==0)$fatal(1,"drum pad %d absent or stuck, peak=%d count=%d",pad,peak,nonzero);
   if(pad==0&&crossings>100)$fatal(1,"kick not low pitched");
   if(pad==1&&crossings<200)$fatal(1,"snare not noise percussion");
  end
  $fclose(f);$display("PASS kick/snare/closed-hat/clap: latched short triggers, distinct low/noise character, audible level, no clipping and exact tail silence");$finish;
 end
 initial begin #60000000;$fatal(1,"drum test timeout");end
endmodule
