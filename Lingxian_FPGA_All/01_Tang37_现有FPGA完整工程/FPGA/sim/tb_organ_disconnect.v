`timescale 1ns/1ps
module tb_organ_disconnect;
 reg clk=0;always #10 clk=~clk;reg rst=0,host=1;
 tri scl,sda;pullup(scl);pullup(sda);
 touch_piano_top dut(.MIC_DO(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .HOST_RX(host),.CTP_SCL(scl),.CTP_SDA(sda));
 // Shorter lease for simulation only; production remains 200ms.
 defparam dut.receiver.LEASE_CYCLES=100000;
 task byte_send;input [7:0] b;integer i;begin
  @(negedge clk);host=0;repeat(434)@(negedge clk);
  for(i=0;i<8;i=i+1)begin host=b[i];repeat(434)@(negedge clk);end
  host=1;repeat(434)@(negedge clk);
 end endtask
 initial begin
  #100;rst=1;repeat(20)@(negedge clk);
  force dut.instrument=2;
  byte_send(8'ha5);byte_send(8'h5a);byte_send(2);byte_send(1);byte_send(0);byte_send(0);byte_send(180);
  byte_send(8'ha5^8'h5a^8'd2^8'd1^8'd180);repeat(20000)@(negedge clk);
  if(dut.active32==0 || dut.engine.VOICE[0].unit.adsr.level!==60000)$fatal(1,"organ never sustained");
  repeat(300000)@(negedge clk);
  if(dut.remote_online!==0 || dut.all_keys!==0 || dut.active32!==0 || dut.fx_left!==0 || dut.fx_right!==0)
   $fatal(1,"sustained organ stuck after remote lease expired");
  $display("PASS sustained organ remote disconnect expires lease and releases DAC path to exact silence");$finish;
 end
 initial begin #15000000;$fatal(1,"organ disconnect timeout");end
// Legacy regression enables microphone; tb_tang_mic exercises actual DO.
 initial begin force dut.mic_permission=1;end
endmodule
