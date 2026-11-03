`timescale 1ns/1ps
// Golden values derive independently from A4=440 equal temperament at 50MHz/1024.
module tb_guitar_pitch;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0;
 reg [23:0] keys=0;wire signed [15:0] sample;wire [31:0] active;
 poly32_engine dut(clk,rst,tick,keys,2'd1,2'd1,1'b0,8'd0,7'd60,sample,active);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(100)@(negedge clk);end endtask
 function [31:0] expected;input integer key;begin case(key)
  0:expected=32'd7248587;1:expected=32'd7679610;2:expected=32'd8136263;3:expected=32'd8620071;
  4:expected=32'd9675702;5:expected=32'd10251050;6:expected=32'd10860609;7:expected=32'd11506414;
  8:expected=32'd12915513;9:expected=32'd13683509;10:expected=32'd14497173;11:expected=32'd15359220;
  12:expected=32'd17240142;13:expected=32'd18265294;14:expected=32'd19351405;15:expected=32'd20502099;
  16:expected=32'd21721217;17:expected=32'd23012828;18:expected=32'd24381242;19:expected=32'd25831026;
  20:expected=32'd28994347;21:expected=32'd30718440;22:expected=32'd32545054;default:expected=32'd34480283;
 endcase end endfunction
 integer key,i,fd,nonzero;reg [31:0] before_phase,delta;
 initial begin
  fd=$fopen("guitar_pitch.csv","w");
  $fdisplay(fd,"key,string_index,fret,phase_step,frequency_hz");
  for(key=0;key<24;key=key+1)begin
   rst=0;keys=0;repeat(4)@(negedge clk);rst=1;keys=24'b1<<key;
   repeat(12)step;
   if(!active[0] || dut.gates!==32'b1)$fatal(1,"independent guitar allocation key=%0d",key);
   if(dut.VOICE[0].unit.shape!==1 || dut.VOICE[0].unit.adsr.profile!==1)
    $fatal(1,"wrong guitar timbre/envelope key=%0d",key);
   nonzero=0;
   for(i=0;i<64;i=i+1)begin
    before_phase=dut.VOICE[0].unit.phase;step;
    delta=dut.VOICE[0].unit.phase-before_phase;
    if(delta!==expected(key))$fatal(1,"wrong physical phase advance key=%0d expected=%0d got=%0d",key,expected(key),delta);
    if(sample!=0)nonzero=nonzero+1;
   end
   if(nonzero<32)$fatal(1,"guitar allocated but missing PCM key=%0d",key);
   $fdisplay(fd,"%0d,%0d,%0d,%0d,%0.6f",key,key/4,key%4,expected(key),expected(key)*48828.125/4294967296.0);
  end
  $fclose(fd);
  $display("PASS 24 guitar string/fret pitches: correct phase advance, independent voice, pluck envelope and nonzero PCM");$finish;
 end
endmodule
