`timescale 1ns/1ps
module tb_smart29;
 reg clk=0;always #10 clk=~clk;reg rst=0,host=1;
 tri scl,sda;pullup(scl);pullup(sda);
 wire [7:0] leds;
 touch_piano_top #(.AUTO_GAP_CYCLES(32),.MIC_TICK_CYCLES(8),.MIC_CAL_MS(1)) dut(.MIC_DO(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .HOST_RX(host),.CTP_SCL(scl),.CTP_SDA(sda),.LED_N(leds));
 defparam dut.receiver.DIV=8;
 reg [7:0] packets[0:63];integer i;reg bank;
 task byte_send;input [7:0] b;integer j;begin
  @(negedge clk);host=0;repeat(8)@(negedge clk);
  for(j=0;j<8;j=j+1)begin host=b[j];repeat(8)@(negedge clk);end
  host=1;repeat(8)@(negedge clk);
 end endtask
 task packet;input [7:0] cmd;input [31:0] data;begin
  byte_send(8'ha5);byte_send(8'h5a);byte_send(cmd);
  byte_send(data[7:0]);byte_send(data[15:8]);byte_send(data[23:16]);byte_send(data[31:24]);
  byte_send(8'ha5^8'h5a^cmd^data[7:0]^data[15:8]^data[23:16]^data[31:24]);
  repeat(10)@(negedge clk);
 end endtask
 initial begin
  $readmemh("smart_packets.hex",packets);
  #100;rst=1;repeat(20)@(negedge clk);
  for(i=0;i<64;i=i+1)byte_send(packets[i]);
  repeat(4000)@(negedge clk);
  if(!dut.cfg_loaded || dut.cfg_token!==1 || !dut.auto_run || dut.guide.score_count!==3 || dut.guide.tick_cycles!==12500000)
   $fatal(1,"actual C-generated UART config/commit/control integration failed");
  if(dut.remote_play!==128 || leds!==8'h6f || !dut.matched)$fatal(1,"mapped G4 key should match downloaded first G target");
  bank=dut.guide.bank;
  // Bad/incomplete replacement may not touch the committed score or bank.
  packet(8'h40,32'h00000202);packet(8'h41,12500000);packet(8'h42,32'h00010000);packet(8'h43,32'hffff0202);
  if(dut.guide.bank!==bank || dut.cfg_token!==1)$fatal(1,"incomplete score replaced playing bank");
  force dut.guide.tick_cycles=4;
  force dut.guide.count=0;@(negedge clk);release dut.guide.count;
  repeat(8)@(negedge clk);
  if(dut.guide.position!==1 || leds!==8'hff)$fatal(1,"downloaded rest duration failed");
  repeat(4)@(negedge clk);
  if(dut.guide.position!==2 || leds!==8'hfe)$fatal(1,"downloaded C target missing");
  repeat(12)@(negedge clk);
  if(dut.guide.position!==0 || dut.auto_run)$fatal(1,"custom score one-pass completion failed");
  release dut.guide.tick_cycles;
  packet(8'h44,0);if(dut.guide_on || dut.auto_run || dut.auto_delay!=0)$fatal(1,"remote playback stop failed");
  packet(8'h44,1);force dut.instrument=2;repeat(3)@(negedge clk);
  if(dut.guide_on)$fatal(1,"organ must exit piano guide");
  $display("PASS C-produced score UART -> atomic FPGA bank commit -> mapped-key hit/rest/durations/offline auto-once/start-stop/instrument exit; interrupted update retained old score");$finish;
 end
 initial begin #10000000;$fatal(1,"smart29 integration timeout");end
// Legacy regression enables microphone; tb_tang_mic exercises actual DO.
 initial begin force dut.mic_permission=1;end
endmodule
