`timescale 1ns/1ps
module touch_piano_top #(parameter STANDARD_I2S=0,TEST_MODE=0,SWAP_XY=1,INVERT_X=0,INVERT_Y=1,
 parameter AUTO_LOOP=0,AUTO_GAP_CYCLES=50000,
 parameter MIC_TICK_CYCLES=50000,MIC_CAL_MS=1000,MIC_HOLD_MS=45,
 parameter [6:0] TOUCH_ADDRESS=7'h38)(
 input wire sys_clk,rst_button_n,play_button_n,mode_button_n,
 inout wire CTP_SCL,CTP_SDA,output wire CTP_RST,
 output wire LCD_SCK,LCD_MOSI,LCD_RS,LCD_CS,LCD_RST,
 output wire HP_BCK,HP_WS,HP_DIN,PA_EN,
 input wire MIC_DO,
 input wire HOST_RX,output wire HOST_TX,
    output wire [7:0] LED_N,
    output wire touch_healthy,output wire [3:0] voice_active);
 reg [2:0] reset_sync = 3'b000;
 always @(posedge sys_clk or negedge rst_button_n)
 if(!rst_button_n) reset_sync<=0;else reset_sync<={reset_sync[1:0],1'b1};
 wire rst_n=reset_sync[2];
 // Hold touch controller reset for 20ms, wait a further 120ms before I2C.
 reg [23:0] boot;
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n) boot<=0;else if(boot<7000000) boot<=boot+1;
 assign CTP_RST=rst_n && boot>=1000000;
 wire touch_run=rst_n && boot>=7000000;
 wire chord_down,timbre_down,unused0,unused1;
 button_debounce cb(.clk(sys_clk),.rst_n(rst_n),.button_n(play_button_n),.pressed(chord_down));
 button_debounce tb(.clk(sys_clk),.rst_n(rst_n),.button_n(mode_button_n),.pressed(timbre_down));
 wire frame;wire [1:0] count;wire [11:0] x0,y0,x1,y1;wire [15:0] errors;
 ft6x36_reader #(.ADDRESS(TOUCH_ADDRESS)) reader(sys_clk,touch_run,CTP_SCL,CTP_SDA,
  frame,touch_healthy,count,x0,y0,x1,y1,errors);
 wire [23:0] keys;wire [7:0] gain;
 touch_controls #(.SWAP_XY(SWAP_XY),.INVERT_X(INVERT_X),.INVERT_Y(INVERT_Y)) controls(
  sys_clk,rst_n,frame,touch_healthy,chord_down,count,x0,y0,x1,y1,keys,gain);
 wire ready;
 wire [23:0] remote_keys;wire [7:0] remote_gain;wire [1:0] remote_inst;wire remote_online,remote_valid;
 wire [15:0] remote_errors;
 reg [1:0] instrument;
 reg auto_run;
 localparam AUTO_GAP_WIDTH=AUTO_GAP_CYCLES>1?$clog2(AUTO_GAP_CYCLES+1):1;
 reg [AUTO_GAP_WIDTH-1:0] auto_delay;
 wire score_commit,score_done;wire [23:0] score_keys;
 wire play_active=auto_run && instrument==0;
 reg touch_held;
 wire [11:0] local_x=y0,local_y=239-x0;
 wire local_bounds=x0<240 && y0<320;
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n) begin instrument<=0;touch_held<=0;end
 else if(score_commit)begin instrument<=0;touch_held<=0;end
 else if(frame && touch_healthy) begin
  touch_held<=count!=0 && local_bounds;
  if(count!=0 && !touch_held && local_bounds && local_y>=48 && local_y<208)
   instrument<=local_x<108?2'd0:(local_x<212?2'd1:2'd2);
 end
 wire cfg_valid;wire [7:0] cfg_command,cfg_token;wire [31:0] cfg_data;wire cfg_loaded;
 smart_uart_rx receiver(sys_clk,rst_n,HOST_RX,remote_keys,remote_gain,remote_inst,
  remote_online,remote_valid,remote_errors,cfg_valid,cfg_command,cfg_data);
 smart_uart_tx sender(sys_clk,rst_n,instrument,HOST_TX,cfg_token,cfg_loaded);
 wire mic_permission,mic_ready;
 tang_mic_gate #(.TICK_CYCLES(MIC_TICK_CYCLES),.CAL_MS(MIC_CAL_MS),.HOLD_MS(MIC_HOLD_MS)) microphone(
  .clk(sys_clk),.rst_n(rst_n),.mic_do(MIC_DO),.ready(mic_ready),.sound(mic_permission));
 wire [23:0] remote_request=(remote_online && remote_inst==instrument)?remote_keys:24'b0;
 wire [23:0] remote_play=(instrument==2 && !mic_permission)?24'b0:remote_request;
 // ORGAN chord must not bypass the microphone plus held-key gate.
 wire chord_allowed=chord_down && (instrument!=2 || remote_play!=0);
 wire [23:0] manual_keys=remote_play | (chord_allowed?24'h001091:24'b0);
 wire [23:0] all_keys=((auto_run || auto_delay!=0) && instrument==0)?score_keys:manual_keys;
 // Keep expression on the release tail: a valid zero-key snapshot is still
 // the same performer, and must not revert to the local screen's gain.
 wire [7:0] effective_gain=(remote_online && remote_inst==instrument)?remote_gain:gain;

 ili9341_piano display(sys_clk,rst_n,keys,gain,instrument,touch_healthy,
  LCD_SCK,LCD_MOSI,LCD_RS,LCD_CS,LCD_RST,ready,{(guide_on||auto_run||auto_delay!=0),effect_on,(vibrato_depth!=0),glide_on},vibrato_depth);
 wire sample_tick;wire signed [15:0] sample,fx_left,fx_right;
 wire [31:0] active32;
 wire signed [15:0] chorus_sample;
 wire matched;
 smart_guide guide(sys_clk,rst_n,(guide_on||auto_run)&&!instrument,manual_keys,active32,LED_N,matched,
  cfg_valid,cfg_command,cfg_data,cfg_token,cfg_loaded,play_active,score_keys,score_commit,score_done);
 chorus_fx chorus(sys_clk,rst_n,sample_tick,TEST_MODE?1'b0:effect_on,sample,chorus_sample);
 wire [1:0] preset=instrument==2?2'd3:(instrument==1?2'd1:2'd0);
 poly32_engine #(.TEST_MODE(TEST_MODE)) engine(sys_clk,rst_n,sample_tick,all_keys,
  instrument,TEST_MODE?2'd3:preset,play_active?1'b0:glide_on,play_active?8'd0:vibrato_depth,7'd60,sample,active32);
 assign voice_active=active32[3:0];
 reg effect_on,glide_on,guide_on,previous_mode;reg [7:0] vibrato_depth;
 wire player_control=cfg_valid && cfg_command==8'h44 && cfg_data[31:1]==0;
 wire [11:0] vibrato_position=local_x>=319?12'd159:(local_x<=160?12'd0:local_x-12'd160);
 function [7:0] vibrato_curve;input [7:0] position;reg [7:0] base;reg [3:0] fraction;begin
  fraction=position[3:0];
  case(position[7:4])
   0:base=0;1:base=26;2:base=51;3:base=77;4:base=102;
   5:base=128;6:base=153;7:base=179;8:base=204;9:base=232;
   default:base=255;
  endcase
  vibrato_curve=base+fraction+(fraction>>1)+(fraction>>3);
 end endfunction
 wire [7:0] vibrato_value=vibrato_curve(vibrato_position[7:0]);
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n)begin effect_on<=0;glide_on<=0;vibrato_depth<=0;guide_on<=0;auto_run<=0;auto_delay<=0;previous_mode<=0;end
 else begin
  previous_mode<=timbre_down;
  if(timbre_down&&!previous_mode)effect_on<=!effect_on;
  // Commit/start has a 1ms key-off interval so replay reliably retriggers.
  if(score_commit)begin auto_run<=0;auto_delay<=AUTO_GAP_CYCLES;guide_on<=0;end
  else if(player_control && (!cfg_data[0] || (instrument==0 && cfg_loaded)))begin
   auto_run<=0;guide_on<=0;auto_delay<=cfg_data[0]?AUTO_GAP_CYCLES:0;
  end else if(instrument!=0)begin auto_run<=0;auto_delay<=0;guide_on<=0;end
  else if(frame&&touch_healthy&&local_bounds&&count!=0&&!touch_held&&local_y<42)begin
   if(auto_run || auto_delay!=0)begin auto_run<=0;auto_delay<=0;guide_on<=0;end
   else guide_on<=!guide_on; // Local title preserves the original manual LED guide.
  end else if(auto_delay!=0)begin
   if(auto_delay>1)auto_delay<=auto_delay-1'b1;
   else if(mic_ready)begin auto_delay<=0;auto_run<=1;end
  end else if(auto_run && score_done && !AUTO_LOOP)begin auto_run<=0;guide_on<=0;end
  if(frame&&touch_healthy&&local_bounds&&count!=0&&local_y>=210)begin
   if(local_x<160&&!touch_held)glide_on<=!glide_on;
   else if(local_x>=160)vibrato_depth<=vibrato_value;
  end
 end
 // 16384 samples at 48828.125 Hz = 335.54432 ms: a distinct repeat for
 // auditioning KEY0. Spectrum mode retains the original bypass configuration.
 audio_fx #(.ADDRESS_BITS(TEST_MODE?12:14)) effects(sys_clk,rst_n,sample_tick,chorus_sample,TEST_MODE?8'd192:effective_gain,
  1'b0,TEST_MODE?1'b0:effect_on,TEST_MODE?1'b0:effect_on,fx_left,fx_right);
 generate if(STANDARD_I2S) begin
  i2s_tx dac(sys_clk,rst_n,fx_left,fx_right,sample_tick,HP_BCK,HP_WS,HP_DIN);
 end else begin
  pt8211_tx dac(sys_clk,rst_n,fx_left,fx_right,sample_tick,HP_BCK,HP_WS,HP_DIN);
 end endgenerate
 assign PA_EN=!rst_n;
endmodule
