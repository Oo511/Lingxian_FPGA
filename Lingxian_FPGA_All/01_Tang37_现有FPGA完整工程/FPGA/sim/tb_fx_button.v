`timescale 1ns/1ps
module tb_fx_button;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,button_n=1;
 tri scl,sda;pullup(scl);pullup(sda);
 touch_piano_top dut(.MIC_DO(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),
  .mode_button_n(button_n),.HOST_RX(1'b1),.CTP_SCL(scl),.CTP_SDA(sda));
 defparam dut.tb.STABLE_CYCLES=4;
 task clocks;input integer n;begin repeat(n)@(negedge clk);end endtask
 task displayed;begin
  // Snapshot the feature state using the renderer's real frame-entry state.
  force dut.display.state=5;clocks(2);release dut.display.state;clocks(1);
  if(dut.display.shown_features[2]!==dut.effect_on)$fatal(1,"display state not following KEY0");
  if(dut.display.word_char(7,0)!==8'd70 || dut.display.word_char(7,1)!==8'd88 ||
     dut.display.word_char(7,3)!==8'd79)$fatal(1,"missing FX O label");
  if(dut.effect_on)begin
   if(dut.display.word_char(7,4)!==8'd78 || dut.display.word_char(7,5)!==8'd32)$fatal(1,"FX ON text");
  end else if(dut.display.word_char(7,4)!==8'd70 || dut.display.word_char(7,5)!==8'd70)$fatal(1,"FX OFF text");
 end endtask
 initial begin
  #100;rst=1;clocks(20);
  if(dut.effect_on!==0)$fatal(1,"effects must start disabled");displayed;
  // Bounce shorter than debounce threshold must not toggle.
  button_n=0;clocks(1);button_n=1;clocks(1);button_n=0;clocks(1);button_n=1;clocks(12);
  if(dut.effect_on!==0)$fatal(1,"bounce toggled effect");
  button_n=0;clocks(20);
  if(dut.effect_on!==1)$fatal(1,"KEY0 failed to enable");displayed;
  clocks(40);if(dut.effect_on!==1)$fatal(1,"held KEY0 toggled twice");
  button_n=1;clocks(20);button_n=0;clocks(20);
  if(dut.effect_on!==0)$fatal(1,"second press failed to disable");displayed;
  rst=0;clocks(2);rst=1;button_n=1;clocks(20);
  if(dut.effect_on!==0)$fatal(1,"reset failed to disable");
  $display("PASS KEY0 bounce/hold/two presses/reset, and real renderer FX ON/OFF labels");$finish;
 end
// Legacy regression enables microphone; tb_tang_mic exercises actual DO.
 initial begin force dut.mic_permission=1;end
endmodule
