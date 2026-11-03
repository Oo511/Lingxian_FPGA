`timescale 1ns/1ps
module tb_guide;
 reg clk=0;always #10 clk=~clk;reg rst=0,practice=0;reg [23:0] keys=24'b1;
 wire [7:0] leds;wire matched;
 performance_led #(.BEAT_CYCLES(4)) dut(clk,rst,practice,keys,32'h5,leds,matched);
 initial begin
 #100;rst=1;#1;if(leds!==8'hfa)$fatal(1,"active voice indicators");
 @(negedge clk);practice=1;#1;if(leds!==8'h7e || !matched)$fatal(1,"guide target and correct-note LED");
 keys=0;#1;if(leds!==8'hfe || matched)$fatal(1,"correct-note feedback clears on release");
 keys=1;
 repeat(4)@(negedge clk);if(leds!==8'h7e || !matched)$fatal(1,"guide advances independently of audio");
 repeat(4)@(negedge clk);if(leds!==8'hef || matched)$fatal(1,"guide G note");
 $display("PASS voice activity and offline 120bpm step guide");$finish;
 end
endmodule
