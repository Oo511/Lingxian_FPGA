`timescale 1ns/1ps
// Four event tracks, two 4/4 bars, 64 frames/beat, 512 frames/loop.
// Snapshot storage is volatile FPGA RAM; each completed/partial take survives
// selection and instrument-page changes. Recording replaces only its own track.
module studio_loop #(parameter CLOCK_HZ=50000000)(
 input wire clk,rst_n,input wire [3:0] command,input wire [1:0] command_track,command_instrument,
 input wire [23:0] live_keys,input wire [7:0] live_gain,
 output reg [1:0] selected,output reg [7:0] instruments,
 output reg [3:0] filled,muted,output reg [127:0] activity,
 output reg playing,recording,armed,output reg [2:0] count_in,
 output reg [8:0] position,output reg [2:0] tempo,
 output wire [7:0] bpm,output reg [95:0] keys_out,output reg [31:0] gains_out,
 output reg [15:0] drum_fire,output reg click);
 localparam PLAY=1,REC=2,STOP=3,CLEAR=4,SELECT=5,INSTRUMENT=6,FASTER=7,SLOWER=8,MUTE=9;
 reg [31:0] bank0[0:511],bank1[0:511],bank2[0:511],bank3[0:511];
 reg [31:0] q0,q1,q2,q3,p0,p1,p2,p3;
 reg [3:0] valid_q,valid_p;reg [9:0] lengths[0:3];
 reg [31:0] clock_count;reg [8:0] preroll;
 reg [1:0] record_track,armed_track;
 reg [23:0] previous_live,rise_latch;
 wire [23:0] rises=live_keys&~previous_live;
 reg frame_d1,frame_d2;
 reg restart_blank;
 integer i;
 function [31:0] frame_cycles;input [2:0] t;begin
  case(t)0:frame_cycles=CLOCK_HZ/64;1:frame_cycles=(CLOCK_HZ*3)/256;
   2:frame_cycles=(CLOCK_HZ*3)/320;3:frame_cycles=(CLOCK_HZ*3)/384;
   4:frame_cycles=(CLOCK_HZ*3)/448;default:frame_cycles=(CLOCK_HZ*3)/512;endcase
 end endfunction
 assign bpm=tempo==0?60:tempo==1?80:tempo==2?100:tempo==3?120:tempo==4?140:160;
 wire frame_tick=playing&&clock_count==frame_cycles(tempo)-1;
 wire flush=recording&&(command==STOP||command==SELECT||command==REC||command==PLAY);
 wire write_take=recording&&(frame_tick||flush)&&command!=CLEAR;
 wire [1:0] record_instrument=instruments[record_track*2+:2];
 wire [23:0] take_keys=record_instrument==3?(rise_latch|rises):(live_keys|rise_latch|rises);
 wire [31:0] take_word={live_gain,take_keys};
 always @(posedge clk)begin
  q0<=bank0[position];q1<=bank1[position];q2<=bank2[position];q3<=bank3[position];
  p0<=q0;p1<=q1;p2<=q2;p3<=q3;
  valid_q<={filled[3]&&position<lengths[3],filled[2]&&position<lengths[2],filled[1]&&position<lengths[1],filled[0]&&position<lengths[0]};valid_p<=valid_q;
  if(write_take)case(record_track)
   0:bank0[position]<=take_word;1:bank1[position]<=take_word;
   2:bank2[position]<=take_word;3:bank3[position]<=take_word;
  endcase
 end
 wire playback=playing&&preroll==0&&!restart_blank;
 reg [31:0] word_value;reg [23:0] track_keys;
 always @* begin
  keys_out=0;gains_out=0;word_value=0;track_keys=0;
  for(integer k=0;k<4;k=k+1)begin
   case(k)0:word_value=p0;1:word_value=p1;2:word_value=p2;default:word_value=p3;endcase
   track_keys=(playback&&valid_p[k]&&!(recording&&record_track==k))?word_value[23:0]:24'b0;
   gains_out[k*8+:8]=(playback&&valid_p[k])?word_value[31:24]:8'd200;
   if(selected==k)begin
    track_keys=track_keys|live_keys;if(live_keys!=0||!playback||!valid_p[k])gains_out[k*8+:8]=live_gain;
   end
   if(instruments[k*2+:2]==3)track_keys=0; // Drums use events, never held gates.
   keys_out[k*24+:24]=muted[k]?24'b0:track_keys;
   if(muted[k])gains_out[k*8+:8]=0;
  end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  selected<=0;instruments<=0;filled<=0;muted<=0;activity<=0;
  playing<=0;recording<=0;armed<=0;count_in<=0;position<=0;tempo<=3;
  clock_count<=0;preroll<=0;record_track<=0;armed_track<=0;
  previous_live<=0;rise_latch<=0;frame_d1<=0;frame_d2<=0;drum_fire<=0;click<=0;restart_blank<=0;
  for(i=0;i<4;i=i+1)lengths[i]<=0;
 end else begin
  previous_live<=live_keys;rise_latch<=rise_latch|rises;
  frame_d1<=frame_tick;frame_d2<=frame_d1;drum_fire<=0;click<=0;
  if(instruments[selected*2+:2]==3&&!muted[selected])drum_fire[selected*4+:4]<=rises[3:0];
  if(playback&&frame_d2)begin
   for(i=0;i<4;i=i+1)begin
    if(instruments[i*2+:2]==3&&valid_q[i]&&!muted[i]&&!(recording&&record_track==i))begin
     case(i)0:drum_fire[3:0]<=q0[3:0]|((selected==0)?rises[3:0]:4'b0);
      1:drum_fire[7:4]<=q1[3:0]|((selected==1)?rises[3:0]:4'b0);
      2:drum_fire[11:8]<=q2[3:0]|((selected==2)?rises[3:0]:4'b0);
      3:drum_fire[15:12]<=q3[3:0]|((selected==3)?rises[3:0]:4'b0);endcase
    end
   end
  end
  if(write_take)begin
   lengths[record_track]<={1'b0,position}+1'b1;
   if(take_keys!=0)begin filled[record_track]<=1;activity[record_track*32+position[8:4]]<=1;end
  end
  if(playing)begin
   if(frame_tick)begin
    clock_count<=0;rise_latch<=0;
    if(preroll!=0)begin
     preroll<=preroll-1'b1;
     if(preroll[5:0]==1)begin click<=1;count_in<=(preroll-1'b1)>>6;end
     if(preroll==1)begin recording<=1;armed<=0;record_track<=armed_track;position<=0;count_in<=0;rise_latch<=0;end
    end else if(restart_blank)begin restart_blank<=0;position<=0;end
    else if(position==511)begin
     position<=0;
     if(recording)recording<=0;
     if(armed)begin
      recording<=1;record_track<=armed_track;armed<=0;filled[armed_track]<=0;lengths[armed_track]<=0;activity[armed_track*32+:32]<=0;
     end
    end else position<=position+1'b1;
   end else clock_count<=clock_count+1'b1;
  end
  case(command)
   PLAY:begin playing<=1;recording<=0;armed<=0;preroll<=0;count_in<=0;position<=0;clock_count<=0;restart_blank<=1;rise_latch<=0;end
   REC:begin
    if(recording)begin recording<=0;armed<=0;end
    else if(armed)begin armed<=0;preroll<=0;count_in<=0;end
    else if(!playing)begin
     playing<=1;position<=0;clock_count<=0;armed<=1;armed_track<=selected;preroll<=256;count_in<=4;
     filled[selected]<=0;lengths[selected]<=0;activity[selected*32+:32]<=0;restart_blank<=0;rise_latch<=0;click<=1;
    end else begin armed<=1;armed_track<=selected;end
   end
   STOP:begin playing<=0;recording<=0;armed<=0;preroll<=0;count_in<=0;position<=0;clock_count<=0;restart_blank<=0;rise_latch<=0;end
   CLEAR:begin
    filled[selected]<=0;lengths[selected]<=0;activity[selected*32+:32]<=0;muted[selected]<=0;
    if(record_track==selected)recording<=0;if(armed_track==selected)armed<=0;
   end
   SELECT:begin selected<=command_track;recording<=0;armed<=0;preroll<=0;count_in<=0;rise_latch<=0;previous_live<=0;end
   // Recorded events belong to the track, independently of its current sound.
   // Changing the sound must not erase a take or silently reject the action.
   INSTRUMENT:begin instruments[selected*2+:2]<=command_instrument;rise_latch<=0;previous_live<=0;end
   FASTER:if(!playing&&tempo<5)tempo<=tempo+1'b1;
   SLOWER:if(!playing&&tempo>0)tempo<=tempo-1'b1;
   MUTE:muted[command_track]<=!muted[command_track];
   default:begin end
  endcase
 end
endmodule
