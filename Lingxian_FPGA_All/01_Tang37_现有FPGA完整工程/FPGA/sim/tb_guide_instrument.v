`timescale 1ns/1ps
module tb_guide_instrument;
 reg clk=0;always #10 clk=~clk;reg rst=0;
 tri scl,sda;pullup(scl);pullup(sda);
 touch_piano_top dut(.MIC_DO(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .HOST_RX(1'b1),.CTP_SCL(scl),.CTP_SDA(sda));
 task frame;begin force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;end endtask
 task release_touch;begin force dut.count=0;frame;end endtask
 initial begin
  #100;rst=1;repeat(10)@(negedge clk);
  force dut.touch_healthy=1;force dut.count=1;force dut.x0=225;force dut.y0=30;frame;
  if(!dut.guide_on)$fatal(1,"piano guide unavailable");
  release_touch;
  force dut.count=1;force dut.x0=139;force dut.y0=200;frame;
  if(dut.instrument!==1 || dut.guide_on)$fatal(1,"piano guide remained active on guitar mapping");
  release_touch;
  force dut.count=1;force dut.x0=225;force dut.y0=30;frame;
  if(dut.guide_on)$fatal(1,"guitar enabled incompatible piano guide");
  $display("PASS piano practice exits on guitar selection and cannot misgrade guitar key bitmap");$finish;
 end
// Legacy regression enables microphone; tb_tang_mic exercises actual DO.
 initial begin force dut.mic_permission=1;end
endmodule
