`timescale 1ns/1ps
module tb_touch_recovery36;
 reg clk=0;always #10 clk=~clk;
 reg rst=0;tri scl,sda;pullup(scl);pullup(sda);
 wire ctp_rst;
 studio_board_top dut(.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .ENCODER_CLK(1'b1),.ENCODER_DT(1'b1),.ENCODER_SW_N(1'b1),.MIC_DO(1'b1),.HOST_RX(1'b1),
  .CTP_SCL(scl),.CTP_SDA(sda),.CTP_RST(ctp_rst));
 defparam dut.TOUCH_BOOT_CYCLES=20;
 defparam dut.TOUCH_RESET_CYCLES=5;
 defparam dut.TOUCH_RETRY_CYCLES=40;
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task tap;input [11:0] xx,yy;begin
  force dut.count=1;force dut.x0=239-yy;force dut.y0=xx;force dut.frame=1;cycles(3);
  force dut.count=0;cycles(3);force dut.frame=0;cycles(3);
 end endtask
 integer i;reg [1:0] saved_selected;
 initial begin
  cycles(5);rst=1;cycles(10);
  force dut.healthy=1;force dut.screen_ready=0;
  tap(20,60);if(dut.picker)$fatal(1,"accepted touches before first LCD frame");
  force dut.screen_ready=1;cycles(3);
  force dut.screen_ready=0;
  // A full-frame repaint must not lock track/card/STOP actions after boot.
  for(i=0;i<12;i=i+1)begin
   tap(20,60+(i%4)*40);
   if(!dut.picker||dut.selected!=i%4)$fatal(1,"track lost during redraw iteration %d",i);
   tap(60,80);if(dut.picker)$fatal(1,"card lost during redraw");
   force dut.playing=1;tap(200,220);
   if(dut.ui_command!=0)$fatal(1,"command did not return to idle");
   release dut.playing;
   if(dut.loop.playing)$fatal(1,"STOP lost during redraw");
  end
  // No touch-up frame arrives during the communication outage.
  force dut.count=1;force dut.frame=1;force dut.x0=179;force dut.y0=20;cycles(3);
  if(!dut.picker)$fatal(1,"picker precondition");
  force dut.frame=0;force dut.healthy=0;cycles(3);
  force dut.healthy=1;
  force dut.x0=159;force dut.y0=60;force dut.frame=1;cycles(3);
  if(!dut.picker)$fatal(1,"brief communication failure retriggered a held finger");
  force dut.frame=0;force dut.healthy=0;cycles(41);
  cycles(25);force dut.healthy=1;force dut.frame=1;cycles(3);
  if(dut.picker)$fatal(1,"stale touch-held survived communication outage");
  force dut.frame=0;force dut.healthy=1;cycles(30);saved_selected=dut.selected;
  force dut.healthy=0;cycles(10);
  if(!ctp_rst)$fatal(1,"transient outage reset the controller");
  force dut.healthy=1;cycles(3);
  for(i=0;i<3;i=i+1)begin
   force dut.healthy=0;cycles(41);
   if(ctp_rst)$fatal(1,"sustained failure did not reset touch");
   if(!dut.rst_n||dut.picker||dut.selected!=saved_selected)$fatal(1,"touch retry disturbed workstation");
   if(dut.touch.scl_low||dut.touch.sda_low)$fatal(1,"I2C outputs not released during reset");
   cycles(5);if(!ctp_rst)$fatal(1,"touch reset did not release");
   cycles(20);force dut.healthy=1;cycles(3);
  end
  $display("PASS first-frame guard, 12 track/card/STOP actions during redraw, stale-held release, transient filtering, repeated isolated touch reset and I2C release");$finish;
 end
 initial begin #1000000;$fatal(1,"touch recovery test timeout");end
endmodule
