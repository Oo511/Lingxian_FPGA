`timescale 1ns/1ps
// True output-stage master: dry sound AND existing effect tails pass through it.
// Q8 coefficient: 0=exact silence, 256=bit-exact unity; 60%=154/256.
// Continuous registered products settle long before the next DAC frame latch.
// Smoothing changes one Q8 unit per audio sample (<=5.243ms full-range ramp).
module master_volume #(parameter [8:0] RESET_GAIN=0)(
 input wire clk,rst_n,tick,input wire [6:0] percent,input wire muted,
 input wire signed [15:0] in_left,in_right,
 output wire signed [15:0] out_left,out_right);
 function [8:0] percent_gain;input [6:0] p;begin case(p)
 7'd0:percent_gain=9'd0;
 7'd1:percent_gain=9'd3;
 7'd2:percent_gain=9'd5;
 7'd3:percent_gain=9'd8;
 7'd4:percent_gain=9'd10;
 7'd5:percent_gain=9'd13;
 7'd6:percent_gain=9'd15;
 7'd7:percent_gain=9'd18;
 7'd8:percent_gain=9'd20;
 7'd9:percent_gain=9'd23;
 7'd10:percent_gain=9'd26;
 7'd11:percent_gain=9'd28;
 7'd12:percent_gain=9'd31;
 7'd13:percent_gain=9'd33;
 7'd14:percent_gain=9'd36;
 7'd15:percent_gain=9'd38;
 7'd16:percent_gain=9'd41;
 7'd17:percent_gain=9'd44;
 7'd18:percent_gain=9'd46;
 7'd19:percent_gain=9'd49;
 7'd20:percent_gain=9'd51;
 7'd21:percent_gain=9'd54;
 7'd22:percent_gain=9'd56;
 7'd23:percent_gain=9'd59;
 7'd24:percent_gain=9'd61;
 7'd25:percent_gain=9'd64;
 7'd26:percent_gain=9'd67;
 7'd27:percent_gain=9'd69;
 7'd28:percent_gain=9'd72;
 7'd29:percent_gain=9'd74;
 7'd30:percent_gain=9'd77;
 7'd31:percent_gain=9'd79;
 7'd32:percent_gain=9'd82;
 7'd33:percent_gain=9'd84;
 7'd34:percent_gain=9'd87;
 7'd35:percent_gain=9'd90;
 7'd36:percent_gain=9'd92;
 7'd37:percent_gain=9'd95;
 7'd38:percent_gain=9'd97;
 7'd39:percent_gain=9'd100;
 7'd40:percent_gain=9'd102;
 7'd41:percent_gain=9'd105;
 7'd42:percent_gain=9'd108;
 7'd43:percent_gain=9'd110;
 7'd44:percent_gain=9'd113;
 7'd45:percent_gain=9'd115;
 7'd46:percent_gain=9'd118;
 7'd47:percent_gain=9'd120;
 7'd48:percent_gain=9'd123;
 7'd49:percent_gain=9'd125;
 7'd50:percent_gain=9'd128;
 7'd51:percent_gain=9'd131;
 7'd52:percent_gain=9'd133;
 7'd53:percent_gain=9'd136;
 7'd54:percent_gain=9'd138;
 7'd55:percent_gain=9'd141;
 7'd56:percent_gain=9'd143;
 7'd57:percent_gain=9'd146;
 7'd58:percent_gain=9'd148;
 7'd59:percent_gain=9'd151;
 7'd60:percent_gain=9'd154;
 7'd61:percent_gain=9'd156;
 7'd62:percent_gain=9'd159;
 7'd63:percent_gain=9'd161;
 7'd64:percent_gain=9'd164;
 7'd65:percent_gain=9'd166;
 7'd66:percent_gain=9'd169;
 7'd67:percent_gain=9'd172;
 7'd68:percent_gain=9'd174;
 7'd69:percent_gain=9'd177;
 7'd70:percent_gain=9'd179;
 7'd71:percent_gain=9'd182;
 7'd72:percent_gain=9'd184;
 7'd73:percent_gain=9'd187;
 7'd74:percent_gain=9'd189;
 7'd75:percent_gain=9'd192;
 7'd76:percent_gain=9'd195;
 7'd77:percent_gain=9'd197;
 7'd78:percent_gain=9'd200;
 7'd79:percent_gain=9'd202;
 7'd80:percent_gain=9'd205;
 7'd81:percent_gain=9'd207;
 7'd82:percent_gain=9'd210;
 7'd83:percent_gain=9'd212;
 7'd84:percent_gain=9'd215;
 7'd85:percent_gain=9'd218;
 7'd86:percent_gain=9'd220;
 7'd87:percent_gain=9'd223;
 7'd88:percent_gain=9'd225;
 7'd89:percent_gain=9'd228;
 7'd90:percent_gain=9'd230;
 7'd91:percent_gain=9'd233;
 7'd92:percent_gain=9'd236;
 7'd93:percent_gain=9'd238;
 7'd94:percent_gain=9'd241;
 7'd95:percent_gain=9'd243;
 7'd96:percent_gain=9'd246;
 7'd97:percent_gain=9'd248;
 7'd98:percent_gain=9'd251;
 7'd99:percent_gain=9'd253;
 7'd100:percent_gain=9'd256;
 default:percent_gain=9'd256;endcase end endfunction
 wire [8:0] target=muted?9'd0:percent_gain(percent);
 reg [8:0] smooth_gain;
 reg signed [25:0] left_product,right_product;
 reg signed [25:0] left_low,left_high,right_low,right_high;
 // Two-stage shift/add multiplier avoids placing another two DSP blocks at
 // the constrained DAC edge. The exact signed Q8 result is unchanged.
 function signed [25:0] partial_product;
 input signed [15:0] value;input [8:0] gain;input high_part;
 reg signed [25:0] x,total;integer bit_index;begin
  x={{10{value[15]}},value};total=0;
  for(bit_index=0;bit_index<9;bit_index=bit_index+1)
   if(gain[bit_index]&&((bit_index>=4)==high_part))total=total+(x<<<bit_index);
  partial_product=total;
 end endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin smooth_gain<=RESET_GAIN;left_product<=0;right_product<=0;left_low<=0;left_high<=0;right_low<=0;right_high<=0;end
 else begin
  if(tick)begin
   if(smooth_gain<target)smooth_gain<=smooth_gain+1'b1;
   else if(smooth_gain>target)smooth_gain<=smooth_gain-1'b1;
  end
  left_low<=partial_product(in_left,smooth_gain,0);left_high<=partial_product(in_left,smooth_gain,1);
  right_low<=partial_product(in_right,smooth_gain,0);right_high<=partial_product(in_right,smooth_gain,1);
  left_product<=left_low+left_high;right_product<=right_low+right_high;
 end
 assign out_left=left_product>>>8;
 assign out_right=right_product>>>8;
endmodule
