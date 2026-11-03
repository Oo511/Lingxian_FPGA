`timescale 1ns/1ps
module tb_encoder_display35;
 reg clk=0;always #10 clk=~clk;reg rst=0;reg [4:0] step=0;reg [6:0] percent=60;reg muted=0;reg playing=0;reg [127:0] activity=0;
 wire sck,mosi,dc,cs,reset,ready;integer sent,baseline,timeout;
 studio_display #(.RESET_CYCLES(2),.WAIT_CYCLES(4),.SPI_HALF_CYCLES(1)) dut(clk,rst,1'b0,2'd0,8'b0,8'd120,4'b0,4'b0,activity,step,playing,1'b0,1'b0,3'b0,1'b0,1'b0,1'b1,sck,mosi,dc,cs,reset,ready,1'b0,8'd0,1'b0,1'b0,3'd0,percent,muted);
 always @(posedge clk)if(dut.start)sent=sent+1;
 initial begin
  sent=0;#100;rst=1;timeout=0;
  while(!ready&&timeout<5000000)begin @(negedge clk);timeout=timeout+1;end
  if(!ready)$fatal(1,"initial LCD frame failed");repeat(4)@(negedge clk);baseline=sent;
  playing=1;step=5;activity[5]=1;timeout=0;
  while((dut.last_cursor!={1'b1,1'b0,5'd5}||dut.last_activity!=activity||dut.last_bottom!={3'b100,3'b000})&&timeout<1500000)begin @(negedge clk);timeout=timeout+1;end
  if(timeout>=1500000||!ready)$fatal(1,"partial cursor/cell update did not finish");
  if(sent-baseline>40000||sent-baseline<3800)$fatal(1,"cursor update repainted a full frame or no pixels %d",sent-baseline);
  baseline=sent;@(negedge clk);percent=64;muted=1;timeout=0;
  while(dut.last_volume!={1'b1,7'd64}&&timeout<300000)begin @(negedge clk);timeout=timeout+1;end
  if(timeout>=300000||sent-baseline<6400||sent-baseline>6500)$fatal(1,"volume/mute strip did not update as a bounded partial rectangle");
  $display("PASS VOL/MUTE dynamic partial-strip update, plus LCD initialization, landscape partial windows, moving cursor/cell refresh without full-frame repaint, bytes=%d",sent-baseline);$finish;
 end
 initial begin #150000000;$fatal(1,"LCD test timeout");end
endmodule
