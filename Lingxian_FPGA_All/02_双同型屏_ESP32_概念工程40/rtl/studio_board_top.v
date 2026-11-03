`timescale 1ns/1ps
// Tang is the workstation/recorder/synth. STM32 supplies live touch keys only.
module studio_board_top #(
 parameter TOUCH_BOOT_CYCLES=7000000,
 parameter TOUCH_RESET_CYCLES=1000000,
 parameter TOUCH_RETRY_CYCLES=12500000
)(input wire sys_clk,rst_button_n,play_button_n,mode_button_n,
 input wire ENCODER_CLK,ENCODER_DT,ENCODER_SW_N,
 input wire MIC_DO,HOST_RX,output wire HOST_TX,output wire [7:0] LED_N,
 inout wire CTP_SCL,CTP_SDA,output wire CTP_RST,
 output wire LCD_SCK,LCD_MOSI,LCD_RS,LCD_CS,LCD_RST,SD_CS,
 output wire HP_BCK,HP_WS,HP_DIN,PA_EN);
 reg [2:0] reset_sync=0;
 always @(posedge sys_clk or negedge rst_button_n)if(!rst_button_n)reset_sync<=0;else reset_sync<={reset_sync[1:0],1'b1};
 wire rst_n=reset_sync[2];reg [23:0] boot;
 wire frame,healthy;wire [1:0] count;wire [11:0] x0,y0,x1,y1;wire [15:0] touch_errors;
 reg [23:0] touch_bad_cycles;
 // Recover the touch controller and its I2C master together after a sustained
 // outage. A released master alone cannot free a slave stuck mid-transaction.
 // This never resets the recorder, voices, encoder, or LCD.
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n)begin boot<=0;touch_bad_cycles<=0;end
 else if(boot<TOUCH_BOOT_CYCLES)begin boot<=boot+1'b1;touch_bad_cycles<=0;end
 else if(healthy)touch_bad_cycles<=0;
 else if(touch_bad_cycles>=TOUCH_RETRY_CYCLES-1)begin boot<=0;touch_bad_cycles<=0;end
 else touch_bad_cycles<=touch_bad_cycles+1'b1;
 assign CTP_RST=rst_n&&boot>=TOUCH_RESET_CYCLES;assign SD_CS=1;assign PA_EN=!rst_n;
 ft6x36_reader touch(sys_clk,rst_n&&boot>=TOUCH_BOOT_CYCLES,CTP_SCL,CTP_SDA,frame,healthy,count,x0,y0,x1,y1,touch_errors);
 wire chord_down,fx_down;
 button_debounce cb(sys_clk,rst_n,play_button_n,chord_down);button_debounce fb(sys_clk,rst_n,mode_button_n,fx_down);
 reg picker,touch_held,ui_initialized;reg [3:0] ui_command;reg [1:0] ui_track,ui_instrument;
 reg [3:0] track_glide;reg [31:0] track_vibrato;reg guide_live,test_mode;
 reg old_fx;reg [2:0] fx_mode;wire fx=fx_mode!=0;
 always @(posedge sys_clk or negedge rst_n)if(!rst_n)begin old_fx<=0;fx_mode<=0;end else begin old_fx<=fx_down;if((fx_down&&!old_fx)||ui_command==10)fx_mode<=fx_mode==4?3'd0:fx_mode+1'b1;end
 wire [23:0] remote_keys;wire [7:0] remote_gain;wire [1:0] remote_inst;wire online,remote_valid;
 wire [15:0] uart_errors;wire cfg_valid;wire [7:0] cfg_command;wire [31:0] cfg_data;
 smart_uart_rx receiver(sys_clk,rst_n,HOST_RX,remote_keys,remote_gain,remote_inst,online,remote_valid,uart_errors,cfg_valid,cfg_command,cfg_data);
 wire [7:0] cfg_token;wire cfg_loaded;
 wire [1:0] selected;wire [7:0] track_instruments,bpm;wire [3:0] filled,muted;wire [127:0] activity;
 wire playing,recording,armed;wire [2:0] count_in,tempo;wire [8:0] position;
 wire [95:0] loop_keys;wire [31:0] loop_gains;wire [15:0] loop_drums;wire click_event;
 reg score_run;reg [15:0] score_delay;
 wire song_mode=score_run||score_delay!=0;
 wire [1:0] instrument=(song_mode||test_mode)?2'd0:track_instruments[selected*2+:2];
 smart_uart_tx sender(sys_clk,rst_n,instrument,HOST_TX,cfg_token,cfg_loaded);
 wire mic_ready,mic_permission;
 tang_mic_gate microphone(sys_clk,rst_n,MIC_DO,mic_ready,mic_permission);
 wire [23:0] raw_live=(online&&remote_inst==instrument)?remote_keys:24'b0;
 wire [23:0] gated_live=(instrument==2&&!mic_permission)?24'b0:raw_live;
 wire chord_allowed=chord_down&&instrument!=3&&(instrument!=2||gated_live!=0);
 wire [23:0] live_keys=gated_live|(chord_allowed?24'h001091:24'b0);
 wire [7:0] live_gain=online?remote_gain:8'd200;
 wire screen_ready;wire score_start;
 wire [11:0] tx=y0,ty=239-x0;wire bounds=x0<240&&y0<320;
 wire [1:0] hit_track=ty<80?0:ty<120?1:ty<160?2:3;
 wire hit_card=(tx>=8&&tx<156||tx>=164&&tx<312)&&(ty>=48&&ty<116||ty>=128&&ty<196);
 wire [1:0] card={ty>=128,tx>=164};
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n)begin picker<=0;touch_held<=0;ui_initialized<=0;ui_command<=0;ui_track<=0;ui_instrument<=0;end
 else begin
  ui_command<=0;if(score_start)picker<=0;
  if(screen_ready)ui_initialized<=1;
  // A brief NACK must not turn one held finger into a second button press.
  // Re-arm only when the touch controller is actually being restarted.
  if(boot<TOUCH_BOOT_CYCLES)touch_held<=0;
  if(frame&&healthy)begin
   touch_held<=count!=0;
   // Only the first frame gates UI startup. Repainting a page must not make
   // control actions depend on the LCD completing hundreds of thousands of bytes.
   if(count!=0&&!touch_held&&bounds&&(ui_initialized||screen_ready))begin
    if(picker)begin
     if(ty>=208)begin
      if(tx<80)ui_command<=11;else if(tx<160)ui_command<=12;else if(tx<240)ui_command<=13;else ui_command<=14;
     end else if(ty<33&&tx<80)picker<=0;
     else if(hit_card)begin ui_command<=6;ui_instrument<=card;picker<=0;end
    end else begin
     if(ty>=208)begin
      if(tx<80)ui_command<=1;else if(tx<160)ui_command<=2;else if(tx<240)ui_command<=3;else ui_command<=4;
     end else if(ty>=40&&ty<200&&tx<108)begin
      ui_track<=hit_track;
      if(tx<84)begin ui_command<=5;picker<=1;end else ui_command<=9;
     end else if(ty<33&&tx>=204&&tx<226)ui_command<=10;
     else if(ty<33&&tx>=236&&tx<264)ui_command<=8;
     else if(ty<33&&tx>=276&&tx<304)ui_command<=7;
    end
   end
  end
 end
 wire score_control=cfg_valid&&cfg_command==8'h44&&cfg_data[31:1]==0;
 assign score_start=score_control&&cfg_data[0]&&cfg_loaded;
 wire score_stop=score_control&&!cfg_data[0];
 wire [3:0] workstation_command=(score_start||score_stop||ui_command==14)?4'd3:ui_command;
 studio_loop loop(sys_clk,rst_n,workstation_command,ui_track,ui_instrument,live_keys,live_gain,
  selected,track_instruments,filled,muted,activity,playing,recording,armed,count_in,position,tempo,bpm,loop_keys,loop_gains,loop_drums,click_event);
 wire [23:0] score_keys;wire score_done,score_committed,matched;wire [7:0] song_leds;
 wire [31:0] voice_active;
 smart_guide guide(sys_clk,rst_n,(score_run||(guide_live&&instrument==0&&!test_mode)),live_keys,voice_active,song_leds,matched,cfg_valid,cfg_command,cfg_data,
  cfg_token,cfg_loaded,score_run,score_keys,score_committed,score_done);
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n)begin track_glide<=0;track_vibrato<=0;guide_live<=0;test_mode<=0;end
 else begin
  if(ui_command==11 && instrument!=3)track_glide[selected]<=!track_glide[selected];
  if(ui_command==12 && instrument!=3)case(track_vibrato[selected*8+:8])
   0:track_vibrato[selected*8+:8]<=32;32:track_vibrato[selected*8+:8]<=96;
   96:track_vibrato[selected*8+:8]<=192;192:track_vibrato[selected*8+:8]<=255;default:track_vibrato[selected*8+:8]<=0;
  endcase
  if(ui_command==13)begin guide_live<=!guide_live;test_mode<=0;end
  if(ui_command==14)begin test_mode<=!test_mode;guide_live<=0;end
  if(score_start || ui_command==1 || ui_command==2 || ui_command==3 || ui_command==5 || ui_command==6)test_mode<=0;
 end
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n)begin score_run<=0;score_delay<=0;end
 else if(score_start)begin score_run<=0;score_delay<=50000;end
 else if(score_stop||(ui_command!=0&&ui_command!=10))begin score_run<=0;score_delay<=0;end
 else if(score_delay!=0)begin
  if(score_delay>1)score_delay<=score_delay-1'b1;
  else if(mic_ready)begin score_delay<=0;score_run<=1;end
 end else if(score_done)score_run<=0;
 wire [95:0] synth_keys=song_mode?{72'b0,score_keys}:loop_keys;
 wire [7:0] synth_instruments=song_mode?8'b0:track_instruments;
 wire [31:0] synth_gains=test_mode?32'h60606060:song_mode?{24'b0,live_gain}:loop_gains;
 wire [15:0] synth_drums=(song_mode||test_mode)?16'b0:loop_drums;
 wire sample_tick;wire signed [15:0] dry,click_sample,chorus_sample,left,right,master_left,master_right;
 wire [6:0] master_percent;wire master_muted;wire [15:0] encoder_detents,encoder_invalid;wire [2:0] encoder_pins;
 encoder_volume volume_control(sys_clk,rst_n,ENCODER_CLK,ENCODER_DT,ENCODER_SW_N,master_percent,master_muted,encoder_detents,encoder_invalid,encoder_pins);
 studio_synth engine(sys_clk,rst_n,sample_tick,synth_keys,synth_instruments,synth_gains,synth_drums,dry,voice_active,song_mode?4'b0:track_glide,song_mode?32'b0:track_vibrato,test_mode);
 studio_click metronome(sys_clk,rst_n,sample_tick,click_event,click_sample);
 wire signed [16:0] with_click=$signed(dry)+(song_mode?17'sd0:$signed(click_sample));
 wire signed [15:0] mixed=with_click>32767?16'sd32767:with_click< -32768?-16'sd32768:with_click[15:0];
 chorus_fx chorus(sys_clk,rst_n,sample_tick,(fx_mode==3||fx_mode==4)&&!test_mode,mixed,chorus_sample);
 audio_fx #(.ADDRESS_BITS(14)) effects(sys_clk,rst_n,sample_tick,chorus_sample,8'd255,1'b0,(fx_mode==2||fx_mode==4)&&!test_mode,(fx_mode==1||fx_mode==4)&&!test_mode,left,right);
 master_volume master(sys_clk,rst_n,sample_tick,master_percent,master_muted,left,right,master_left,master_right);
 pt8211_tx dac(sys_clk,rst_n,master_left,master_right,sample_tick,HP_BCK,HP_WS,HP_DIN);
 wire [7:0] studio_leds=~{recording,armed,playing,(playing&&position[5:0]<8),filled};
 assign LED_N=(song_mode||(guide_live&&instrument==0&&!test_mode))?song_leds:test_mode?~voice_active[7:0]:studio_leds;
 wire [4:0] display_step=song_mode?guide.position[4:0]:position[8:4];
 studio_display display(sys_clk,rst_n,picker,selected,track_instruments,bpm,filled,muted,activity,display_step,
  playing||score_run,recording,armed,count_in,song_mode,fx,healthy,LCD_SCK,LCD_MOSI,LCD_RS,LCD_CS,LCD_RST,screen_ready,track_glide[selected],track_vibrato[selected*8+:8],guide_live,test_mode,fx_mode,master_percent,master_muted);
endmodule
