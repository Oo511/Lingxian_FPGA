`timescale 1ns/1ps
// 32 parallel phase accumulators, envelopes and waveform datapaths.
// Live interface has 24 chromatic keys. Test mode exercises ALL 32 voices.
module poly32_engine #(parameter TEST_MODE=0)(input wire clk,rst_n,tick,
 input wire [23:0] keys,input wire [1:0] timbre,envelope_preset,
 input wire glide,input wire [7:0] vibrato_depth,input wire [6:0] base_note,
 output reg signed [15:0] sample,output wire [31:0] active);
 reg [31:0] gates,triggers;reg [159:0] owners;
 reg [23:0] previous_keys,snapshot;reg [31:0] work_gates,work_triggers;
 reg [159:0] work_owners;integer v,slot;
 reg [2:0] state;reg [5:0] cursor;reg legato;
 reg [31:0] candidates;
 function [4:0] first_slot;input [31:0] bits;reg [31:0] b;reg [4:0] n;begin
 b=bits;n=0;
 if(b[15:0]==0)begin n=n+16;b=b>>16;end
 if(b[7:0]==0)begin n=n+8;b=b>>8;end
 if(b[3:0]==0)begin n=n+4;b=b>>4;end
 if(b[1:0]==0)begin n=n+2;b=b>>2;end
 if(!b[0])n=n+1;
 first_slot=n;end endfunction
 wire [4:0] chosen=first_slot(candidates);
 reg test_started;
 reg [31:0] guitar_owner,old_gates;
 integer iv;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin guitar_owner<=0;old_gates<=0;end
 else if(tick)begin
  old_gates<=gates;
  for(iv=0;iv<32;iv=iv+1)if(gates[iv]&&(!old_gates[iv]||triggers[iv]))guitar_owner[iv]<=timbre[0];
 end
 function [6:0] mapped;input [4:0] k;input guitar;reg [6:0] b;begin
 if(!guitar)mapped=7'd60+{2'b0,k};else begin
 case(k[4:2])0:b=40;1:b=45;2:b=50;3:b=55;4:b=59;default:b=64;endcase
 mapped=b+{5'b0,k[1:0]};end end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin gates<=0;triggers<=0;owners<=0;previous_keys<=0;test_started<=0;
  work_gates<=0;work_triggers<=0;work_owners<=0;snapshot<=0;state<=0;cursor<=0;legato<=0;end
 else if(TEST_MODE) begin
  if(tick) begin
   gates<=32'hffffffff;triggers<=test_started?0:32'hffffffff;test_started<=1;
   for(v=0;v<32;v=v+1) owners[v*5+:5]<=v;
  end
 end else if(tick) begin
  // A complete allocation sweep uses 80 system clocks, far below the 1024
  // clocks per sample. Commit atomically at the next audio sample boundary.
  gates<=work_gates;triggers<=work_triggers;owners<=work_owners;
  work_triggers<=0;snapshot<=keys;cursor<=0;state<=1;
  legato<=glide && keys!=0 && (keys & (keys-24'd1))==0 &&
   work_gates!=0 && (work_gates & active)!=0 && (work_gates & (work_gates-32'd1))==0;
 end else if(state==1) begin
  if(!legato && work_gates[cursor] && !snapshot[work_owners[cursor*5+:5]]) work_gates[cursor]<=0;
  if(cursor==31) begin cursor<=0;state<=2;end else cursor<=cursor+1'b1;
 end else if(state==2) begin
  if(legato && snapshot[cursor]) begin
   for(v=0;v<32;v=v+1) if(work_gates[v]) work_owners[v*5+:5]<=cursor[4:0];
  end else if(snapshot[cursor] && !previous_keys[cursor]) begin
   candidates<=(~work_gates & ~active)!=0?(~work_gates & ~active):~work_gates;
   state<=3;

  end
  if(!(snapshot[cursor] && !previous_keys[cursor] && !legato))begin
   if(cursor==23) begin previous_keys<=snapshot;state<=0;end else cursor<=cursor+1'b1;
  end
 end else if(state==3)begin
  if(candidates!=0)begin work_gates[chosen]<=1;work_triggers[chosen]<=1;work_owners[chosen*5+:5]<=cursor[4:0];end
  if(cursor==23)begin previous_keys<=snapshot;state<=0;end
  else begin cursor<=cursor+1'b1;state<=2;end
 end
 reg [31:0] lfo_phase;wire signed [12:0] lfo_wave;
 reg signed [8:0] lfo_q,lfo_depth_q;
 always @(posedge clk) lfo_q<=lfo_wave[12:4];
 wire signed [16:0] lfo_scaled=$signed(lfo_q)*$signed({1'b0,vibrato_depth});
 always @(posedge clk or negedge rst_n)
 if(!rst_n)lfo_depth_q<=0;else lfo_depth_q<=lfo_scaled>>>8;
 always @(posedge clk or negedge rst_n) if(!rst_n) lfo_phase<=0;else if(tick) lfo_phase<=lfo_phase+32'd439805;
 sine_lut lf(lfo_phase[31:24],lfo_wave);
 wire signed [15:0] voices[0:31];
 // One MIDI lookup fills 32 independent frequency registers in 0.64us.
 // This is control-parameter scheduling; all audio oscillators remain parallel.
 reg [4:0] pitch_cursor;reg [31:0] pitch_steps[0:31];
 wire [6:0] pitch_note=TEST_MODE?(7'd48+{2'b0,pitch_cursor}):
  mapped(owners[pitch_cursor*5+:5],guitar_owner[pitch_cursor]);
 wire [31:0] pitch_result;note_phase_step pitch(pitch_note,pitch_result);
 integer p;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin pitch_cursor<=0;for(p=0;p<32;p=p+1) pitch_steps[p]<=0;end
 else begin pitch_steps[pitch_cursor]<=pitch_result;pitch_cursor<=pitch_cursor+1'b1;end
 genvar g;generate for(g=0;g<32;g=g+1) begin:VOICE
  // Spectrum mode locks every control, not just the note map, and emits one
  // fundamental per independent voice so instrument harmonics do not mask peaks.
  voice_ex #(.PURE_SINE(TEST_MODE)) unit(clk,rst_n,tick,gates[g],triggers[g],pitch_steps[g],
   TEST_MODE?2'd0:timbre,TEST_MODE?2'd3:envelope_preset,
   TEST_MODE?1'b0:glide,TEST_MODE?1'b0:(vibrato_depth!=0),lfo_depth_q,voices[g],active[g]);
 end endgenerate
 // Registered balanced summing tree: 5 pipeline stages, no long 32-way chain.
 reg signed [16:0] sum1[0:15];reg signed [17:0] sum2[0:7];
 reg signed [18:0] sum3[0:3];reg signed [19:0] sum4[0:1];reg signed [20:0] sum5;
 integer i;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin
  for(i=0;i<16;i=i+1) sum1[i]<=0;
  for(i=0;i<8;i=i+1) sum2[i]<=0;
  for(i=0;i<4;i=i+1) sum3[i]<=0;
  for(i=0;i<2;i=i+1) sum4[i]<=0;
  sum5<=0;sample<=0;
 end else begin
  for(i=0;i<16;i=i+1) sum1[i]<=$signed(voices[i*2])+$signed(voices[i*2+1]);
  for(i=0;i<8;i=i+1) sum2[i]<=$signed(sum1[i*2])+$signed(sum1[i*2+1]);
  for(i=0;i<4;i=i+1) sum3[i]<=$signed(sum2[i*2])+$signed(sum2[i*2+1]);
  for(i=0;i<2;i=i+1) sum4[i]<=$signed(sum3[i*2])+$signed(sum3[i*2+1]);
  sum5<=$signed(sum4[0])+$signed(sum4[1]);
  if((sum5>>>1)>32767) sample<=16'sh7fff;
  else if((sum5>>>1)<-32768) sample<=16'sh8000;
  else sample<=sum5>>>1;
 end
endmodule
