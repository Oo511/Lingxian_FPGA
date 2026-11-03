`timescale 1ns/1ps
module tb_dual_screen_concept40;
 reg clk=0;always #10 clk=~clk;reg rst=0;
 tri scl1,sda1,scl2,sda2;pullup(scl1);pullup(sda1);pullup(scl2);pullup(sda2);
 fpga_dual_screen_concept40 dut(.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
 .ENCODER_CLK(1'b1),.ENCODER_DT(1'b1),.ENCODER_SW_N(1'b1),.MIC_DO(1'b1),.ESP32_RX(1'b1),
 .CTP_SCL(scl1),.CTP_SDA(sda1),.CTP2_SCL(scl2),.CTP2_SDA(sda2));
 defparam dut.TOUCH_BOOT_CYCLES=20;defparam dut.TOUCH_RESET_CYCLES=5;
 integer heard=0;
 always @(posedge clk)if(dut.dry!=0)heard=heard+1;
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 initial begin
  cycles(5);rst=1;cycles(40);
  force dut.frame2=1;force dut.healthy2=1;force dut.count2=1;force dut.x20=89;force dut.y20=20;
  cycles(8);
  if(dut.local_keys!=1||dut.live_keys!=1||dut.live_gain!=183)$fatal(1,"second screen to local performance path");
  if(dut.picker||dut.selected!=0)$fatal(1,"second-screen performance modified workstation selection");
  force dut.frame2=0;cycles(30000);
  if(heard==0)$fatal(1,"local touch did not reach existing synth PCM");
  force dut.now_ms=20;force dut.count2=0;force dut.frame2=1;cycles(5);
  if(dut.local_keys!=0||dut.live_keys!=0)$fatal(1,"local touch release");
  $display("PASS conceptual second FT6x36 screen -> HDL mapping -> existing synth PCM; independent workstation UI and release");$finish;
 end
 initial begin #2000000;$fatal(1,"concept integration timeout");end
endmodule
