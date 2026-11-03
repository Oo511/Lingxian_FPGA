`timescale 1ns/1ps
module tb_tang_mic_unit;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,mic=1;wire ready,sound;
 tang_mic_gate #(.TICK_CYCLES(10),.CAL_MS(8),.HOLD_MS(4)) dut(clk,rst,mic,ready,sound);
 reg prod_rst=0;wire prod_ready,prod_sound;
 tang_mic_gate #(.CAL_MS(1)) production_divider(clk,prod_rst,1'b1,prod_ready,prod_sound);
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 initial begin
  cycles(3);rst=1;cycles(75);if(ready||sound)$fatal(1,"calibration ended early");
  cycles(10);if(!ready||sound||dut.idle_level!==1)$fatal(1,"quiet-high calibration");
  mic=0;cycles(8);if(!sound)$fatal(1,"sound-low not detected");
  cycles(120);if(!sound)$fatal(1,"continuous sound did not hold");
  mic=1;cycles(8);if(!sound)$fatal(1,"release hold absent");
  cycles(50);if(sound)$fatal(1,"quiet did not close gate");
  mic=0;cycles(5);mic=1;cycles(5);if(!sound)$fatal(1,"short pulse lost");
  cycles(50);if(sound)$fatal(1,"pulse gate stuck");
  rst=0;mic=0;cycles(4);rst=1;cycles(85);
  if(!ready||sound||dut.idle_level!==0)$fatal(1,"quiet-low calibration");
  mic=1;cycles(8);if(!sound)$fatal(1,"sound-high not detected");
  mic=0;cycles(60);if(sound)$fatal(1,"active-high release");
  // Verify the unmodified production 50MHz -> 1ms divider separately.
  prod_rst=1;cycles(49999);if(prod_ready)$fatal(1,"production divider too fast");
  cycles(2);if(!prod_ready||prod_sound)$fatal(1,"production divider not 50000 clocks");
  $display("PASS Tang microphone synchronizer, both quiet polarities, boot inhibit, sustained sound, short pulses, silence expiry and production 50000-cycle divider");$finish;
 end
 initial begin #5000000;$fatal(1,"microphone unit timeout");end
endmodule
