`timescale 1ns/1ps
module tb_score_auto;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,practice=0,valid=0,autoplay=0;reg [7:0] cmd=0;reg [31:0] data=0;
 wire [7:0] token,leds;wire loaded,matched,committed,done;wire [23:0] played;
 smart_guide dut(clk,rst,practice,24'b0,32'b0,leds,matched,valid,cmd,data,token,loaded,autoplay,played,committed,done);
 reg [15:0] crc;integer counts[0:3];integer c_on,g_on,done_count,i;reg [23:0] previous;
 function [15:0] cb;input [15:0] c;input [7:0] b;integer j;reg [15:0] x;begin
  x=c^{b,8'b0};for(j=0;j<8;j=j+1)x=x[15]?(x<<1)^16'h1021:x<<1;cb=x;
 end endfunction
 task send;input [7:0] c;input [31:0] d;begin @(negedge clk);cmd=c;data=d;valid=1;@(negedge clk);valid=0;end endtask
 task step;input [7:0] index,note,ticks;begin send(8'h42,{8'b0,ticks,note,index});crc=cb(cb(crc,note),ticks);end endtask
 initial begin
  #100;rst=1;
  send(8'h40,32'h00000401);send(8'h41,32'd12500000);
  crc=cb(16'hffff,4);crc=cb(cb(cb(cb(crc,8'h20),8'hbc),8'hbe),0);
  step(0,0,1);step(1,0,2);step(2,255,1);step(3,4,1);send(8'h43,{crc,8'd4,8'd1});
  if(!loaded||token!=1||dut.tick_cycles!=12500000)$fatal(1,"score/tempo commit failed");
  force dut.tick_cycles=80;
  for(i=0;i<4;i=i+1)counts[i]=0;
  c_on=0;g_on=0;done_count=0;previous=0;
  @(negedge clk);practice=1;autoplay=1;
  for(i=0;i<400;i=i+1)begin
   @(negedge clk);counts[dut.position]=counts[dut.position]+1;
   if(played==1&&previous!=1)c_on=c_on+1;
   if(played==128&&previous!=128)g_on=g_on+1;
   if(done)done_count=done_count+1;
   if(dut.position==2&&played!=0)$fatal(1,"rest produced a key");
   if(played!=0&&played!=1&&played!=128)$fatal(1,"wrong score pitch");
   previous=played;
  end
  if(counts[0]!=80||counts[1]!=160||counts[2]!=80||counts[3]!=80)$fatal(1,"note duration/tempo ratios failed %d %d %d %d",counts[0],counts[1],counts[2],counts[3]);
  if(c_on!=2||g_on!=1||done_count!=1)$fatal(1,"repeated-note articulation or completion failed %d %d %d",c_on,g_on,done_count);
  practice=0;autoplay=0;repeat(3)@(negedge clk);if(played!=0)$fatal(1,"stop left a key held");
  $display("PASS score virtual keys C4/repeated C4/rest/G4, exact duration ratios, tempo commit, note-off gap and one completion pulse");$finish;
 end
 initial begin #1000000;$fatal(1,"score autoplay timeout");end
endmodule
