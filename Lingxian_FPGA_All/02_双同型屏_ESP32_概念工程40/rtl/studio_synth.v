`timescale 1ns/1ps
// 32 shared melodic voices: eight reserved slots per track. Track identity and
// instrument are retained across release tails; no 4x duplication of 32 voices.
module studio_synth(input wire clk,rst_n,tick,input wire [95:0] keys,
 input wire [7:0] instruments,input wire [31:0] gains,input wire [15:0] drum_fire,
 output reg signed [15:0] sample,output wire [31:0] active,
 input wire [3:0] glide,input wire [31:0] vibrato_depth,input wire test_mode);
 reg [31:0] gates,triggers,work_gates,work_triggers,old_gates,guitar_owner;
 reg [159:0] owners,work_owners;
 reg [95:0] snapshot,previous;
 reg [7:0] snapshot_inst,previous_inst;reg [3:0] legato;reg test_started,previous_test;
 reg [2:0] state;reg [4:0] cursor;reg [1:0] track;reg [7:0] candidates;
 wire [7:0] group_gates=work_gates[track*8+:8],group_active=active[track*8+:8];
 function [2:0] first;input [7:0] b;begin
  if(b[0])first=0;else if(b[1])first=1;else if(b[2])first=2;else if(b[3])first=3;
  else if(b[4])first=4;else if(b[5])first=5;else if(b[6])first=6;else first=7;
 end endfunction
 wire [4:0] chosen={track,first(candidates)};
 integer i;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  gates<=0;triggers<=0;work_gates<=0;work_triggers<=0;owners<=0;work_owners<=0;
  snapshot<=0;previous<=0;snapshot_inst<=0;previous_inst<=0;state<=0;cursor<=0;track<=0;legato<=0;test_started<=0;previous_test<=0;
 end else if(test_mode)begin
  previous_test<=1;
  if(tick)begin
   gates<=32'hffffffff;triggers<=test_started?0:32'hffffffff;test_started<=1;
   owners<=0;
  end
 end else if(previous_test)begin
  previous_test<=0;test_started<=0;gates<=0;triggers<=0;work_gates<=0;work_triggers<=0;
  previous<=0;snapshot<=0;state<=0;legato<=0;
 end else if(tick)begin
  for(i=0;i<4;i=i+1)legato[i]<=glide[i]&&instruments[i*2+:2]!=3&&keys[i*24+:24]!=0&&
   (keys[i*24+:24]&(keys[i*24+:24]-24'd1))==0&&
   work_gates[i*8+:8]!=0&&(work_gates[i*8+:8]&active[i*8+:8])!=0&&
   (work_gates[i*8+:8]&(work_gates[i*8+:8]-8'd1))==0&&
   instruments[i*2+:2]==previous_inst[i*2+:2];
  gates<=work_gates;triggers<=work_triggers;owners<=work_owners;work_triggers<=0;
  for(i=0;i<4;i=i+1)snapshot[i*24+:24]<=instruments[i*2+:2]==3?24'b0:keys[i*24+:24];
  snapshot_inst<=instruments;cursor<=0;track<=0;state<=1;
 end else case(state)
  1:begin
   if(!legato[cursor>>3]&&work_gates[cursor]&&(!snapshot[(cursor>>3)*24+work_owners[cursor*5+:5]]||
      snapshot_inst[(cursor>>3)*2+:2]!=previous_inst[(cursor>>3)*2+:2]))work_gates[cursor]<=0;
   if(cursor==31)begin cursor<=0;track<=0;state<=2;end else cursor<=cursor+1'b1;
  end
  2:begin
   if(legato[track]&&snapshot[track*24+cursor])begin
    for(i=0;i<8;i=i+1)if(work_gates[track*8+i])work_owners[(track*8+i)*5+:5]<=cursor;
   end
   if(!legato[track]&&snapshot[track*24+cursor]&&(!previous[track*24+cursor]||snapshot_inst[track*2+:2]!=previous_inst[track*2+:2]))begin
    candidates<=(~group_gates&~group_active)!=0?(~group_gates&~group_active):~group_gates;state<=3;
   end else if(cursor==23)begin
    cursor<=0;if(track==3)begin previous<=snapshot;previous_inst<=snapshot_inst;state<=0;end else track<=track+1'b1;
   end else cursor<=cursor+1'b1;
  end
  3:begin
   if(candidates!=0)begin work_gates[chosen]<=1;work_triggers[chosen]<=1;work_owners[chosen*5+:5]<=cursor;end
   if(cursor==23)begin
    cursor<=0;if(track==3)begin previous<=snapshot;previous_inst<=snapshot_inst;state<=0;end else begin track<=track+1'b1;state<=2;end
   end else begin cursor<=cursor+1'b1;state<=2;end
  end
  default:begin end
 endcase
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin old_gates<=0;guitar_owner<=0;end
 else if(tick)begin
  old_gates<=gates;
  for(integer v=0;v<32;v=v+1)if(gates[v]&&(!old_gates[v]||triggers[v]))guitar_owner[v]<=instruments[(v/8)*2+:2]==1;
 end
 function [6:0] mapped;input [4:0] k;input guitar;reg [6:0] b;begin
  if(!guitar)mapped=60+{2'b0,k};else begin
   case(k[4:2])0:b=40;1:b=45;2:b=50;3:b=55;4:b=59;default:b=64;endcase
   mapped=b+{5'b0,k[1:0]};
  end
 end endfunction
 reg [4:0] pitch_cursor;reg [31:0] pitch_steps[0:31];
 wire [31:0] pitch_result;
 note_phase_step lookup(test_mode?(7'd48+{2'b0,pitch_cursor}):mapped(owners[pitch_cursor*5+:5],guitar_owner[pitch_cursor]),pitch_result);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin pitch_cursor<=0;for(integer n=0;n<32;n=n+1)pitch_steps[n]<=0;end
 else begin pitch_steps[pitch_cursor]<=pitch_result;pitch_cursor<=pitch_cursor+1'b1;end
 reg [31:0] lfo_phase;wire signed [12:0] lfo_wave;
 sine_lut lfo_table(lfo_phase[31:24],lfo_wave);
 reg signed [8:0] lfo_q,lfo_depth[0:3];reg signed [17:0] lfo_product[0:3];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin lfo_phase<=0;lfo_q<=0;for(integer j=0;j<4;j=j+1)begin lfo_depth[j]<=0;lfo_product[j]<=0;end end
 else begin
  if(tick)lfo_phase<=lfo_phase+32'd439805;
  lfo_q<=lfo_wave[12:4];
  for(integer j=0;j<4;j=j+1)begin lfo_product[j]<=lfo_q*$signed({1'b0,vibrato_depth[j*8+:8]});lfo_depth[j]<=lfo_product[j]>>>8;end
 end
 wire signed [15:0] voices[0:31];wire signed [15:0] drums[0:3];
 genvar g;
 generate for(g=0;g<32;g=g+1)begin:VOICE
  wire [1:0] tone=test_mode?2'd3:instruments[(g/8)*2+:2];
  voice_ex unit(clk,rst_n,tick,gates[g],triggers[g],pitch_steps[g],tone,test_mode?2'd3:tone==2?2'd3:tone==1?2'd1:2'd0,
   test_mode?1'b0:glide[g/8],test_mode?1'b0:(vibrato_depth[(g/8)*8+:8]!=0),test_mode?9'sd0:lfo_depth[g/8],voices[g],active[g]);
 end
 for(g=0;g<4;g=g+1)begin:DRUM
  studio_drums #(.SEED(32'h1aceb00c+g*32'h17231)) unit(clk,rst_n,tick,drum_fire[g*4+:4],drums[g]);
 end endgenerate
 reg signed [16:0] sum1[0:15];reg signed [17:0] sum2[0:7];reg signed [18:0] sum3[0:3];
 reg signed [19:0] group_sum[0:3];reg [7:0] gain_q[0:3];reg signed [28:0] product[0:3];
 reg signed [20:0] sum4[0:1];reg signed [21:0] sum5;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  for(i=0;i<16;i=i+1)sum1[i]<=0;for(i=0;i<8;i=i+1)sum2[i]<=0;
  for(i=0;i<4;i=i+1)begin sum3[i]<=0;group_sum[i]<=0;gain_q[i]<=0;product[i]<=0;end
  sum4[0]<=0;sum4[1]<=0;sum5<=0;sample<=0;
 end else begin
  for(i=0;i<16;i=i+1)sum1[i]<=$signed(voices[2*i])+$signed(voices[2*i+1]);
  for(i=0;i<8;i=i+1)sum2[i]<=$signed(sum1[2*i])+$signed(sum1[2*i+1]);
  for(i=0;i<4;i=i+1)begin
   sum3[i]<=$signed(sum2[2*i])+$signed(sum2[2*i+1]);
   group_sum[i]<=$signed(sum3[i])+$signed(drums[i]);gain_q[i]<=gains[i*8+:8];
   product[i]<=group_sum[i]*$signed({1'b0,gain_q[i]});
  end
  sum4[0]<=(product[0]>>>8)+(product[1]>>>8);sum4[1]<=(product[2]>>>8)+(product[3]>>>8);sum5<=sum4[0]+sum4[1];
  if((sum5>>>1)>32767)sample<=32767;else if((sum5>>>1)<-32768)sample<=-32768;else sample<=sum5>>>1;
 end
endmodule
