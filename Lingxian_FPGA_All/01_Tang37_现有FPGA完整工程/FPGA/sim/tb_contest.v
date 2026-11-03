`timescale 1ns/1ps
module tb_contest;
 reg clk=0;always #10 clk=~clk;reg rst=0,live_rst=0,tick=0;
 reg [23:0] keys=0;wire signed [15:0] live,test_pcm;wire [31:0] active,test_active;
 poly32_engine engine(clk,live_rst,tick,keys,2'd0,2'd0,1'b0,8'd0,7'd60,live,active);
 poly32_engine #(.TEST_MODE(1)) test_engine(clk,rst,tick,24'b0,2'd0,2'd3,1'b0,8'd0,7'd60,test_pcm,test_active);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(90)@(negedge clk);end endtask
 task test_step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(8)@(negedge clk);end endtask
 integer i,fd;
 initial begin
  #100;rst=1;live_rst=1;keys=24'h1091;repeat(10)step;
  if(active[3:0]!==4'hf)$fatal(1,"four independent voices");
  keys=0;repeat(3)step;keys=1;repeat(3)step;
  if(!active[4])$fatal(1,"release-tail reservation");
  if(test_active!==32'hffffffff)$fatal(1,"32 oscillator activity");
  live_rst=0;keys=0;repeat(100)test_step;
  fd=$fopen("contest_samples.txt","w");
  for(i=0;i<32768;i=i+1)begin test_step;$fdisplay(fd,"%d",test_pcm);end
  $fclose(fd);$display("PASS four voices, spare release tails, 32 independent oscillators");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
