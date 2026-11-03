`timescale 1ns/1ps
// Profiles 0/1 are damped piano/guitar strings, 2/3 are sustaining pad/organ.
// Capture the profile at note-on so instrument changes do not alter old tails.
module envelope_ex(input wire clk,rst_n,tick,gate,trigger,input wire [1:0] preset,
 output reg [15:0] level,output wire active);
 reg [2:0] state;reg previous_gate;reg [1:0] profile;
 reg [15:0] attack,decay,sustain,release_step;
 wire [16:0] up={1'b0,level}+{1'b0,attack};
 assign active=state!=0;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin level<=0;state<=0;previous_gate<=0;profile<=0;attack<=4096;decay<=128;sustain<=0;release_step<=128;end
 else if(tick) begin
  previous_gate<=gate;
  if(gate && (!previous_gate || trigger)) begin
   state<=1;level<=0;profile<=preset;
   case(preset)
    1:begin attack<=4096;decay<=256;sustain<=0;release_step<=128;end
    2:begin attack<=64;decay<=32;sustain<=45000;release_step<=16;end
    3:begin attack<=8192;decay<=1024;sustain<=60000;release_step<=512;end
    default:begin attack<=4096;decay<=128;sustain<=0;release_step<=128;end
   endcase
  end else if(!gate && previous_gate) state<=4;
  else case(state)
   0:level<=0;
   1:if(up>=65535) begin level<=65535;state<=2;end else level<=up[15:0];
   2:if(profile<2)begin
      // Restore the exponential string loss used by the working 08 voices.
      // Piano rings longer than guitar; held keys do not become organ tones.
      if(level>1)level<=level-((level>>(profile==1?12:15))+16'd1);
      else begin level<=0;state<=0;end
     end else if({1'b0,level}<={1'b0,sustain}+{1'b0,decay}) begin level<=sustain;state<=3;end else level<=level-decay;
   3:level<=sustain;
   4:if(level<=release_step) begin level<=0;state<=0;end else level<=level-release_step;
   default:begin state<=0;level<=0;end
  endcase
 end
endmodule
