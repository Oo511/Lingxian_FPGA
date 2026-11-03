`timescale 1ns/1ps
// ILI9341-compatible landscape renderer. Only changed cells/cursor strips are
// redrawn during playback; the proven conservative SPI clock is retained.
module performance_display40 #(parameter RESET_CYCLES=1000000,WAIT_CYCLES=6000000,SPI_HALF_CYCLES=16)(
 input wire clk,rst_n,picker,input wire [1:0] selected,input wire [7:0] instruments,bpm,
 input wire [3:0] filled,muted,input wire [127:0] activity,input wire [4:0] step,
 input wire playing,recording,armed,input wire [2:0] count_in,input wire song_mode,fx,healthy,
 output wire sck,mosi,dc,cs_n,output reg lcd_rst_n,output reg screen_ready,
 input wire glide_on,input wire [7:0] vib_depth,input wire guide_on,test_mode,input wire [2:0] fx_mode,input wire [6:0] master_percent,input wire master_muted,input wire [23:0] live_keys,input wire [7:0] live_gain);
 reg start,dc_in;reg [7:0] data;wire busy,done;
 lcd_spi_byte #(.HALF_CYCLES(SPI_HALF_CYCLES)) spi(clk,rst_n,start,dc_in,data,busy,done,sck,mosi,dc);
 assign cs_n=!lcd_rst_n;
 reg [4:0] state;reg [31:0] timer;reg [5:0] index;reg [2:0] job;
 reg [8:0] x0,x1,y0,y1,u,v;reg [15:0] pixel;reg [8:0] entry;
 reg shown_picker,shown_play,shown_rec,shown_arm,shown_song,shown_fx,shown_health;
 reg [1:0] shown_selected;reg [7:0] shown_inst,shown_bpm;reg [3:0] shown_filled,shown_muted;
 reg [127:0] shown_activity,last_activity;reg [4:0] shown_step;reg [2:0] shown_count;
 reg shown_glide,shown_guide,shown_test;reg [7:0] shown_vib;reg [10:0] last_panel;
 reg last_picker;reg [17:0] last_meta;reg [12:0] last_top;reg [2:0] shown_fx_mode;reg [5:0] last_bottom;reg [6:0] last_cursor;
 reg [6:0] shown_percent;reg shown_mute;reg [7:0] last_volume;
 reg [6:0] activity_index;
 wire [17:0] meta={selected,instruments,filled,muted};
 wire [12:0] top_state={bpm,song_mode,fx_mode,healthy};wire [5:0] bottom_state={playing,recording,armed,count_in};
 wire [6:0] cursor_state={playing,recording,step};
 function [6:0] first_changed;input [127:0] b;reg [127:0] q;reg [6:0] n;begin
  q=b;n=0;if(q[63:0]==0)begin n=n+64;q=q>>64;end
  if(q[31:0]==0)begin n=n+32;q=q>>32;end if(q[15:0]==0)begin n=n+16;q=q>>16;end
  if(q[7:0]==0)begin n=n+8;q=q>>8;end if(q[3:0]==0)begin n=n+4;q=q>>4;end
  if(q[1:0]==0)begin n=n+2;q=q>>2;end if(!q[0])n=n+1;first_changed=n;
 end endfunction
 reg [6:0] changed;
 always @(posedge clk)changed<=first_changed(activity^last_activity);
 wire [10:0] panel_state={glide_on,vib_depth,guide_on,test_mode};
 reg [23:0] shown_keys,last_keys;reg [7:0] shown_gain,last_gain;
 wire [15:0] rgb;
 performance_pixels40 pixels(clk,319-v,u,shown_inst[shown_selected*2+:2],shown_keys,shown_gain,rgb);
 function [8:0] init_byte;input [5:0] n;begin case(n)
  0:init_byte=9'h001;1:init_byte=9'h011;2:init_byte=9'h03a;3:init_byte=9'h155;
  4:init_byte=9'h036;5:init_byte=9'h188;6:init_byte=9'h029;default:init_byte=0;endcase end endfunction
 function [8:0] window_byte;input [5:0] n;input [8:0] xa,xb,ya,yb;reg [8:0] va,vb;begin
  va=319-xb;vb=319-xa;
  case(n)0:window_byte=9'h02a;1:window_byte={1'b1,7'b0,ya[8]};2:window_byte={1'b1,ya[7:0]};
   3:window_byte={1'b1,7'b0,yb[8]};4:window_byte={1'b1,yb[7:0]};5:window_byte=9'h02b;
   6:window_byte={1'b1,7'b0,va[8]};7:window_byte={1'b1,va[7:0]};
   8:window_byte={1'b1,7'b0,vb[8]};9:window_byte={1'b1,vb[7:0]};10:window_byte=9'h02c;default:window_byte=0;endcase
 end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  shown_keys<=0;last_keys<=0;shown_gain<=200;last_gain<=200;state<=0;timer<=0;index<=0;job<=0;start<=0;dc_in<=0;data<=0;lcd_rst_n<=0;screen_ready<=0;
  x0<=0;x1<=319;y0<=0;y1<=239;u<=0;v<=0;pixel<=0;entry<=0;
  shown_picker<=0;shown_selected<=0;shown_inst<=0;shown_bpm<=120;shown_filled<=0;shown_muted<=0;shown_activity<=0;
  shown_step<=0;shown_play<=0;shown_rec<=0;shown_arm<=0;shown_count<=0;shown_song<=0;shown_fx<=0;shown_health<=0;
  last_picker<=0;last_meta<=0;last_top<=0;last_bottom<=0;last_cursor<=0;last_activity<=0;activity_index<=0;shown_glide<=0;shown_vib<=0;shown_guide<=0;shown_test<=0;last_panel<=0;shown_fx_mode<=0;shown_percent<=60;shown_mute<=0;last_volume<=0;
 end else begin
  start<=0;
  case(state)
   0:if(timer==RESET_CYCLES-1)begin lcd_rst_n<=1;timer<=0;state<=1;end else timer<=timer+1;
   1:if(timer==WAIT_CYCLES-1)begin timer<=0;index<=0;state<=2;end else timer<=timer+1;
   2:begin entry=init_byte(index);data<=entry[7:0];dc_in<=entry[8];start<=1;state<=3;end
   3:if(done)begin if(index==0||index==1||index==6)begin timer<=0;state<=4;end else begin index<=index+1'b1;state<=2;end end
   4:if(timer==WAIT_CYCLES-1)begin
    timer<=0;if(index==6)begin job<=0;x0<=0;x1<=319;y0<=0;y1<=239;state<=5;end else begin index<=index+1'b1;state<=2;end
   end else timer<=timer+1;
   5:begin
    if(job!=5)begin
     shown_keys<=live_keys;shown_gain<=live_gain;
     shown_picker<=picker;shown_selected<=selected;shown_inst<=instruments;shown_bpm<=bpm;shown_filled<=filled;shown_muted<=muted;
     shown_activity<=activity;shown_step<=step;shown_play<=playing;shown_rec<=recording;shown_arm<=armed;shown_count<=count_in;
     shown_song<=song_mode;shown_fx<=fx;shown_health<=healthy;
     shown_percent<=master_percent;shown_mute<=master_muted;shown_fx_mode<=fx_mode;shown_glide<=glide_on;shown_vib<=vib_depth;shown_guide<=guide_on;shown_test<=test_mode;
    end
    u<=y0;v<=319-x1;index<=0;state<=6;
   end
   6:begin entry=window_byte(index,x0,x1,y0,y1);data<=entry[7:0];dc_in<=entry[8];start<=1;state<=7;end
   7:if(done)begin if(index==10)state<=11;else begin index<=index+1'b1;state<=6;end end
   8:begin pixel<=rgb;data<=rgb[15:8];dc_in<=1;start<=1;state<=9;end
   9:if(done)begin data<=pixel[7:0];start<=1;state<=10;end
   10:if(done)begin
    if(u==y1)begin u<=y0;if(v==319-x0)state<=14;else begin v<=v+1'b1;state<=11;end end
    else begin u<=u+1'b1;state<=11;end
   end
   11:state<=12;12:state<=13;13:state<=8;
   14:begin
    state<=15;
    case(job)
     0:begin
      last_keys<=shown_keys;last_gain<=shown_gain;      last_volume<={shown_mute,shown_percent};last_panel<={shown_glide,shown_vib,shown_guide,shown_test};last_picker<=shown_picker;last_meta<={shown_selected,shown_inst,shown_filled,shown_muted};
      last_top<={shown_bpm,shown_song,shown_fx_mode,shown_health};last_bottom<={shown_play,shown_rec,shown_arm,shown_count};
      last_cursor<={shown_play,shown_rec,shown_step};last_activity<=shown_activity;screen_ready<=1;
     end
     1:last_top<={shown_bpm,shown_song,shown_fx_mode,shown_health};
     2:last_bottom<={shown_play,shown_rec,shown_arm,shown_count};
     3:last_meta<={shown_selected,shown_inst,shown_filled,shown_muted};
     4:begin job<=5;x0<=112+shown_step*6;x1<=117+shown_step*6;y0<=40;y1<=199;state<=5;end
     5:last_cursor<={shown_play,shown_rec,shown_step};
     6:last_activity[activity_index]<=shown_activity[activity_index];
     7:last_volume<={shown_mute,shown_percent};
     default:begin end
    endcase
   end
   15:begin
    if(meta!=last_meta || live_keys!=last_keys || live_gain!=last_gain)begin
     job<=0;x0<=0;x1<=319;y0<=0;y1<=239;state<=5;
    end
   end
   16:begin
      job<=6;activity_index<=changed;x0<=112+changed[4:0]*6;x1<=117+changed[4:0]*6;y0<=40+changed[6:5]*40;y1<=79+changed[6:5]*40;state<=5;
   end
   default:state<=0;
  endcase
 end
endmodule
