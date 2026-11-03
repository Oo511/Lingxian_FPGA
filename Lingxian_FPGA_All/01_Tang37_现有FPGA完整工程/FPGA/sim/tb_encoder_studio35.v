`timescale 1ns/1ps
module tb_encoder_studio35;
 reg clk=0;always #10 clk=~clk;reg rst=0,a=1,b=1,sw=1,tick=0;
 tri scl,sda;pullup(scl);pullup(sda);
 studio_board_top dut(.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .MIC_DO(1'b1),.HOST_RX(1'b1),.ENCODER_CLK(a),.ENCODER_DT(b),.ENCODER_SW_N(sw),.CTP_SCL(scl),.CTP_SDA(sda));
 defparam dut.volume_control.SAMPLE_CYCLES=8;defparam dut.volume_control.SW_TICKS=3;
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task step;begin tick=1;cycles(1);tick=0;cycles(11);end endtask
 task hold;input [1:0] ab;input button;begin @(negedge clk);a=ab[1];b=ab[0];sw=button;cycles(32);end endtask
 initial begin
  cycles(5);rst=1;cycles(100);
  force dut.sample_tick=tick;
  // Independent nonzero L/R represent existing dry+effect-tail output.
  force dut.left=16'sd16000;force dut.right=-16'sd12000;
  repeat(200)step;
  if(dut.master_percent!=60||dut.master_muted||dut.master_left!==9625||dut.master_right!==-7219)$fatal(1,"boot master scaling or final-stage routing");
  hold(1,1);hold(0,1);hold(2,1);hold(3,1);repeat(20)step;
  if(dut.master_percent!=62||dut.master.smooth_gain!=159)$fatal(1,"quadrature not connected to final master");
  hold(3,0);repeat(200)step;
  if(!dut.master_muted||dut.left!==16000||dut.master_left!==0||dut.master_right!==0)$fatal(1,"mute must suppress even nonzero effect output");
  hold(1,0);hold(0,0);hold(2,0);hold(3,0);repeat(20)step;
  if(dut.master_percent!=64||!dut.master_muted||dut.master_left!=0)$fatal(1,"turn while muted");
  hold(3,1);hold(3,0);repeat(200)step;
  if(dut.master_muted||dut.master_percent!=64||dut.master_left!==10250||dut.master_right!==-7688)$fatal(1,"restore current target");
  if(dut.track_glide!=0||dut.track_vibrato!=0||dut.playing||dut.recording)$fatal(1,"encoder modified workstation controls");
  $display("PASS integrated studio encoder -> post-FX stereo master -> DAC input, 60/62/64 percent, mute over nonzero tails and restore without changing tracks/expression");$finish;
 end
 initial begin #10000000;$fatal(1,"encoder studio timeout");end
endmodule
