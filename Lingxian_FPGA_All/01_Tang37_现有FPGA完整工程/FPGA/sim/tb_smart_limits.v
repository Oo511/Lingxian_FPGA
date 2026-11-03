`timescale 1ns/1ps
module tb_smart_limits;
 reg clk=0;always #10 clk=~clk;reg rst=0,practice=0,valid=0;
 reg [7:0] cmd=0;reg [31:0] data=0;wire [7:0] token,leds;wire loaded,matched;
 wire [23:0] unused_keys;wire unused_commit,unused_done;
 smart_guide dut(clk,rst,practice,24'b0,32'b0,leds,matched,valid,cmd,data,token,loaded,1'b0,unused_keys,unused_commit,unused_done);
 reg [15:0] crc;integer i;reg bank;
 function [15:0] cb;input [15:0] c;input [7:0] b;integer j;reg [15:0] x;begin
  x=c^{b,8'b0};for(j=0;j<8;j=j+1)x=x[15]?(x<<1)^16'h1021:x<<1;cb=x;
 end endfunction
 task send;input [7:0] c;input [31:0] d;begin
  @(negedge clk);cmd=c;data=d;valid=1;@(negedge clk);valid=0;
 end endtask
 task header;input [7:0] t;input [7:0] n;begin
  send(8'h40,{16'b0,n,t});send(8'h41,32'd6250000);
  crc=cb(16'hffff,n);crc=cb(cb(cb(cb(crc,8'h10),8'h5e),8'h5f),8'h00);
 end endtask
 initial begin
  #100;rst=1;
  header(1,64);
  for(i=0;i<64;i=i+1)begin
   send(8'h42,{8'b0,8'd16,8'd6,i[7:0]});crc=cb(cb(crc,6),16);
  end
  send(8'h43,{crc,8'd64,8'd1});
  if(!loaded || token!==1 || dut.score_count!==64 || dut.lengths[127]!==16 || dut.notes[127]!==6)
   $fatal(1,"maximum 64-step/16-tick score rejected");
  bank=dut.bank;
  header(2,0);send(8'h43,{crc,8'd0,8'd2});if(token!==1 || dut.bank!==bank)$fatal(1,"zero-length accepted");
  header(2,65);send(8'h43,{crc,8'd65,8'd2});if(token!==1)$fatal(1,"oversized accepted");
  header(2,1);send(8'h42,32'h00010000);crc=cb(cb(crc,0),1);
  send(8'h43,{(crc^16'h0001),8'd1,8'd2});if(token!==1)$fatal(1,"bad CRC committed");
  header(2,1);send(8'h42,32'h00010001);send(8'h43,{crc,8'd1,8'd2});if(token!==1)$fatal(1,"wrong index accepted");
  header(2,1);send(8'h42,32'h00010700);send(8'h43,{crc,8'd1,8'd2});if(token!==1)$fatal(1,"invalid note accepted");
  header(2,1);send(8'h42,32'h0000ff00);send(8'h43,{crc,8'd1,8'd2});if(token!==1)$fatal(1,"zero duration accepted");
  header(2,1);send(8'h42,32'h0010ff00);crc=cb(cb(crc,255),16);send(8'h43,{crc,8'd1,8'd2});
  if(token!==2 || dut.bank===bank)$fatal(1,"valid replacement not committed");
  practice=1;#1;if(leds!==8'hff || matched)$fatal(1,"rest hit/LED falsely lit");
  $display("PASS 64-step/16-tick boundary, second-bank replacement, rest, zero/oversize/order/note/duration/CRC rejection");$finish;
 end
 initial begin #1000000;$fatal(1,"score boundary timeout");end
endmodule
