`timescale 1ns/1ps
module tb_tang_mic;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,host=1,mic=1;
 tri scl,sda;pullup(scl);pullup(sda);
 touch_piano_top #(.MIC_TICK_CYCLES(500),.MIC_CAL_MS(5),.MIC_HOLD_MS(4)) dut(
  .sys_clk(clk),.rst_button_n(rst),.MIC_DO(mic),.HOST_RX(host),
  .play_button_n(1'b1),.mode_button_n(1'b1),.CTP_SCL(scl),.CTP_SDA(sda));
 defparam dut.receiver.LEASE_CYCLES=300000;
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task byte_send;input [7:0] b;integer i;begin
  @(negedge clk);host=0;cycles(434);
  for(i=0;i<8;i=i+1)begin host=b[i];cycles(434);end
  host=1;cycles(434);
 end endtask
 task frame_send;input [23:0] k;begin
  byte_send(8'ha5);byte_send(8'h5a);byte_send(2);byte_send(k[7:0]);byte_send(k[15:8]);byte_send(k[23:16]);byte_send(180);
  byte_send(8'ha5^8'h5a^8'd2^k[7:0]^k[15:8]^k[23:16]^8'd180);cycles(1000);
 end endtask
 initial begin
  cycles(5);rst=1;force dut.instrument=2;force dut.chord_down=1;
  cycles(100);if(dut.all_keys!==0)$fatal(1,"boot or KEY1 bypassed microphone");
  cycles(3000);if(!dut.mic_ready||dut.mic_permission)$fatal(1,"quiet boot calibration");
  frame_send(1);if(dut.remote_keys!==1||dut.all_keys!==0)$fatal(1,"quiet held key was not gated on Tang");
  mic=0;cycles(20);if(dut.all_keys!==24'h1091)$fatal(1,"DO plus held C4/chord failed");
  frame_send(0);if(dut.all_keys!==0)$fatal(1,"sound without a held key played");
  frame_send(128);if(dut.all_keys!==(24'h1091|24'd128))$fatal(1,"selected G4 was lost");
  mic=1;cycles(3000);if(dut.all_keys!==0)$fatal(1,"quiet did not gate continuously held key/KEY1");
  cycles(200000);if(dut.active32!==0||dut.fx_left!==0||dut.fx_right!==0)$fatal(1,"dry DAC failed to release");
  mic=0;cycles(10);mic=1;cycles(10);if(!dut.mic_permission||dut.all_keys==0)$fatal(1,"short DO pulse lost");
  cycles(3000);if(dut.all_keys!==0)$fatal(1,"short pulse release stuck");
  mic=0;frame_send(1);cycles(550000);
  if(dut.remote_online!==0||dut.all_keys!==0||dut.active32!==0)$fatal(1,"sound bypassed UART disconnect");
  mic=1;cycles(3000);force dut.instrument=0;cycles(3);if(dut.all_keys!==24'h1091)$fatal(1,"piano chord changed");
  force dut.instrument=1;cycles(3);if(dut.all_keys!==24'h1091)$fatal(1,"guitar chord changed");
  $display("PASS real Tang DO + real UART held keys: boot/quiet gating, C4/G4, key release, silence release, pulse capture, KEY1, disconnect and original instruments");$finish;
 end
 initial begin #50000000;$fatal(1,"Tang microphone integration timeout");end
endmodule
