`timescale 1ns/1ps
module tb_smart_tx;
 reg clk=0;always #10 clk=~clk;reg rst=0;reg [1:0] inst=0;reg [7:0] token=0;reg loaded=0;
 wire tx;smart_uart_tx #(.DIV(8),.PERIOD(30)) dut(clk,rst,inst,tx,token,loaded);
 reg [7:0] b[0:5];integer i,j,frames=0,statuses=0,acks=0;reg [7:0] checksum;
 task byte_read;output [7:0] v;begin
  @(negedge tx);repeat(12)@(posedge clk);
  for(j=0;j<8;j=j+1)begin v[j]=tx;repeat(8)@(posedge clk);end
  if(!tx)$fatal(1,"smart TX stop bit low");
 end endtask
 initial begin #100;rst=1;
  while(frames<8)begin
   checksum=0;
   for(i=0;i<3;i=i+1)begin byte_read(b[i]);checksum=checksum^b[i];end
   if(b[0]!==8'ha5 || b[1]!==8'h5a)$fatal(1,"TX framing");
   if(b[2]==8'h53)begin
    byte_read(b[3]);checksum=checksum^b[3];byte_read(b[4]);if(checksum!==b[4] || b[3]>2)$fatal(1,"legacy status CRC");statuses=statuses+1;
   end else if(b[2]==8'h54)begin
    byte_read(b[3]);byte_read(b[4]);checksum=checksum^b[3]^b[4];byte_read(b[5]);
    if(checksum!==b[5] || b[4]>1)$fatal(1,"commit ACK CRC");acks=acks+1;
   end else $fatal(1,"unexpected status type");
   frames=frames+1;if(frames==3)begin token=7;loaded=1;inst=2;end
  end
  if(statuses==0 || acks==0)$fatal(1,"one status type starved");
  $display("PASS real serial legacy instrument and score-commit ACK frames with checksums and midstream changes");$finish;
 end
 initial begin #5000000;$fatal(1,"smart TX timeout");end
endmodule
