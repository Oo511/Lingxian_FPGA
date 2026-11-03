`timescale 1ns/1ps
// HDL port of the performance mapping and debounce state. Coordinates are
// calibrated landscape pixels; acquisition/calibration are separate blocks.
module performance_control39(
 input wire clk,rst_n,frame_valid,pressed,
 input wire [8:0] x,y,input wire [31:0] now_ms,
 input wire [1:0] instrument,input wire [2:0] piano_offset,input wire chord,
 output reg [23:0] keys,output reg [7:0] gain,note);
 reg [7:0] candidate;reg candidate_seen;reg [31:0] last_good;
 reg [1:0] previous_instrument;
 function [7:0] white;input integer i;begin
  case(i)0:white=0;1:white=2;2:white=4;3:white=5;4:white=7;5:white=9;6:white=11;
  7:white=12;8:white=14;9:white=16;10:white=17;11:white=19;12:white=21;default:white=23;endcase
 end endfunction
 function [7:0] find_note;input [8:0] xx,yy;input [1:0] inst;input [2:0] off;
 integer i,col,row;reg [7:0] a,b;begin
  find_note=255;col=0;row=0;a=0;b=0;
  if(yy>=54 && yy<204 && xx>=2 && xx<317)begin
   if(inst==3)begin
    if(xx>=12&&xx<154&&yy>=58&&yy<124)find_note=0;
    if(xx>=166&&xx<308&&yy>=58&&yy<124)find_note=1;
    if(xx>=12&&xx<154&&yy>=133&&yy<199)find_note=2;
    if(xx>=166&&xx<308&&yy>=133&&yy<199)find_note=3;
   end else if(inst==1)begin
    if(xx>=32)begin
     col=xx<103?0:xx<174?1:xx<245?2:3;
     row=yy<79?0:yy<104?1:yy<129?2:yy<154?3:yy<179?4:5;
     find_note=row*4+col;
    end
   end else begin
    col=xx<47?0:xx<92?1:xx<137?2:xx<182?3:xx<227?4:xx<272?5:6;
    find_note=white(off+col);
    if(yy<136)for(i=1;i<7;i=i+1)begin
     a=white(off+i-1);b=white(off+i);
     if(b-a==2 && xx>=2+45*i-12 && xx<2+45*i+12)find_note=a+1'b1;
    end
   end
  end
 end endfunction
 function inside_held;input [7:0] n;input [8:0] xx,yy;integer left,top;begin
  left=32+(n%4)*71;top=54+(n/4)*25;
  inside_held=n<24 && xx>=left-4 && xx<left+75 && yy>=top-4 && yy<top+29;
 end endfunction
 function [7:0] expression_gain;input [8:0] yy;begin
  // Generated exact constants avoid inferring a multiplier/divider for gain.
  case(yy)
  9'd54:expression_gain=8'd100;
  9'd55:expression_gain=8'd100;
  9'd56:expression_gain=8'd101;
  9'd57:expression_gain=8'd102;
  9'd58:expression_gain=8'd103;
  9'd59:expression_gain=8'd104;
  9'd60:expression_gain=8'd105;
  9'd61:expression_gain=8'd106;
  9'd62:expression_gain=8'd106;
  9'd63:expression_gain=8'd107;
  9'd64:expression_gain=8'd108;
  9'd65:expression_gain=8'd109;
  9'd66:expression_gain=8'd110;
  9'd67:expression_gain=8'd111;
  9'd68:expression_gain=8'd112;
  9'd69:expression_gain=8'd113;
  9'd70:expression_gain=8'd113;
  9'd71:expression_gain=8'd114;
  9'd72:expression_gain=8'd115;
  9'd73:expression_gain=8'd116;
  9'd74:expression_gain=8'd117;
  9'd75:expression_gain=8'd118;
  9'd76:expression_gain=8'd119;
  9'd77:expression_gain=8'd120;
  9'd78:expression_gain=8'd120;
  9'd79:expression_gain=8'd121;
  9'd80:expression_gain=8'd122;
  9'd81:expression_gain=8'd123;
  9'd82:expression_gain=8'd124;
  9'd83:expression_gain=8'd125;
  9'd84:expression_gain=8'd126;
  9'd85:expression_gain=8'd127;
  9'd86:expression_gain=8'd127;
  9'd87:expression_gain=8'd128;
  9'd88:expression_gain=8'd129;
  9'd89:expression_gain=8'd130;
  9'd90:expression_gain=8'd131;
  9'd91:expression_gain=8'd132;
  9'd92:expression_gain=8'd133;
  9'd93:expression_gain=8'd134;
  9'd94:expression_gain=8'd134;
  9'd95:expression_gain=8'd135;
  9'd96:expression_gain=8'd136;
  9'd97:expression_gain=8'd137;
  9'd98:expression_gain=8'd138;
  9'd99:expression_gain=8'd139;
  9'd100:expression_gain=8'd140;
  9'd101:expression_gain=8'd141;
  9'd102:expression_gain=8'd141;
  9'd103:expression_gain=8'd142;
  9'd104:expression_gain=8'd143;
  9'd105:expression_gain=8'd144;
  9'd106:expression_gain=8'd145;
  9'd107:expression_gain=8'd146;
  9'd108:expression_gain=8'd147;
  9'd109:expression_gain=8'd147;
  9'd110:expression_gain=8'd148;
  9'd111:expression_gain=8'd149;
  9'd112:expression_gain=8'd150;
  9'd113:expression_gain=8'd151;
  9'd114:expression_gain=8'd152;
  9'd115:expression_gain=8'd153;
  9'd116:expression_gain=8'd154;
  9'd117:expression_gain=8'd154;
  9'd118:expression_gain=8'd155;
  9'd119:expression_gain=8'd156;
  9'd120:expression_gain=8'd157;
  9'd121:expression_gain=8'd158;
  9'd122:expression_gain=8'd159;
  9'd123:expression_gain=8'd160;
  9'd124:expression_gain=8'd161;
  9'd125:expression_gain=8'd161;
  9'd126:expression_gain=8'd162;
  9'd127:expression_gain=8'd163;
  9'd128:expression_gain=8'd164;
  9'd129:expression_gain=8'd165;
  9'd130:expression_gain=8'd166;
  9'd131:expression_gain=8'd167;
  9'd132:expression_gain=8'd168;
  9'd133:expression_gain=8'd168;
  9'd134:expression_gain=8'd169;
  9'd135:expression_gain=8'd170;
  9'd136:expression_gain=8'd171;
  9'd137:expression_gain=8'd172;
  9'd138:expression_gain=8'd173;
  9'd139:expression_gain=8'd174;
  9'd140:expression_gain=8'd175;
  9'd141:expression_gain=8'd175;
  9'd142:expression_gain=8'd176;
  9'd143:expression_gain=8'd177;
  9'd144:expression_gain=8'd178;
  9'd145:expression_gain=8'd179;
  9'd146:expression_gain=8'd180;
  9'd147:expression_gain=8'd181;
  9'd148:expression_gain=8'd182;
  9'd149:expression_gain=8'd182;
  9'd150:expression_gain=8'd183;
  9'd151:expression_gain=8'd184;
  9'd152:expression_gain=8'd185;
  9'd153:expression_gain=8'd186;
  9'd154:expression_gain=8'd187;
  9'd155:expression_gain=8'd188;
  9'd156:expression_gain=8'd188;
  9'd157:expression_gain=8'd189;
  9'd158:expression_gain=8'd190;
  9'd159:expression_gain=8'd191;
  9'd160:expression_gain=8'd192;
  9'd161:expression_gain=8'd193;
  9'd162:expression_gain=8'd194;
  9'd163:expression_gain=8'd195;
  9'd164:expression_gain=8'd195;
  9'd165:expression_gain=8'd196;
  9'd166:expression_gain=8'd197;
  9'd167:expression_gain=8'd198;
  9'd168:expression_gain=8'd199;
  9'd169:expression_gain=8'd200;
  9'd170:expression_gain=8'd201;
  9'd171:expression_gain=8'd202;
  9'd172:expression_gain=8'd202;
  9'd173:expression_gain=8'd203;
  9'd174:expression_gain=8'd204;
  9'd175:expression_gain=8'd205;
  9'd176:expression_gain=8'd206;
  9'd177:expression_gain=8'd207;
  9'd178:expression_gain=8'd208;
  9'd179:expression_gain=8'd209;
  9'd180:expression_gain=8'd209;
  9'd181:expression_gain=8'd210;
  9'd182:expression_gain=8'd211;
  9'd183:expression_gain=8'd212;
  9'd184:expression_gain=8'd213;
  9'd185:expression_gain=8'd214;
  9'd186:expression_gain=8'd215;
  9'd187:expression_gain=8'd216;
  9'd188:expression_gain=8'd216;
  9'd189:expression_gain=8'd217;
  9'd190:expression_gain=8'd218;
  9'd191:expression_gain=8'd219;
  9'd192:expression_gain=8'd220;
  9'd193:expression_gain=8'd221;
  9'd194:expression_gain=8'd222;
  9'd195:expression_gain=8'd223;
  9'd196:expression_gain=8'd223;
  9'd197:expression_gain=8'd224;
  9'd198:expression_gain=8'd225;
  9'd199:expression_gain=8'd226;
  9'd200:expression_gain=8'd227;
  9'd201:expression_gain=8'd228;
  9'd202:expression_gain=8'd229;
  9'd203:expression_gain=8'd230;
  default:expression_gain=200;
  endcase
 end endfunction
 reg [7:0] mapped;
 reg [23:0] next_keys;
 integer k;
 always @*begin
  mapped=pressed?find_note(x,y,instrument,piano_offset):8'd255;
  if(instrument==1 && mapped<24 && note<24 && mapped!=note && inside_held(note,x,y))mapped=note;
  next_keys=mapped<24?(24'b1<<mapped):24'b0;
  if(chord && instrument!=3 && mapped<24)begin
   if(instrument==1)next_keys=24'h001441;
   else begin
    if(mapped+4<24)next_keys=next_keys|(24'b1<<(mapped+4));
    if(mapped+7<24)next_keys=next_keys|(24'b1<<(mapped+7));
    if(mapped+12<24)next_keys=next_keys|(24'b1<<(mapped+12));
   end
  end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin keys<=0;gain<=200;note<=255;candidate<=255;candidate_seen<=0;last_good<=0;previous_instrument<=0;end
 else if(instrument!=previous_instrument)begin
  previous_instrument<=instrument;keys<=0;gain<=200;note<=255;candidate<=255;candidate_seen<=0;last_good<=0;
 end else if(frame_valid)begin
  if(instrument==3)begin
   candidate<=255;candidate_seen<=0;
   if(mapped==255)begin keys<=0;note<=255;end
   else begin note<=mapped;keys<=next_keys;gain<=220;last_good<=now_ms;end
  end else if(mapped==255)begin
   if(pressed || (now_ms-last_good)>=12)begin keys<=0;note<=255;candidate<=255;candidate_seen<=0;end
  end else begin
   last_good<=now_ms;
   if(note==255 || mapped==note || (candidate==mapped && candidate_seen))begin
    note<=mapped;keys<=next_keys;candidate<=255;candidate_seen<=0;
    gain<=instrument==1?8'd210:expression_gain(y);
   end else begin candidate<=mapped;candidate_seen<=1;end
  end
 end
endmodule
