`timescale 1ns/1ps
module tb_encoder_volume31;
 reg clk=0;always #10 clk=~clk;reg rst=0,a=1,b=1,sw=1;
 wire [6:0] pct,rev,half;wire mute;wire [15:0] detents,invalids;
 encoder_volume #(.SAMPLE_CYCLES(8),.SW_TICKS(3)) dut(.clk(clk),.rst_n(rst),.encoder_clk(a),.encoder_dt(b),.encoder_sw_n(sw),.percent(pct),.muted(mute),.detents(detents),.invalid_edges(invalids));
 encoder_volume #(.SAMPLE_CYCLES(8),.SW_TICKS(3),.REVERSE(1)) backwards(.clk(clk),.rst_n(rst),.encoder_clk(a),.encoder_dt(b),.encoder_sw_n(sw),.percent(rev));
 encoder_volume #(.SAMPLE_CYCLES(8),.SW_TICKS(3),.EDGES_PER_DETENT(2)) halfstep(.clk(clk),.rst_n(rst),.encoder_clk(a),.encoder_dt(b),.encoder_sw_n(sw),.percent(half));
 task hold;input [1:0] ab;input button;begin
  @(negedge clk);a=ab[1];b=ab[0];sw=button;repeat(24)@(negedge clk);
 end endtask
 task up;begin hold(1,1);hold(0,1);hold(2,1);hold(3,1);end endtask
 task down;begin hold(2,1);hold(0,1);hold(1,1);hold(3,1);end endtask
 task reset;input button;begin rst=0;a=1;b=1;sw=button;repeat(10)@(negedge clk);rst=1;repeat(60)@(negedge clk);end endtask
 integer i;reg [15:0] n;
 initial begin
  reset(1);if(pct!==60||mute)$fatal(1,"default");
  for(i=0;i<20;i=i+1)begin hold(1,1);hold(3,1);end
  if(pct!==60 || detents!==0)$fatal(1,"contact bounce created a detent");
  up();if(pct!==62||rev!==58||half!==64||detents!==1)$fatal(1,"direction/edge configuration");
  down();if(pct!==60||rev!==60||half!==60||detents!==2)$fatal(1,"reverse step");
  hold(1,1);hold(0,1);hold(1,1);hold(3,1);if(pct!==60)$fatal(1,"half-turn reversal");
  hold(0,1);hold(3,1);if(invalids!==2||pct!==60)$fatal(1,"diagonal invalid phase");
  for(i=0;i<100;i=i+1)up();if(pct!==100)$fatal(1,"upper clamp");
  for(i=0;i<100;i=i+1)down();if(pct!==0)$fatal(1,"lower clamp");
  reset(1);
  // Sub-ms glitches cannot produce a complete legal quadrature detent.
  @(negedge clk);a=0;@(negedge clk);a=1;repeat(40)@(negedge clk);if(pct!==60)$fatal(1,"glitch");
  hold(3,0);repeat(80)@(negedge clk);if(!mute)$fatal(1,"press to mute");
  n=detents;repeat(300)@(negedge clk);if(!mute||detents!==n)$fatal(1,"held switch repeated");
  hold(3,1);hold(3,0);repeat(30)@(negedge clk);if(mute)$fatal(1,"second press restore");
  reset(0);repeat(100)@(negedge clk);if(mute)$fatal(1,"boot-held false press");
  hold(3,1);hold(3,0);repeat(30)@(negedge clk);if(!mute)$fatal(1,"release and repress after boot");
  $display("PASS synchronized Tang quadrature, bounce/reversal/glitch/diagonal rejection, 2/4-edge and reverse options, limits, press/hold and boot-held handling");$finish;
 end
 initial begin #10000000;$fatal(1,"encoder timeout");end
endmodule
