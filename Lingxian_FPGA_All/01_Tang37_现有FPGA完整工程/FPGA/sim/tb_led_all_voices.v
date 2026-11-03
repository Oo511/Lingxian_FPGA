`timescale 1ns/1ps
module tb_led_all_voices;
 reg clk=0;always #10 clk=~clk;reg rst=0,practice=0;
 reg [31:0] active=0;reg [23:0] keys=0;wire [7:0] leds;wire matched;
 performance_led #(.BEAT_CYCLES(8)) dut(clk,rst,practice,keys,active,leds,matched);
 integer voice;
 initial begin
  #100;rst=1;
  for(voice=0;voice<32;voice=voice+1)begin
   active=32'b1<<voice;#1;
   if(leds!==(~(8'b1<<(voice%8))))$fatal(1,"active voice %d is invisible on performance LEDs: %h",voice,leds);
  end
  active=0;#1;if(leds!==8'hff)$fatal(1,"idle LEDs");
  $display("PASS all 32 independent voices contribute to performance LED activity");$finish;
 end
endmodule
