`timescale 1ns/1ps
// Percussion v2 at the existing 48,828.125Hz audio rate. Independent body,
// transient and band-limited noise layers; no sample files or external codec.
module studio_drums #(parameter SEED=32'h1aceb00c)(input wire clk,rst_n,tick,
 input wire [3:0] fire,output reg signed [15:0] sample);
 reg [3:0] pending;
 reg [31:0] noise,kick_phase,snare_phase,kick_step;
 reg [31:0] metal0,metal1,metal2,metal3,metal4,metal5;
 reg [15:0] kick_env,kick_attack,snare_env,snare_body,hat_env,clap_env;
 reg [10:0] clap_age;reg clap_running;
 reg signed [15:0] noise_low,noise_mid,metal_low;
 wire [3:0] hit=pending|fire;
 wire signed [15:0] white=$signed(noise[31:16])>>>4;
 wire signed [16:0] high_noise=$signed(white)-$signed(noise_low);
 wire signed [16:0] band_noise=$signed(noise_mid)-$signed(noise_low);
 wire metallic=(metal0[31]^metal1[31])^(metal2[31]&metal3[31])^(metal4[31]&metal5[31]);
 wire signed [15:0] metal_wave=metallic?16'sd1500:-16'sd1500;
 wire signed [16:0] metal_high=$signed(metal_wave)-$signed(metal_low);
 wire signed [12:0] kick_sine,snare_sine;
 sine_lut kick_osc(kick_phase[31:24],kick_sine);
 sine_lut snare_osc(snare_phase[31:24],snare_sine);
 wire signed [15:0] kick_body_wave={{3{kick_sine[12]}},kick_sine};
 wire signed [15:0] snare_body_wave={{3{snare_sine[12]}},snare_sine};
 wire signed [15:0] snare_noise_wave=($signed(high_noise)>>>1)+($signed(band_noise)>>>1);
 wire signed [15:0] hat_wave=($signed(metal_high)>>>1)+($signed(high_noise)>>>2);
 wire signed [15:0] clap_wave=($signed(high_noise)>>>1)+$signed(band_noise);
 reg signed [32:0] a0,a1,b0,b1,c0,d0;
 reg signed [17:0] kick_mix,snare_mix,hat_mix,clap_mix;
 reg signed [18:0] pair0,pair1;reg signed [19:0] mix;
 always @(posedge clk)begin
  a0<=kick_body_wave*$signed({1'b0,kick_env});
  a1<=high_noise*$signed({1'b0,kick_attack});
  b0<=snare_body_wave*$signed({1'b0,snare_body});
  b1<=snare_noise_wave*$signed({1'b0,snare_env});
  c0<=hat_wave*$signed({1'b0,hat_env});d0<=clap_wave*$signed({1'b0,clap_env});
  kick_mix<=(a0>>>16)+(a1>>>18);snare_mix<=(b0>>>17)+(b1>>>16);
  hat_mix<=c0>>>17;clap_mix<=d0>>>16;
  pair0<=kick_mix+snare_mix;pair1<=hat_mix+clap_mix;mix<=pair0+pair1;
 end
 function [15:0] decay;input [15:0] value;input [3:0] shift;input [15:0] floor_step;reg [16:0] loss;begin
  loss={1'b0,(value>>shift)}+{1'b0,floor_step};decay={1'b0,value}>loss?value-loss:16'b0;
 end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  pending<=0;noise<=SEED;kick_phase<=0;snare_phase<=0;kick_step<=4398047;
  metal0<=0;metal1<=0;metal2<=0;metal3<=0;metal4<=0;metal5<=0;
  kick_env<=0;kick_attack<=0;snare_env<=0;snare_body<=0;hat_env<=0;clap_env<=0;
  noise_low<=0;noise_mid<=0;metal_low<=0;clap_age<=0;clap_running<=0;sample<=0;
 end else begin
  pending<=pending|fire;
  if(tick)begin
   pending<=0;noise<={noise[30:0],noise[31]^noise[21]^noise[1]^noise[0]};
   noise_low<=noise_low+(($signed(white)-$signed(noise_low))>>>4);
   noise_mid<=noise_mid+(($signed(white)-$signed(noise_mid))>>>1);
   metal_low<=metal_low+(($signed(metal_wave)-$signed(metal_low))>>>2);
   kick_phase<=kick_phase+kick_step;snare_phase<=snare_phase+32'd15832967;
   // Inharmonic metallic partials: 3.1,4.2,5.3,6.7,8.1,9.6kHz.
   metal0<=metal0+32'd272678883;metal1<=metal1+32'd369435907;metal2<=metal2+32'd466192930;
   metal3<=metal3+32'd589338496;metal4<=metal4+32'd712484062;metal5<=metal5+32'd844424930;
   if(hit[0])begin kick_env<=62000;kick_attack<=44000;kick_phase<=0;kick_step<=11434921;end
   else begin
    kick_env<=decay(kick_env,12,2);kick_attack<=decay(kick_attack,4,256);
    if(kick_step>4398047)kick_step<=kick_step-((kick_step-4398047)>>9)-1'b1;
   end
   if(hit[1])begin snare_env<=61000;snare_body<=56000;snare_phase<=0;end
   else begin snare_env<=decay(snare_env,12,4);snare_body<=decay(snare_body,10,12);end
   if(hit[2])hat_env<=52000;else hat_env<=decay(hat_env,9,6);
   if(hit[3])begin clap_env<=58000;clap_age<=0;clap_running<=1;end
   else begin
    if(clap_running)begin
     if(clap_age==1758)clap_running<=0;else clap_age<=clap_age+1'b1;
     if(clap_age==585||clap_age==1171)clap_env<=55000;
     else if(clap_age<1171)clap_env<=decay(clap_env,7,96);
     else clap_env<=decay(clap_env,11,4);
    end else clap_env<=decay(clap_env,11,4);
   end
   if(mix>32767)sample<=32767;else if(mix< -32768)sample<=-32768;else sample<=mix[15:0];
  end
 end
endmodule
