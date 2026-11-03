`timescale 1ns/1ps
// Piano approximation: three partials with a fast-decaying bright transient.
// Guitar approximation: richer plucked spectrum, fast attack, no sustain.
// Both are live additive synthesis, not sampled recordings.
module instrument_voice(input wire clk,rst_n,tick,gate,trigger,instrument,
 input wire [31:0] step,output reg signed [15:0] sample,output wire active);
 reg [31:0] phase;reg [15:0] env,bright;reg shape,previous_gate;
 reg [2:0] state;
 assign active=state!=0;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin phase<=0;env<=0;bright<=0;shape<=0;state<=0;previous_gate<=0;end
 else if(tick) begin
  previous_gate<=gate;
  if(gate && (!previous_gate || trigger)) begin
   shape<=instrument;env<=0;bright<=65535;state<=1;phase<=0;
  end else begin
   if(active) phase<=phase+step;
   if(bright!=0) bright<=bright-((bright>>10)+1'b1);
   if(!gate && previous_gate) state<=3;
   else case(state)
    0:env<=0;
    1:if(env>=61439) begin env<=65535;state<=2;end else env<=env+4096;
    // Exponential loss sounds more like damped strings than a linear fade.
    2:if(env>1) env<=env-((env>>(shape?12:15))+1'b1);else begin env<=0;state<=0;end
    3:if(env>256) env<=env-256;else begin env<=0;state<=0;end
    default:state<=0;
   endcase
  end
 end
 wire signed [12:0] a,b,c,d;
 wire [31:0] p3=phase+(phase<<1),p5=phase+(phase<<2);
 sine_lut s1(phase[31:24],a),s2(phase[30:23],b),s3(p3[31:24],c),s5(p5[31:24],d);
 wire signed [15:0] harmonics=shape?($signed(b)>>>1)+($signed(c)>>>2)+($signed(d)>>>3):
  ($signed(b)>>>2)+($signed(c)>>>3);
 reg signed [32:0] transient;
 reg signed [16:0] wave;
 reg signed [33:0] product;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin transient<=0;wave<=0;product<=0;sample<=0;end
 else begin
  transient<=harmonics*$signed({1'b0,bright});
  wave<=$signed(a)+(transient>>>16);
  product<=wave*$signed({1'b0,env});sample<=product>>>16;
 end
endmodule
