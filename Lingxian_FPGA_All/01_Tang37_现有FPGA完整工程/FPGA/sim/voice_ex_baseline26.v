`timescale 1ns/1ps
module voice_ex_baseline26 #(parameter PURE_SINE=0)(input wire clk,rst_n,tick,gate,trigger,
 input wire [31:0] target_step,input wire [1:0] timbre,envelope_preset,
 input wire glide,vibrato,input wire signed [8:0] lfo,
 output reg signed [15:0] sample,output wire active);
 reg [31:0] phase,step;reg [1:0] shape;reg previous_gate;
 wire [15:0] env;
 envelope_ex adsr(clk,rst_n,tick,gate,trigger,envelope_preset,env,active);
 reg signed [32:0] delta;
 always @(posedge clk) delta<=$signed({1'b0,target_step})-$signed({1'b0,step});
 wire signed [32:0] glide_delta=delta>>>7;
 // Shared 5Hz sine LFO. The actual engine LFO peaks near +/-128, so
 // shift 12 gives about +/-3.125% (roughly +/-half a semitone) at MAX.
 // Internal depth 128 is near version 25 MAX; depth 32 near version 24 MAX.
 reg signed [41:0] modulation;
 always @(posedge clk) modulation<=$signed({1'b0,step})*lfo;
 // Finish the signed shift before adding to the unsigned phase step.
 // Otherwise Verilog makes >>> logical in the enclosing unsigned sum,
 // turning negative vibrato into an extra 2^27 phase step (~1526 Hz).
 wire signed [32:0] vibrato_offset=modulation>>>12;
 wire signed [32:0] modulated_step=$signed({1'b0,step})+
  (vibrato?vibrato_offset:33'sd0);
 reg [31:0] increment;
 always @(posedge clk) increment<=modulated_step[31:0];
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin phase<=0;step<=0;shape<=0;previous_gate<=0;end
 else if(tick) begin
  previous_gate<=gate;
  if(gate && (!previous_gate || trigger)) shape<=timbre;
  if(!glide || !active || step==0) step<=target_step;
  else if(delta>0) step<=step+(glide_delta==0?1:glide_delta);
  else if(delta<0) step<=step+(glide_delta==-1?-1:glide_delta);
  if(!active && !gate) phase<=0;else phase<=phase+increment;
 end
 (* syn_keep=1 *) reg [31:0] phase_q;
 always @(posedge clk)phase_q<=phase;
 wire signed [12:0] fundamental,harmonic;
 sine_lut sin1(phase_q[31:24],fundamental),sin2(phase_q[30:23],harmonic);
 wire [11:0] fold=phase[31]?~phase[30:19]:phase[30:19];
 wire signed [12:0] triangle=$signed({1'b0,fold})-13'sd2048;
 wire signed [13:0] organ=$signed(fundamental)+($signed(harmonic)>>>1);
 // Piano has a softer second partial; the plucked guitar is brighter.
 wire signed [13:0] wave=PURE_SINE?$signed(fundamental):shape==0?($signed(fundamental)+($signed(harmonic)>>>2)):shape==1?organ:
  shape==2?(organ>>>1):(phase[31]?-14'sd1800:14'sd1800);
 reg signed [13:0] wave_q;reg [15:0] env_q;
 always @(posedge clk)begin wave_q<=wave;env_q<=env;end
 reg signed [30:0] product;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin product<=0;sample<=0;end
 else begin product<=wave_q*$signed({1'b0,env_q});sample<=product>>>16;end
endmodule
