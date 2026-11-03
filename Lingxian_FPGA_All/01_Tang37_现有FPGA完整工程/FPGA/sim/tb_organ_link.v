`timescale 1ns/1ps
module tb_organ_link;
 reg clk=0;always #10 clk=~clk;reg rst=0,host=1;
 tri scl,sda;pullup(scl);pullup(sda);
 touch_piano_top dut(.MIC_DO(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .HOST_RX(host),.CTP_SCL(scl),.CTP_SDA(sda));
 task byte_send;input [7:0] b;integer i;begin
  @(negedge clk);host=0;repeat(434)@(negedge clk);
  for(i=0;i<8;i=i+1)begin host=b[i];repeat(434)@(negedge clk);end
  host=1;repeat(434)@(negedge clk);
 end endtask
 task frame_send;input [23:0] keys;input [7:0] ins;begin
  byte_send(8'ha5);byte_send(8'h5a);byte_send(ins);byte_send(keys[7:0]);byte_send(keys[15:8]);byte_send(keys[23:16]);byte_send(8'd180);
  byte_send(8'ha5^8'h5a^ins^keys[7:0]^keys[15:8]^keys[23:16]^8'd180);repeat(10000)@(negedge clk);
 end endtask
 initial begin
  #100;rst=1;repeat(20)@(negedge clk);
  force dut.touch_healthy=1;force dut.count=1;force dut.x0=139;force dut.y0=265;
  force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  if(dut.instrument!==2 || dut.preset!==3)$fatal(1,"third card did not select organ");
  frame_send(1,2);
  if(dut.remote_inst!==2 || dut.all_keys!==1 || dut.engine.VOICE[0].unit.shape!==2 || dut.engine.VOICE[0].unit.adsr.profile!==3)
   $fatal(1,"organ UART/timbre/envelope integration");
  frame_send(1,1);if(dut.all_keys!==0)$fatal(1,"guitar snapshot played on organ");
  frame_send(1,2);if(dut.all_keys!==1)$fatal(1,"organ snapshot recovery");
  frame_send(0,2);repeat(200000)@(negedge clk);
  if(dut.active32!==0)$fatal(1,"organ host release stuck");
  force dut.count=0;force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  force dut.count=1;force dut.x0=225;force dut.y0=30;force dut.frame=1;
  repeat(3)@(negedge clk);force dut.frame=0;
  if(dut.guide_on)$fatal(1,"organ enabled incompatible piano guide");
  $display("PASS third touch card -> instrument2 UART -> sustained organ, mismatched-frame rejection and note-off");$finish;
 end
 initial begin #50000000;$fatal(1,"organ integration timeout");end
// Legacy regression enables microphone; tb_tang_mic exercises actual DO.
 initial begin force dut.mic_permission=1;end
endmodule
