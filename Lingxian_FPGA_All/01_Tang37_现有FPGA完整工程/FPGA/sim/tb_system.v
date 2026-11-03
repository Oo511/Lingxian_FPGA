`timescale 1ns/1ps
module tb_system;
 reg clk=0;always #10 clk=~clk;reg rst=0,host=1;
 tri scl,sda;pullup(scl);pullup(sda);
 wire tx,pa,bck,ws,din;wire healthy;wire [3:0] active;
 integer release_cycles;
 touch_piano_top dut(.MIC_DO(1'b1),.sys_clk(clk),.rst_button_n(rst),.play_button_n(1'b1),.mode_button_n(1'b1),
 .HOST_RX(host),.HOST_TX(tx),.CTP_SCL(scl),.CTP_SDA(sda),.HP_BCK(bck),.HP_WS(ws),.HP_DIN(din),
 .PA_EN(pa),.touch_healthy(healthy),.voice_active(active));
 task send_byte;input [7:0] b;integer i;begin
  @(negedge clk);host=0;repeat(434)@(negedge clk);
  for(i=0;i<8;i=i+1)begin host=b[i];repeat(434)@(negedge clk);end
  host=1;repeat(434)@(negedge clk);
 end endtask
 task frame;input [23:0] keys;input [7:0] ins;begin
  send_byte(8'ha5);send_byte(8'h5a);send_byte(ins);
  send_byte(keys[7:0]);send_byte(keys[15:8]);send_byte(keys[23:16]);send_byte(8'd180);
  send_byte(8'ha5^8'h5a^ins^keys[7:0]^keys[15:8]^keys[23:16]^8'd180);
  repeat(3100)@(negedge clk);
 end endtask
 initial begin
  #100;rst=1;repeat(30)@(negedge clk);
  frame(24'h1091,0);
  repeat(10000)@(negedge clk);
  if(active!==4'hf || pa!==0 || dut.fx_left==0)$fatal(1,"host to four voice DAC active=%h pa=%b pcm=%d keys=%h",active,pa,dut.fx_left,dut.remote_keys);
  frame(0,0);
  if(dut.effective_gain!==8'd180)$fatal(1,"note-off must retain remote expression gain");
  release_cycles=0;
  while(active!==0 && release_cycles<600000)begin @(negedge clk);release_cycles=release_cycles+1;end
  if(active!==0)$fatal(1,"host noteoff");
  // The 2.8-inch screen exclusively selects instruments; raw portrait point.
  force dut.touch_healthy=1;force dut.count=1;force dut.x0=139;force dut.y0=200;
  force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  if(dut.instrument!==1)$fatal(1,"touch instrument selection");
  frame(1,1);repeat(4000)@(negedge clk);
  if(dut.engine.guitar_owner==0 || dut.active32==0)$fatal(1,"guitar voice ownership");
  if(dut.engine.mapped(0,1)!==7'd40 || dut.engine.mapped(23,1)!==7'd67)
   $fatal(1,"guitar mapping");
  force dut.count=0;force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  force dut.count=1;force dut.x0=19;force dut.y0=20;force dut.frame=1;
  repeat(3)@(negedge clk);force dut.frame=0;
  if(!dut.glide_on)$fatal(1,"glide UI control");
  force dut.count=0;force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  force dut.count=1;force dut.y0=220;force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  if(dut.vibrato_depth==0)$fatal(1,"vibrato slider depth");
  if(dut.vibrato_depth!==8'd96)$fatal(1,"vibrato slider midpoint mapping");
  force dut.y0=250;force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  if(dut.vibrato_depth<=8'd96)$fatal(1,"vibrato slider must be monotonic");
  force dut.y0=319;force dut.frame=1;repeat(3)@(negedge clk);force dut.frame=0;
  if(dut.vibrato_depth!==8'hff)$fatal(1,"vibrato slider maximum");
  force dut.chord_down=1;repeat(10000)@(negedge clk);
  if((dut.all_keys&24'h1091)!==24'h1091)$fatal(1,"KEY1 four note chord");
  $display("PASS UART to 32-voice engine / PT8211, release, guitar mapping, glide/vibrato UI and KEY1 chord");$finish;
 end
 initial begin #60000000;$fatal(1,"system timeout");end
// Legacy regression enables microphone; tb_tang_mic exercises actual DO.
 initial begin force dut.mic_permission=1;end
endmodule
