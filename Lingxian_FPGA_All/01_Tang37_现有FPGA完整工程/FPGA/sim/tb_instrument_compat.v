`timescale 1ns/1ps
module tb_instrument_compat;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0,gate=0,glide=0;
 reg [31:0] pitch=23012828;reg signed [8:0] lfo=0;
 wire signed [15:0] old_p,new_p,old_g,new_g;wire a,b,c,d;
 voice_ex_baseline26 p0(clk,rst,tick,gate,1'b0,pitch,2'd0,2'd0,glide,1'b1,lfo,old_p,a);
 voice_ex p1(clk,rst,tick,gate,1'b0,pitch,2'd0,2'd0,glide,1'b1,lfo,new_p,b);
 voice_ex_baseline26 g0(clk,rst,tick,gate,1'b0,pitch,2'd1,2'd1,glide,1'b1,lfo,old_g,c);
 voice_ex g1(clk,rst,tick,gate,1'b0,pitch,2'd1,2'd1,glide,1'b1,lfo,new_g,d);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(18)@(negedge clk);end endtask
 integer i;
 initial begin
  #100;rst=1;gate=1;
  for(i=0;i<6000;i=i+1)begin
   if(i==500)begin glide=1;pitch=34480283;lfo=127;end
   if(i==1500)begin pitch=23012828;lfo=-128;end
   if(i==2500)begin gate=0;end
   if(i==3500)begin gate=1;glide=0;lfo=0;end
   if(i==4500)gate=0;
   step;
   if(old_p!==new_p || old_g!==new_g || a!==b || c!==d)$fatal(1,"old instrument PCM changed at sample %d",i);
  end
  $display("PASS piano/guitar bit-identical to 26 across glide, positive/negative vibrato, release and restrike");$finish;
 end
endmodule
