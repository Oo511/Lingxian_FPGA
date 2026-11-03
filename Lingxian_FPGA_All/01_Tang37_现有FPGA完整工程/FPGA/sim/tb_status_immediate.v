`timescale 1ns/1ps
module tb_status_immediate;
 reg clk=0;always #10 clk=~clk;reg rst=0;reg [1:0] instrument=0;wire tx;
 link_uart_tx #(.DIV(10),.PERIOD(10000)) dut(clk,rst,instrument,tx);
 integer latency;
 task byte_read(input [7:0] expected);reg [7:0] value;integer i;begin
  @(negedge tx);repeat(15)@(posedge clk);#1;
  for(i=0;i<8;i=i+1)begin value[i]=tx;repeat(10)@(posedge clk);#1;end
  if(!tx || value!==expected)$fatal(1,"status word expected %h got %h",expected,value);
 end endtask
 initial begin
  #100;rst=1;
  byte_read(8'ha5);byte_read(8'h5a);byte_read(8'h53);byte_read(0);byte_read(8'hac);
  repeat(30)@(negedge clk);instrument=1;
  latency=0;
  while(tx && latency<1000)begin @(negedge clk);latency=latency+1;end
  if(latency>=1000)$fatal(1,"instrument change waited for heartbeat instead of immediate status");
  // Start bit already observed; finish this byte then decode the remainder.
  repeat(100)@(posedge clk);
  byte_read(8'h5a);byte_read(8'h53);byte_read(1);byte_read(8'had);
  repeat(30)@(negedge clk);instrument=0;
  byte_read(8'ha5);instrument=1; /* new request while an old frame is in flight */
  byte_read(8'h5a);byte_read(8'h53);byte_read(0);byte_read(8'hac);
  byte_read(8'ha5);byte_read(8'h5a);byte_read(8'h53);byte_read(1);byte_read(8'had);
  repeat(30)@(negedge clk);instrument=2;
  byte_read(8'ha5);instrument=0;
  byte_read(8'h5a);byte_read(8'h53);byte_read(2);byte_read(8'hae);
  byte_read(8'ha5);byte_read(8'h5a);byte_read(8'h53);byte_read(0);byte_read(8'hac);
  $display("PASS instrument change triggers immediate atomic UART status, latency=%d cycles",latency);$finish;
 end
 initial begin #5000000;$fatal(1,"status test timeout");end
endmodule
