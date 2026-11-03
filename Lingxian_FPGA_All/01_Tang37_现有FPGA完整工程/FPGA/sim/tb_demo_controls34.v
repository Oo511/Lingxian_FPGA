`timescale 1ns/1ps
module tb_demo_controls34;
 reg clk=0;always #10 clk=~clk;reg rst=0;tri scl,sda;pullup(scl);pullup(sda);
 studio_board_top dut(.ENCODER_CLK(1'b1),.ENCODER_DT(1'b1),.ENCODER_SW_N(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),.MIC_DO(1'b1),.HOST_RX(1'b1),.CTP_SCL(scl),.CTP_SDA(sda));
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task tap;input [11:0] xx,yy;begin
  force dut.healthy=1;force dut.screen_ready=1;force dut.count=1;force dut.x0=239-yy;force dut.y0=xx;force dut.frame=1;cycles(3);
  force dut.count=0;cycles(3);force dut.frame=0;cycles(3);
 end endtask
 integer i;
 initial begin
  cycles(5);rst=1;cycles(10);tap(20,60);if(!dut.picker)$fatal(1,"picker failed");
  tap(40,220);if(!dut.track_glide[0])$fatal(1,"GLI button not routed");
  tap(115,220);if(dut.track_vibrato[7:0]!=32)$fatal(1,"VIB first step");
  tap(115,220);tap(115,220);tap(115,220);if(dut.track_vibrato[7:0]!=255)$fatal(1,"VIB max");
  tap(200,220);if(!dut.guide_live||dut.guide.practice!==1)$fatal(1,"manual LED guide entry lost");
  tap(280,220);if(!dut.test_mode||dut.guide_live)$fatal(1,"test mode start");
  cycles(40000);if(dut.voice_active!==32'hffffffff||dut.engine.test_mode!==1)$fatal(1,"32-tone test not active");
  tap(280,220);if(dut.test_mode)$fatal(1,"test mode exit");
  tap(30,15);tap(20,100);if(dut.selected!=1||dut.track_glide[0]!==1||dut.track_vibrato[7:0]!==255||dut.track_glide[1]!==0)$fatal(1,"expression settings not retained per track");
  tap(30,15);
  for(i=1;i<=4;i=i+1)begin tap(214,15);if(dut.fx_mode!==i)$fatal(1,"FX select %d",i);end
  tap(214,15);if(dut.fx_mode!=0)$fatal(1,"FX off");
  $display("PASS Tang UI glide/depth/LED/test32 controls, per-track preservation and separate delay/reverb/chorus/all/off selection");$finish;
 end
 initial begin #10000000;$fatal(1,"controls timeout");end
endmodule
