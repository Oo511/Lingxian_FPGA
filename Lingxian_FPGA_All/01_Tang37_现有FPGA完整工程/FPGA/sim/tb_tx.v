`timescale 1ns/1ps
module tb_tx;
 reg clk=0;always #10 clk=~clk;reg rst=0;reg [1:0] inst=0;wire tx;
 link_uart_tx #(.DIV(10),.PERIOD(30)) dut(clk,rst,inst,tx);
 task read_byte;input [7:0] expected;reg [7:0] b;integer i;begin
  @(negedge tx);repeat(15)@(posedge clk);#1;
  for(i=0;i<8;i=i+1)begin b[i]=tx;repeat(10)@(posedge clk);#1;end
  if(!tx || b!==expected)$fatal(1,"state UART expected %h got %h",expected,b);
 end endtask
 initial begin
  #100;rst=1;
  read_byte(8'ha5);read_byte(8'h5a);read_byte(8'h53);read_byte(0);read_byte(8'hac);
  inst=1;
  read_byte(8'ha5);read_byte(8'h5a);read_byte(8'h53);read_byte(1);read_byte(8'had);
  inst=2;
  read_byte(8'ha5);read_byte(8'h5a);read_byte(8'h53);read_byte(2);read_byte(8'hae);
  $display("PASS instrument status TX UART words and checksum");$finish;
 end
 initial begin #200000;$fatal(1,"TX timeout");end
endmodule
