`timescale 1ns/1ps
// Uses current 27 three-instrument RTL, including chorus bypass and the actual
// PT8211 serial pins. It excludes touch acquisition, STM32 and analog settling.
module tb_latency_dac27;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,rx=1,armed=0;
 wire [23:0] keys;wire [7:0] gain;wire [1:0] instrument;wire online,valid;
 wire [15:0] errors;wire [31:0] active;
 wire signed [15:0] pcm,chorus,left,right;
 wire tick,bck,ws,din;
 link_uart_rx receiver(clk,rst,rx,keys,gain,instrument,online,valid,errors);
 poly32_engine engine(clk,rst,tick,keys,instrument,instrument==2?2'd3:(instrument==1?2'd1:2'd0),
   1'b0,8'd0,7'd60,pcm,active);
 chorus_fx chorus_stage(clk,rst,tick,1'b0,pcm,chorus);
 audio_fx #(.ADDRESS_BITS(14)) effects(clk,rst,tick,chorus,gain,1'b0,1'b0,1'b0,left,right);
 pt8211_tx dac(clk,rst,left,right,tick,bck,ws,din);

 time frame_start,pcm_time,right_time,left_time,right_16_time,left_16_time;
 reg pcm_seen=0,right_seen=0,left_seen=0,right_16_seen=0,left_16_seen=0;
 reg [15:0] shift;integer bits=0;reg previous_ws=1;
 reg signed [15:0] decoded;
 always @(posedge clk)if(rst&&armed&&!pcm_seen&&left!=0)begin
  pcm_seen=1;pcm_time=$time-frame_start;
 end
 // DIN is sampled on BCK rising edges, just as the board DAC does.
 // WS=0 right and WS=1 left; 16 complete bits per sample with no I2S delay.
 always @(posedge bck or negedge rst)begin
  if(!rst)begin bits=0;shift=0;previous_ws=1;end
  else begin
   if(ws!=previous_ws)begin bits=0;shift=0;previous_ws=ws;end
   shift={shift[14:0],din};bits=bits+1;
   if(bits==16)begin
    decoded=$signed(shift);bits=0;
    if(armed&&decoded!=0)begin
     if(!ws&&!right_seen)begin right_seen=1;right_time=$time-frame_start;end
     if(ws&&!left_seen)begin left_seen=1;left_time=$time-frame_start;end
    end
    if(armed&&(decoded>=16||decoded<=-16))begin
     if(!ws&&!right_16_seen)begin right_16_seen=1;right_16_time=$time-frame_start;end
     if(ws&&!left_16_seen)begin left_16_seen=1;left_16_time=$time-frame_start;end
    end
   end
  end
 end
 task send_byte(input [7:0] value);integer i;begin
  @(negedge clk);rx=0;repeat(434)@(negedge clk);
  for(i=0;i<8;i=i+1)begin rx=value[i];repeat(434)@(negedge clk);end
  rx=1;repeat(434)@(negedge clk);
 end endtask
 integer fd,timeout;
 task check_case(input integer id,input integer phase,input [23:0] note_keys,
                 input [7:0] ins,input [7:0] volume);reg [7:0] checksum;begin
  armed=0;rst=0;rx=1;repeat(8)@(negedge clk);
  pcm_seen=0;right_seen=0;left_seen=0;right_16_seen=0;left_16_seen=0;
  pcm_time=0;right_time=0;left_time=0;right_16_time=0;left_16_time=0;
  rst=1;repeat(1100+phase)@(negedge clk);
  // send_byte starts on the following falling edge; timestamp exactly that edge.
  @(negedge clk);frame_start=$time+20;armed=1;
  checksum=8'ha5^8'h5a^ins^note_keys[7:0]^note_keys[15:8]^note_keys[23:16]^volume;
  send_byte(8'ha5);send_byte(8'h5a);send_byte(ins);
  send_byte(note_keys[7:0]);send_byte(note_keys[15:8]);send_byte(note_keys[23:16]);
  send_byte(volume);send_byte(checksum);
  timeout=0;
  while((!left_16_seen||!right_16_seen)&&timeout<100000)begin @(negedge clk);timeout=timeout+1;end
  if(!pcm_seen||!left_seen||!right_seen||!left_16_seen||!right_16_seen)
   $fatal(1,"no serial DAC audio: case=%0d",id);
  if(errors!=0||!online||active==0)$fatal(1,"control/audio path failed");
  if(pcm_time>=left_time||right_time>left_time||left_time>=10000000||right_16_time>=10000000)
   $fatal(1,"bad pin latency ordering or >10ms: case=%0d pcm=%0t R=%0t L=%0t",id,pcm_time,right_time,left_time);
  $fdisplay(fd,"%0d,%0d,%0d,%0d,%h,%0d,%0d,%0d,%0d,%0d",id,phase,ins,volume,note_keys,
            pcm_time,right_time,left_time,right_16_time,left_16_time);
  $display("PASS case %0d: PCM=%0d ns right-word=%0d ns left-word=%0d ns |word|>=16=%0d ns",
            id,pcm_time,right_time,left_time,left_16_time);
 end endtask
 initial begin
  fd=$fopen("latency_dac27.csv","w");
  $fdisplay(fd,"case,phase_cycles,instrument,gain,keys_hex,pcm_ns,right_word_ns,left_word_ns,right_word_16_ns,left_word_16_ns");
  check_case(0,0,24'h000001,0,180);
  check_case(1,137,24'h000001,0,180);
  check_case(2,509,24'h000200,0,100);
  check_case(3,1007,24'h800000,0,230);
  check_case(4,0,24'h000001,1,210);
  check_case(5,137,24'h000001,1,100);
  check_case(6,509,24'h800000,1,230);
  check_case(7,1007,24'h001091,0,180);
  check_case(8,0,24'h000001,2,180);
  check_case(9,137,24'h000001,2,100);
  check_case(10,509,24'h800000,2,230);
  check_case(11,1007,24'h001091,2,180);
  $fclose(fd);
  $display("PASS twelve UART phase/note/gain cases including organ to complete PT8211 left/right words; not physical touch/analog latency");
  $finish;
 end
 initial begin #100000000;$fatal(1,"latency suite timeout");end
endmodule
