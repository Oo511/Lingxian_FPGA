`timescale 1ns/1ps
module tb_performance_pixels40;
 reg clk=0;always #10 clk=~clk;reg [8:0] x=20,y=180;reg [1:0] inst=0;reg [23:0] keys=0;wire [15:0] rgb;
 performance_pixels40 dut(clk,x,y,inst,keys,8'd180,rgb);
 initial begin
  #20;if(rgb!==16'hefff)$fatal(1,"white key");keys=1;
  #20;if(rgb!==16'h2e5b)$fatal(1,"white key active");
  inst=1;x=65;y=65;#20;if(rgb!==16'h2e5b)$fatal(1,"guitar active");
  inst=3;x=70;y=90;#20;if(rgb!==16'hfd66)$fatal(1,"drum active");
  $display("PASS concept performance-screen piano, guitar and drum active pixels");$finish;
 end
endmodule
