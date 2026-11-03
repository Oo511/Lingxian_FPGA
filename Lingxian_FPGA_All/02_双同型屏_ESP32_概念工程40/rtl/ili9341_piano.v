`timescale 1ns/1ps
// Assumed ILI9341, RGB565, landscape MADCTL=0x28. No framebuffer.
module ili9341_piano #(parameter RESET_CYCLES=1000000,
 WAIT_CYCLES=6000000,SPI_HALF_CYCLES=16)(
 input wire clk,rst_n,input wire [23:0] keys,input wire [7:0] gain,
 input wire [1:0] chord_mode,input wire healthy,
 output wire sck,mosi,dc,cs_n,output reg lcd_rst_n,output reg ready,input wire [3:0] features,
 input wire [7:0] vibrato_depth);
 reg start,dc_in;reg [7:0] data;wire busy,done;
 lcd_spi_byte #(.HALF_CYCLES(SPI_HALF_CYCLES)) spi(clk,rst_n,start,dc_in,data,busy,done,sck,mosi,dc);
 assign cs_n=!lcd_rst_n;
 reg [3:0] state;reg [31:0] timer;reg [5:0] index;
 reg [8:0] scan_x,scan_y;
 wire [8:0] x=319-scan_y,y=scan_x;reg [23:0] shown_keys;reg [7:0] shown_gain;
 reg [1:0] shown_chord;reg shown_healthy;reg [3:0] shown_features;reg [7:0] shown_vibrato_depth;
 wire [8:0] vibrato_mark=9'd170+{2'b0,shown_vibrato_depth[7:1]};
 wire valid,black;wire [3:0] note;
 piano_geometry geom(x,y,valid,note,black);
 reg [15:0] color;
function [34:0] glyph;input [7:0] ch;begin case(ch)
8'd66:glyph=35'b11110100011000111110100011000111110;
8'd68:glyph=35'b11110100011000110001100011000111110;
8'd86:glyph=35'b10001100011000110001100010101000100;
8'd65:glyph=35'b01110100011000111111100011000110001;
8'd67:glyph=35'b01111100001000010000100001000001111;
8'd69:glyph=35'b11111100001000011110100001000011111;
8'd70:glyph=35'b11111100001000011110100001000010000;
8'd71:glyph=35'b01110100011000010111100011000101110;
8'd72:glyph=35'b10001100011000111111100011000110001;
8'd73:glyph=35'b11111001000010000100001000010011111;
8'd75:glyph=35'b10001100101010011000101001001010001;
8'd76:glyph=35'b10000100001000010000100001000011111;
8'd78:glyph=35'b10001110011010110101100111000110001;
8'd79:glyph=35'b01110100011000110001100011000101110;
8'd80:glyph=35'b11110100011000111110100001000010000;
8'd82:glyph=35'b11110100011000111110101001001010001;
8'd83:glyph=35'b01111100001000001110000010000111110;
8'd84:glyph=35'b11111001000010000100001000010000100;
8'd85:glyph=35'b10001100011000110001100011000101110;
8'd88:glyph=35'b10001100010101000100010101000110001;
8'd89:glyph=35'b10001100010101000100001000010000100;
default:glyph=0;endcase end endfunction
function [7:0] word_char;input [3:0] word;input [4:0] n;begin case(word)
0:case(n)
0:word_char=8'd76;
1:word_char=8'd73;
2:word_char=8'd78;
3:word_char=8'd71;
4:word_char=8'd88;
5:word_char=8'd73;
6:word_char=8'd65;
7:word_char=8'd78;
default:word_char=32;endcase
1:case(n)
0:word_char=8'd80;
1:word_char=8'd73;
2:word_char=8'd65;
3:word_char=8'd78;
4:word_char=8'd79;
default:word_char=32;endcase
2:case(n)
0:word_char=8'd71;
1:word_char=8'd85;
2:word_char=8'd73;
3:word_char=8'd84;
4:word_char=8'd65;
5:word_char=8'd82;
default:word_char=32;endcase
3:case(n)
0:word_char=8'd75;
1:word_char=8'd69;
2:word_char=8'd89;
3:word_char=8'd83;
default:word_char=32;endcase
4:case(n)
0:word_char=8'd83;
1:word_char=8'd84;
2:word_char=8'd82;
3:word_char=8'd73;
4:word_char=8'd78;
5:word_char=8'd71;
6:word_char=8'd83;
default:word_char=32;endcase
5:case(n)
0:word_char=71;1:word_char=76;2:word_char=73;3:word_char=68;4:word_char=69;
default:word_char=32;endcase
6:case(n)
0:word_char=86;1:word_char=73;2:word_char=66;3:word_char=82;4:word_char=65;5:word_char=84;6:word_char=79;
default:word_char=32;endcase
7:case(n)
0:word_char=70;1:word_char=88;2:word_char=32;3:word_char=79;
4:word_char=shown_features[2]?78:70;5:word_char=shown_features[2]?32:70;
default:word_char=32;endcase
8:case(n)
0:word_char=79;1:word_char=82;2:word_char=71;3:word_char=65;4:word_char=78;
default:word_char=32;endcase
9:case(n)
0:word_char=72;1:word_char=79;2:word_char=76;3:word_char=68;
default:word_char=32;endcase
default:word_char=32;endcase end endfunction
reg [15:0] color_q;
 always @(posedge clk) color_q<=color;
 reg [5:0] font_index;reg font_valid;
 always @(posedge clk)begin
 font_index<=34-(font_large?ty/2:ty)*5-(font_large?(tx%12)/2:tx%6);
 font_valid<=(font_large?tx%12<10:tx%6<5) && tx<(font_large?192:90);
 end
reg [34:0] letter_q;
always @(posedge clk) letter_q<=letter;
reg [34:0] letter;reg [8:0] tx;reg [3:0] ty;reg [3:0] word;reg font_large;

 always @* begin
  color=16'h0863;letter=0;tx=0;ty=0;word=15;font_large=0;
  if(y<42) color=shown_features[3]?16'h21ac:16'h10a5;
  if(y>=210)color=(x<160?shown_features[0]:shown_features[1])?16'h218c:16'h10a5;
  if(x>=170&&x<306&&y>=230&&y<234)color=(x<vibrato_mark)?16'h21ac:16'h2945;
  if(x+9'd2>=vibrato_mark&&x<=vibrato_mark+9'd2&&y>=227&&y<237)color=16'hfd66;
  if(x>=274 && x<284 && y>=16 && y<24)color=shown_features[2]?16'hfd66:16'h1907;
  if(x>=8 && x<104 && y>=54 && y<204) begin
   color=shown_chord==0?16'h218c:16'h1907;
   if((x<11 || x>=101 || y<57 || y>=201) && shown_chord==0) color=16'hfd66;
  end
  if(x>=112 && x<208 && y>=54 && y<204) begin
   color=shown_chord==1?16'h21ac:16'h1907;
   if((x<115 || x>=205 || y<57 || y>=201) && shown_chord==1) color=16'h2e5b;
  end
  if(x>=216 && x<312 && y>=54 && y<204) begin
   color=shown_chord==2?16'h218c:16'h1907;
   if((x<219 || x>=309 || y<57 || y>=201) && shown_chord==2) color=16'hfd66;
  end
  // Piano silhouette and raised black keys.
  if(x>=22 && x<90 && y>=82 && y<132) begin
   color=16'hefff;
   if(x==22 || x==39 || x==56 || x==73) color=16'h1907;
   if(y<110 && ((x>=34 && x<41)||(x>=51 && x<58)||(x>=68 && x<75))) color=16'h0863;
  end
  // Guitar silhouette: neck, body, sound hole and three visible strings.
  if(x>=156 && x<165 && y>=70 && y<108) color=16'hdca9;
  if((x>=149 && x<172 && y>=103 && y<120)||(x>=139 && x<183 && y>=117 && y<138)) color=16'hfd66;
  if(x>=155 && x<167 && y>=113 && y<123) color=16'h0863;
  if((x==158 || x==161 || x==164) && y>=72 && y<134) color=16'hefff;
  // Five organ pipes: sustained tone is visible as HOLD under this card.
  if(y>=78 && y<132 && ((x>=231&&x<240)||(x>=289&&x<298)))color=16'hce79;
  if(y>=66 && y<132 && ((x>=246&&x<255)||(x>=275&&x<284)))color=16'hefff;
  if(y>=58 && y<132 && x>=260&&x<269)color=16'hfd66;
  if(y>=132&&y<138&&x>=229&&x<300)color=16'h632c;
  if(y>=13 && y<27) begin
   word=(x>=188&&x<272)?7:0;tx=x-((x>=188&&x<272)?188:16);ty=y-13;font_large=1;
  end
  else if(y>=151 && y<165) begin word=x<108?1:(x<212?2:8);tx=x-(x<108?26:(x<212?124:234));ty=y-151;font_large=1;end
  else if(y>=176 && y<183) begin word=x<108?3:(x<212?4:9);tx=x-(x<108?44:(x<212?139:252));ty=y-176;end
  else if(y>=218 && y<225) begin word=x<160?5:6;tx=x-(x<160?58:214);ty=y-218;end
  if(word!=15 && tx>=0) begin
   letter=glyph(word_char(word,font_large?tx/12:tx/6));
   if(font_valid)
    if(letter_q[font_index]) color=16'hefff;
  end
  if(x>=294 && x<302 && y>=16 && y<24) color=shown_healthy?16'h2e5b:16'hf9a6;
 end
 // Each entry is {data/command,byte}. Minimal initialization; vendor variants
 // may require additional power/gamma commands.
 function [8:0] init_byte;input [5:0] i;begin
  case(i)
   0:init_byte=9'h001;
   1:init_byte=9'h011; // sleep out, followed by >=120ms delay
   2:init_byte=9'h03a;3:init_byte=9'h155;
   4:init_byte=9'h036;5:init_byte=9'h188;
   6:init_byte=9'h029;
   default:init_byte=0;
  endcase
 end endfunction
 function [8:0] window_byte;input [5:0] i;begin
  case(i)
   0:window_byte=9'h02a;1:window_byte=9'h100;2:window_byte=9'h100;
   3:window_byte=9'h100;4:window_byte=9'h1ef;
   5:window_byte=9'h02b;6:window_byte=9'h100;7:window_byte=9'h100;
   8:window_byte=9'h101;9:window_byte=9'h13f;10:window_byte=9'h02c;
   default:window_byte=0;
  endcase
 end endfunction
 reg [8:0] entry;reg [15:0] pixel;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin state<=0;timer<=0;index<=0;start<=0;dc_in<=0;data<=0;
  lcd_rst_n<=0;ready<=0;scan_x<=0;scan_y<=0;shown_keys<=0;shown_gain<=0;
  shown_chord<=0;shown_healthy<=0;shown_features<=0;shown_vibrato_depth<=0;pixel<=0;entry<=0;end
 else begin
  start<=0;
  case(state)
   0:if(timer==RESET_CYCLES-1) begin lcd_rst_n<=1;timer<=0;state<=1;end else timer<=timer+1;
   1:if(timer==WAIT_CYCLES-1) begin timer<=0;state<=2;index<=0;end else timer<=timer+1;
   2:begin entry=init_byte(index);data<=entry[7:0];dc_in<=entry[8];start<=1;state<=3;end
   3:if(done) begin
    if(index==0 || index==1 || index==6) begin timer<=0;state<=4;end
    else if(index==6) begin ready<=1;state<=5;index<=0;end
    else begin index<=index+1;state<=2;end
   end
   4:if(timer==WAIT_CYCLES-1) begin
     if(index==6) begin ready<=1;state<=5;index<=0;end
     else begin index<=index+1;state<=2;end
     timer<=0;end else timer<=timer+1;
   5:begin
    shown_keys<=keys;shown_gain<=gain;shown_chord<=chord_mode;shown_healthy<=healthy;
    shown_features<=features;shown_vibrato_depth<=vibrato_depth;
    scan_x<=0;scan_y<=0;index<=0;state<=6;
   end
   6:begin entry=window_byte(index);data<=entry[7:0];dc_in<=entry[8];start<=1;state<=7;end
   7:if(done) begin if(index==10) state<=11;else begin index<=index+1;state<=6;end end
   8:begin pixel<=color_q;data<=color_q[15:8];dc_in<=1;start<=1;state<=9;end
   9:if(done) begin data<=pixel[7:0];start<=1;state<=10;end
   10:if(done) begin
    if(scan_x==239) begin scan_x<=0;if(scan_y==319) state<=5;else begin scan_y<=scan_y+1;state<=11;end end
    else begin scan_x<=scan_x+1;state<=11;end
   end
   11:state<=12;
   12:state<=13;
   13:state<=8;
   default:state<=0;
  endcase
 end
endmodule
