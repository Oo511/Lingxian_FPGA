`timescale 1ns/1ps
module tb_guide_full;
 reg clk=0;always #10 clk=~clk;reg rst=0,practice=0;
 reg [23:0] keys=0;reg [31:0] active=0;
 wire [7:0] leds;wire matched;
 performance_led #(.BEAT_CYCLES(4)) dut(clk,rst,practice,keys,active,leds,matched);
 integer pos;reg [7:0] mask;reg [3:0] note;
 function [3:0] expected_note;input integer p;begin
  case(p/2)
   0:expected_note=0;1:expected_note=7;2:expected_note=9;3:expected_note=7;
   4:expected_note=5;5:expected_note=4;6:expected_note=2;7:expected_note=0;
   8:expected_note=7;9:expected_note=5;10:expected_note=4;11:expected_note=2;
   12:expected_note=7;13:expected_note=5;14:expected_note=4;default:expected_note=2;
  endcase
 end endfunction
 function [7:0] note_mask;input [3:0] n;begin
  case(n)0:note_mask=1;2:note_mask=2;4:note_mask=4;5:note_mask=8;
   7:note_mask=16;9:note_mask=32;default:note_mask=64;endcase
 end endfunction
 initial begin
  #100;rst=1;@(negedge clk);practice=1;
  // No active clock edges during each combinational check; 4 clocks per slot.
  for(pos=0;pos<32;pos=pos+1)begin
   note=expected_note(pos);mask=note_mask(note);keys=0;#1;
   if(dut.position!==pos || leds!==~mask || matched)$fatal(1,"guide slot %d no-key mismatch",pos);
   keys=24'd1<<note;#1;
   if(leds!==~(mask|8'h80) || !matched)$fatal(1,"correct key not matched slot %d",pos);
   keys=24'd1<<((note+1)%12);#1;
   if(leds!==~mask || matched)$fatal(1,"wrong key matched slot %d",pos);
   keys=0;repeat(4)@(negedge clk);
  end
  if(dut.position!==0)$fatal(1,"32-slot loop failed");
  practice=0;active=32'h80000000;#1;
  if(leds!==8'h7f)$fatal(1,"normal high voice activity lost");
  repeat(2)@(negedge clk);practice=1;active=0;#1;
  if(dut.position!==0 || leds!==8'hfe)$fatal(1,"guide restart not C");
  rst=0;keys=0;practice=0;active=0;#1;
  if(leds!==8'hff)$fatal(1,"idle not off");
  $display("PASS all 32 guide slots, target LEDs, correct/wrong key feedback, wrap, restart and normal high-voice activity");$finish;
 end
endmodule
