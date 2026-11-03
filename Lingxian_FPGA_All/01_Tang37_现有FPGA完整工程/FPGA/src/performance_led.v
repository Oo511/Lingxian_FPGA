`timescale 1ns/1ps
// Pure HDL guide: 32 quarter-note slots: Twinkle practice excerpt at 120bpm. LEDs are active low.
// Practice mode only displays expected key; it never plays a prerecorded tune.
module performance_led #(parameter BEAT_CYCLES=25000000)(
 input wire clk,rst_n,practice,input wire [23:0] keys,input wire [31:0] active,
 output wire [7:0] leds_n,output wire matched);
 reg [24:0] count;reg [4:0] position;reg [3:0] expected;
 always @*case(position)
  0:expected=0;
  1:expected=0;
  2:expected=7;
  3:expected=7;
  4:expected=9;
  5:expected=9;
  6:expected=7;
  7:expected=7;
  8:expected=5;
  9:expected=5;
  10:expected=4;
  11:expected=4;
  12:expected=2;
  13:expected=2;
  14:expected=0;
  15:expected=0;
  16:expected=7;
  17:expected=7;
  18:expected=5;
  19:expected=5;
  20:expected=4;
  21:expected=4;
  22:expected=2;
  23:expected=2;
  24:expected=7;
  25:expected=7;
  26:expected=5;
  27:expected=5;
  28:expected=4;
  29:expected=4;
  30:expected=2;
  31:expected=2;
  default:expected=0;
 endcase
 assign matched=keys[expected];
 reg [2:0] white_key;
 always @*case(expected)0:white_key=0;2:white_key=1;4:white_key=2;5:white_key=3;7:white_key=4;9:white_key=5;11:white_key=6;default:white_key=7;endcase
 wire [7:0] guide_leds=(8'b1<<white_key)|(matched?8'h80:8'h00);
 wire [7:0] activity=active[7:0]|active[15:8]|active[23:16]|active[31:24];
 assign leds_n=practice?~guide_leds:~activity;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin count<=0;position<=0;end
 else if(!practice)begin count<=0;position<=0;end
 else if(count==BEAT_CYCLES-1)begin count<=0;position<=position+1'b1;end
 else count<=count+1'b1;
endmodule
