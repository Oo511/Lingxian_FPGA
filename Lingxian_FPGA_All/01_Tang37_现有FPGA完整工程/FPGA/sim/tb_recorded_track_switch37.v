`timescale 1ns/1ps
module tb_recorded_track_switch37;
 reg clk=0;always #10 clk=~clk;reg rst=0,host=1;
 tri scl,sda;pullup(scl);pullup(sda);
 studio_board_top dut(.ENCODER_CLK(1'b1),.ENCODER_DT(1'b1),.ENCODER_SW_N(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
  .MIC_DO(1'b1),.HOST_RX(host),.CTP_SCL(scl),.CTP_SDA(sda));
 defparam dut.receiver.DIV=8;defparam dut.loop.CLOCK_HZ=6400;
 defparam dut.TOUCH_BOOT_CYCLES=20;defparam dut.TOUCH_RESET_CYCLES=5;defparam dut.TOUCH_RETRY_CYCLES=40;
 integer k,j;reg [31:0] saved_bank[0:511];reg [3:0] saved_filled;reg [31:0] saved_word;reg [9:0] saved_length;reg [127:0] saved_activity;reg [15:0] crc;integer timeout;
 function [15:0] cb;input [15:0] c;input [7:0] b;integer j;reg [15:0] v;begin v=c^{b,8'b0};for(j=0;j<8;j=j+1)v=v[15]?(v<<1)^16'h1021:v<<1;cb=v;end endfunction
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task byte_send;input [7:0] b;integer j;begin @(negedge clk);host=0;cycles(8);for(j=0;j<8;j=j+1)begin host=b[j];cycles(8);end host=1;cycles(8);end endtask
 task packet;input [7:0] c;input [31:0] d;begin
  byte_send(8'ha5);byte_send(8'h5a);byte_send(c);byte_send(d[7:0]);byte_send(d[15:8]);byte_send(d[23:16]);byte_send(d[31:24]);byte_send(8'ha5^8'h5a^c^d[7:0]^d[15:8]^d[23:16]^d[31:24]);cycles(10);
 end endtask
 task keys;input [7:0] inst;input [23:0] k;begin packet(inst,{8'd220,k});end endtask
 task tap;input [11:0] xx,yy;begin
  force dut.healthy=1;force dut.screen_ready=1;force dut.count=1;force dut.x0=239-yy;force dut.y0=xx;force dut.frame=1;cycles(3);
  force dut.count=0;cycles(3);force dut.frame=0;cycles(3);
 end endtask
 initial begin
  cycles(5);rst=1;cycles(10);tap(20,60);if(!dut.picker)$fatal(1,"track picker did not open");
  tap(230,160);if(dut.picker||dut.instrument!=3)$fatal(1,"drum card did not switch MCU instrument state");
  keys(3,1);cycles(30000);if(dut.dry==0||dut.receiver.instrument!=3||!dut.online)$fatal(1,"real drum UART -> PCM path");
  keys(3,0);tap(120,220);timeout=0;while(!dut.recording&&timeout<15000)begin cycles(1);timeout=timeout+1;end
  if(!dut.recording)$fatal(1,"UI REC/count-in failed");keys(3,2);keys(3,0);tap(20,100);
  if(dut.selected!=1||!dut.filled[0]||dut.recording||!dut.picker)$fatal(1,"return to track2 did not retain track1");
  tap(60,80);if(dut.instrument!=0)$fatal(1,"piano card");keys(0,1);cycles(25000);
  if(dut.engine.active[15:8]==0||dut.dry==0||!dut.filled[0])$fatal(1,"second instrument monitoring/first take retention");
  keys(0,0);tap(200,220);if(dut.playing||dut.recording)$fatal(1,"UI STOP");
  tap(95,60);if(!dut.muted[0])$fatal(1,"UI track mute");
  // Stored score still loads quietly; explicit App play temporarily uses piano.
  packet(8'h40,32'h00000101);packet(8'h41,12500000);crc=cb(16'hffff,1);crc=cb(cb(cb(cb(crc,8'h20),8'hbc),8'hbe),0);
  packet(8'h42,32'h00010000);crc=cb(cb(crc,0),1);packet(8'h43,{crc,8'd1,8'd1});
  if(!dut.cfg_loaded||dut.song_mode)$fatal(1,"score restore disrupted workstation");
  tap(20,60);if(!dut.picker)$fatal(1,"reopen existing track");
  force dut.mic_ready=1;packet(8'h44,1);cycles(50020);
  if(!dut.score_run||dut.instrument!=0||dut.picker||dut.score_keys!=1||!dut.filled[0])$fatal(1,"App score audition or studio data retention");
  packet(8'h44,0);cycles(5);if(dut.song_mode||dut.playing||!dut.filled[0])$fatal(1,"App global stop lost project");
  saved_word=dut.loop.bank0[0];saved_length=dut.loop.lengths[0];saved_activity=dut.activity;
  tap(40,220);if(!dut.playing)$fatal(1,"playback recovery precondition");
  force dut.frame=0;force dut.healthy=0;cycles(41);
  if(dut.CTP_RST||!dut.playing||!dut.filled[0])$fatal(1,"touch reset stopped playback or lost filled track");
  if(dut.loop.bank0[0]!==saved_word||dut.loop.lengths[0]!=saved_length||dut.activity!=saved_activity)$fatal(1,"touch reset changed recorded RAM or metadata");
  cycles(25);force dut.healthy=1;cycles(3);tap(200,220);
  if(dut.playing||!dut.filled[0])$fatal(1,"STOP unavailable after isolated touch recovery");
  saved_filled=dut.filled;
  for(j=0;j<512;j=j+1)saved_bank[j]=dut.loop.bank0[j];
  for(k=0;k<8;k=k+1)begin
   tap(20,60);if(!dut.picker)$fatal(1,"recorded track picker failed");
   tap((k%2)?230:60,(k%4>=2)?160:80);
   if(dut.picker||dut.instrument!=k%4)$fatal(1,"recorded track card did not switch and return %d",k);
   if(dut.filled!=saved_filled||dut.loop.lengths[0]!=saved_length||dut.activity!=saved_activity)$fatal(1,"instrument switch lost recorded metadata");
   for(j=0;j<512;j=j+1)if(dut.loop.bank0[j]!==saved_bank[j])$fatal(1,"instrument switch changed recorded RAM %d",j);
  end
  tap(20,100);tap(230,80);
  if(dut.picker||dut.selected!=1||dut.instrument!=1)$fatal(1,"next empty track selection regressed");
  $display("PASS eight recorded-track instrument changes close picker directly; all 512 RAM words and track metadata retained; next empty track selectable");
  $display("PASS recorded event RAM and playback preserved across touch reset; STOP responds after recovery");
  $display("PASS Tang touch track/card/REC/return/mute/STOP + real DRUM3/piano UART PCM; retained project and non-destructive App single-score audition");$finish;
 end
 initial begin #10000000;$fatal(1,"studio board integration timeout");end
endmodule
