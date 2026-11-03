`timescale 1ns/1ps
module tb_studio_loop;
 reg clk=0;always #10 clk=~clk;reg rst=0;reg [3:0] cmd=0;reg [1:0] target=0,tone=0;reg [23:0] live=0;
 wire [1:0] selected;wire [7:0] instruments,bpm;wire [3:0] filled,muted;wire [127:0] activity;
 wire playing,recording,armed;wire [2:0] count_in,tempo;wire [8:0] pos;wire [95:0] keys;wire [31:0] gains;wire [15:0] hits;wire click;
 studio_loop #(.CLOCK_HZ(6400)) dut(clk,rst,cmd,target,tone,live,8'd200,selected,instruments,filled,muted,activity,
  playing,recording,armed,count_in,pos,tempo,bpm,keys,gains,hits,click);
 reg [31:0] saved[0:511];integer i,timeout,clicks,playback_hits;
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task command;input [3:0] c;input [1:0] t,v;begin @(negedge clk);cmd=c;target=t;tone=v;@(negedge clk);cmd=0;cycles(2);end endtask
 task wait_rec;begin timeout=0;while(!recording&&timeout<40000)begin cycles(1);timeout=timeout+1;end if(!recording)$fatal(1,"record start timeout");end endtask
 task wait_pos;input [8:0] p;begin timeout=0;while(pos!=p&&timeout<40000)begin cycles(1);timeout=timeout+1;end if(pos!=p)$fatal(1,"position timeout %d",p);end endtask
 task wait_end;begin timeout=0;while(recording&&timeout<40000)begin cycles(1);timeout=timeout+1;end if(recording)$fatal(1,"record did not stop after one loop");cycles(5);end endtask
 always @(negedge clk)if(rst)begin
  if(click)clicks=clicks+1;
  if(!recording&&live==0&&hits[3:0]!=0&&!muted[0])begin
   playback_hits=playback_hits+1;
   if(hits[3:0]!==dut.bank0[pos][3:0])$fatal(1,"drum playback frame misalignment at %d",pos);
  end
 end
 initial begin
  clicks=0;playback_hits=0;cycles(4);rst=1;cycles(3);if(bpm!=120)$fatal(1,"default tempo");
  command(6,0,3);command(2,0,0);if(!armed||count_in!=4||recording)$fatal(1,"count-in not armed");
  wait_rec();if(pos!=0||count_in!=0||clicks<4)$fatal(1,"count-in alignment/clicks");
  live=1;cycles(10);live=0;wait_pos(128);live=2;cycles(10);live=0;
  wait_pos(256);live=4;cycles(10);live=0;wait_pos(384);live=8;cycles(10);live=0;wait_end();
  if(!filled[0]||dut.lengths[0]!=512||activity[31:0]!==32'h01010101)$fatal(1,"drum take or activity lost %h",activity[31:0]);
  for(i=0;i<512;i=i+1)saved[i]=dut.bank0[i];
  command(5,1,0);command(6,0,0);command(2,0,0);if(!armed||recording)$fatal(1,"overdub did not wait for loop boundary");
  wait_rec();live=24'h91;wait_pos(128);live=0;wait_pos(256);live=128;wait_pos(384);live=0;wait_end();
  if(filled[1:0]!=3||dut.lengths[1]!=512)$fatal(1,"second take absent");
  for(i=0;i<512;i=i+1)if(saved[i]!==dut.bank0[i])$fatal(1,"recording track2 corrupted track1 %d",i);
  if(playback_hits<4)$fatal(1,"first drum track did not continue during second take");
  command(5,0,0);command(6,0,1);if(instruments[1:0]!=1||filled[1:0]!=3||dut.lengths[0]!=512)$fatal(1,"recorded track instrument change or data retention failed");
  for(i=0;i<512;i=i+1)if(saved[i]!==dut.bank0[i])$fatal(1,"instrument switch corrupted recorded event %d",i);
  command(6,0,3);if(instruments[1:0]!=3)$fatal(1,"return to original drum instrument failed");
  command(9,0,0);if(!muted[0]||gains[7:0]!=0)$fatal(1,"mute failed");
  command(3,0,0);cycles(5);if(playing||keys!=0||filled[1:0]!=3)$fatal(1,"stop erased data or held notes");
  command(7,0,0);if(bpm!=140)$fatal(1,"stopped tempo edit");command(8,0,0);
  command(1,0,0);cycles(70);if(keys[47:24]==0)$fatal(1,"recorded piano did not replay");
  command(5,1,0);command(4,0,0);if(filled[1]||!filled[0])$fatal(1,"clear affected wrong track");
  for(i=0;i<512;i=i+1)if(saved[i]!==dut.bank0[i])$fatal(1,"selection/clear corrupted track1");
  command(5,2,0);command(6,0,2);command(2,0,0);wait_rec();live=4;cycles(10);command(5,3,0);live=0;cycles(5);
  if(recording||!filled[2]||dut.lengths[2]!=1||dut.bank2[0][23:0]!=4)$fatal(1,"return/select did not retain partial take");
  $display("PASS studio count-in, full-loop drum record, loop-aligned piano layering, retained track1 bytes, drum event timing, mute, stop, tempo, clear-one and return with partial take");$finish;
 end
 initial begin #20000000;$fatal(1,"studio loop timeout");end
endmodule
