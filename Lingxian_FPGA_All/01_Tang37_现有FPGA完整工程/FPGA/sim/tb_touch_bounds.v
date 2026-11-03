`timescale 1ns/1ps
module tb_touch_bounds;
 reg clk=0;always #10 clk=~clk;reg rst=0;
 tri scl,sda;pullup(scl);pullup(sda);
 touch_piano_top dut(.MIC_DO(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .HOST_RX(1'b1),.CTP_SCL(scl),.CTP_SDA(sda));
 task touch_frame;begin force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;end endtask
 initial begin
  #100;rst=1;repeat(10)@(negedge clk);
  force dut.touch_healthy=1;force dut.count=1;
  force dut.x0=4095;force dut.y0=4095;touch_frame;
  if(dut.instrument!==0 || dut.guide_on || dut.glide_on || dut.vibrato_depth!=0)
   $fatal(1,"out-of-range I2C coordinates changed controls");
  force dut.x0=19;force dut.y0=319;touch_frame;
  if(dut.vibrato_depth!==255)$fatal(1,"valid slider lost after corrupt coordinates");
  force dut.x0=4095;force dut.y0=160;touch_frame;
  if(dut.vibrato_depth!==255)$fatal(1,"underflowed portrait Y reset vibrato");
  force dut.count=0;touch_frame;
  force dut.count=1;force dut.x0=139;force dut.y0=200;touch_frame;
  if(dut.instrument!==1)$fatal(1,"valid instrument tap rejected");
  $display("PASS out-of-range portrait coordinates cannot change instrument/glide/vibrato/guide; valid input recovers");$finish;
 end
// Legacy regression enables microphone; tb_tang_mic exercises actual DO.
 initial begin force dut.mic_permission=1;end
endmodule
