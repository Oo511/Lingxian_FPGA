`timescale 1ns/1ps
module tb_i2s;
 reg clk=0;always #10 clk=~clk;
 reg rst=0;
 reg signed [15:0] left_word=16'ha55a,right_word=16'h3c69;
 wire tick,bck,ws,din;
 i2s_tx #(.HALF_CYCLES(2)) dut(clk,rst,left_word,right_word,tick,bck,ws,din);
 integer slot;
 initial begin
  #100;rst=1;wait(ws===1'b0);
  for(slot=0;slot<64;slot=slot+1)begin
   @(negedge bck);#1;
   if(slot<16 && (ws!==1'b0 || din!==left_word[15-slot]))
    $fatal(1,"I2S left data/WS slot=%0d ws=%b din=%b",slot,ws,din);
   if(slot>=16 && slot<31 && (ws!==1'b0 || din!==1'b0))
    $fatal(1,"I2S left padding slot=%0d",slot);
   if(slot==31 && (ws!==1'b1 || din!==1'b0))
    $fatal(1,"I2S right transition must follow 32-bit left slot");
   if(slot>=32 && slot<48 && (ws!==1'b1 || din!==right_word[47-slot]))
    $fatal(1,"I2S right data/WS slot=%0d ws=%b din=%b",slot,ws,din);
   if(slot>=48 && slot<63 && (ws!==1'b1 || din!==1'b0))
    $fatal(1,"I2S right padding slot=%0d",slot);
   if(slot==63 && (ws!==1'b0 || din!==1'b0))
    $fatal(1,"I2S frame boundary/one-bit delay");
  end
  $display("PASS standard I2S: 16-bit words, 32-bit slots, MSB order and one-bit WS delay");
  $finish;
 end
 initial begin #100000;$fatal(1,"I2S timeout");end
endmodule
