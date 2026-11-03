`timescale 1ns/1ps
module tb_auto32;
 reg clk=0;always #10 clk=~clk;reg rst=0,host=1;
 tri scl,sda;pullup(scl);pullup(sda);
 touch_piano_top #(.AUTO_GAP_CYCLES(4096),.MIC_TICK_CYCLES(500),.MIC_CAL_MS(5)) dut(.sys_clk(clk),.rst_button_n(rst),.MIC_DO(1'b1),
  .play_button_n(1'b1),.mode_button_n(1'b1),.HOST_RX(host),.CTP_SCL(scl),.CTP_SDA(sda));
 defparam dut.receiver.DIV=8;
 reg [15:0] crc;integer timeout;
 function [15:0] cb;input [15:0] c;input [7:0] b;integer j;reg [15:0] x;begin
  x=c^{b,8'b0};for(j=0;j<8;j=j+1)x=x[15]?(x<<1)^16'h1021:x<<1;cb=x;
 end endfunction
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task byte_send;input [7:0] b;integer j;begin
  @(negedge clk);host=0;cycles(8);for(j=0;j<8;j=j+1)begin host=b[j];cycles(8);end host=1;cycles(8);
 end endtask
 task packet;input [7:0] c;input [31:0] d;begin
  byte_send(8'ha5);byte_send(8'h5a);byte_send(c);byte_send(d[7:0]);byte_send(d[15:8]);byte_send(d[23:16]);byte_send(d[31:24]);
  byte_send(8'ha5^8'h5a^c^d[7:0]^d[15:8]^d[23:16]^d[31:24]);cycles(10);
 end endtask
 task score_step;input [7:0] index,note,ticks;begin packet(8'h42,{8'b0,ticks,note,index});crc=cb(cb(crc,note),ticks);end endtask
 task organ_card;begin
  force dut.touch_healthy=1;force dut.count=1;force dut.x0=139;force dut.y0=265;force dut.frame=1;cycles(3);
  force dut.frame=0;force dut.count=0;cycles(3);force dut.frame=1;cycles(3);force dut.frame=0;
 end endtask
 task wait_play;begin
  timeout=0;while(!dut.auto_run&&timeout<6000)begin cycles(1);timeout=timeout+1;end
  if(!dut.auto_run)$fatal(1,"player failed to start");cycles(3);
 end endtask
 initial begin
  cycles(5);rst=1;cycles(20);organ_card();if(dut.instrument!=2)$fatal(1,"organ setup");
  packet(8'h44,1);if(dut.auto_run||dut.auto_delay!=0)$fatal(1,"empty score played");
  packet(8'h40,32'h00000401);packet(8'h41,12500000);
  crc=cb(16'hffff,4);crc=cb(cb(cb(cb(crc,8'h20),8'hbc),8'hbe),0);
  score_step(0,0,1);score_step(1,0,2);score_step(2,255,1);score_step(3,4,1);
  force dut.mic_ready=0;packet(8'h43,{crc,8'd4,8'd1});
  if(!dut.cfg_loaded||dut.cfg_token!=1||dut.instrument!=0||dut.auto_delay==0)$fatal(1,"valid UART commit did not select piano/start");
  force dut.guide.tick_cycles=32768;cycles(5000);
  if(dut.auto_run || dut.auto_delay!=1 || dut.score_keys!=0)$fatal(1,"startup quiet calibration was bypassed");
  release dut.mic_ready;wait_play();
  if(dut.score_keys!==1||dut.all_keys!==1||dut.mic_permission!==0)$fatal(1,"first C4 must play without touch or microphone");
  force dut.chord_down=1;force dut.glide_on=1;force dut.vibrato_depth=200;cycles(20000);
  if(dut.all_keys!==1||dut.active32==0||dut.fx_left==0||dut.engine.glide!==0||dut.engine.vibrato_depth!==0)$fatal(1,"autoplay DAC/tone/ownership failed");
  force dut.chord_down=0;release dut.glide_on;release dut.vibrato_depth;
  packet(8'h44,0);cycles(5);if(dut.auto_run||dut.auto_delay!=0||dut.all_keys!=0)$fatal(1,"App stop failed");
  cycles(600000);if(dut.active32!=0||dut.fx_left!=0||dut.fx_right!=0)$fatal(1,"stop left dry DAC sounding");
  packet(8'h44,1);wait_play();if(dut.guide.position!=0||dut.score_keys!=1)$fatal(1,"App replay did not start from first note");
  timeout=0;while(dut.auto_run&&timeout<170000)begin cycles(1);timeout=timeout+1;end
  if(dut.auto_run)$fatal(1,"one-shot did not finish");cycles(600000);
  if(dut.score_keys!=0||dut.all_keys!=0||dut.active32!=0||dut.fx_left!=0)$fatal(1,"one-shot did not return to silence");
  organ_card();packet(8'h40,32'h00000202);packet(8'h41,12500000);packet(8'h42,32'h00010000);packet(8'h43,32'hffff0202);
  if(dut.cfg_token!=1||dut.instrument!=2||dut.auto_run||dut.auto_delay!=0)$fatal(1,"partial/bad score triggered playback");
  $display("PASS real UART download -> CRC commit -> startup quiet wait, automatic piano PCM without touch/mic, manual isolation, App stop/replay, one-shot end and rejected partial download");$finish;
 end
 initial begin #30000000;$fatal(1,"autoplay integration timeout");end
endmodule
