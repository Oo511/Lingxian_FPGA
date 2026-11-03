`timescale 1ns/1ps
module tb_link;
 reg clk=0;always #10 clk=~clk;reg rst=0,rx=1;
 wire [23:0] keys;wire [7:0] gain;wire [1:0] inst;wire online,valid;wire [15:0] errors;
 link_uart_rx #(.DIV(10),.LEASE_CYCLES(20000)) dut(clk,rst,rx,keys,gain,inst,online,valid,errors);
 task byte_send;input [7:0] b;integer i;begin
  @(negedge clk);rx=0;repeat(10) @(negedge clk);
  for(i=0;i<8;i=i+1)begin rx=b[i];repeat(10) @(negedge clk);end
  rx=1;repeat(10) @(negedge clk);
 end endtask
 task frame_send;input [23:0] k;input [7:0] ins,vol,bad;reg [7:0] c;begin
  c=8'ha5^8'h5a^ins^k[7:0]^k[15:8]^k[23:16]^vol^bad;
  byte_send(8'ha5);byte_send(8'h5a);byte_send(ins);byte_send(k[7:0]);byte_send(k[15:8]);byte_send(k[23:16]);byte_send(vol);byte_send(c);
  repeat(5)@(negedge clk);
 end endtask
 initial begin
  #100;rst=1;byte_send(8'h33);frame_send(24'h1091,0,180,0);
  if(keys!==24'h1091 || gain!=180 || inst || !online)$fatal(1,"snapshot");
  frame_send(24'h100000,1,100,0);if(keys!==24'h100000 || !inst)$fatal(1,"instrument/high note");
  frame_send(0,0,0,1);if(keys!==24'h100000 || errors==0)$fatal(1,"checksum rejects corruption");
  repeat(20010)@(negedge clk);if(keys!==0 || online)$fatal(1,"lost link release");
  byte_send(8'ha5);byte_send(8'h5a);repeat(405)@(negedge clk);
  frame_send(1,0,255,0);if(keys!==1 || !online)$fatal(1,"partial frame recovery");
  frame_send(24'h000200,2,190,0);if(keys!==24'h000200 || inst!==2)$fatal(1,"organ snapshot");
  frame_send(1,3,190,0);if(keys!==24'h000200 || inst!==2)$fatal(1,"invalid instrument changed state");
  $display("PASS UART snapshot, bad CRC, high note, partial recovery, lost-link release");$finish;
 end
endmodule
