`timescale 1ns/1ps
module studio_pixels(input wire clk,input wire [8:0] x,y,input wire picker,
 input wire [1:0] selected,input wire [7:0] instruments,bpm,input wire [3:0] filled,muted,
 input wire [127:0] activity,input wire [4:0] step,input wire playing,recording,armed,
 input wire [2:0] count_in,input wire song_mode,fx,healthy,output reg [15:0] rgb,
 input wire glide_on,input wire [7:0] vib_depth,input wire guide_on,test_mode,input wire [2:0] fx_mode,input wire [6:0] master_percent,input wire master_muted);
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
8'd48:glyph=35'b01110100011001110101110011000101110;
8'd49:glyph=35'b00100011000010000100001000010001110;
8'd50:glyph=35'b01110100010000100010001000100011111;
8'd51:glyph=35'b11110000010000101110000010000111110;
8'd52:glyph=35'b00010001100101010010111110001000010;
8'd53:glyph=35'b11111100001000011110000010000111110;
8'd54:glyph=35'b01110100001000011110100011000101110;
8'd55:glyph=35'b11111000010001000100010000100001000;
8'd56:glyph=35'b01110100011000101110100011000101110;
8'd57:glyph=35'b01110100011000101111000010000101110;
8'd77:glyph=35'b10001110111010110101100011000110001;
8'd43:glyph=35'b00000001000010011111001000010000000;
8'd45:glyph=35'b00000000000000011111000000000000000;
default:glyph=0;endcase end endfunction
 function [127:0] word;input [3:0] n;begin case(n)
  0:word="STUDIO          ";1:word="PIANO           ";2:word="GUITAR          ";3:word="ORGAN           ";4:word="DRUM            ";
  5:word="PLAY            ";6:word="REC             ";7:word="STOP            ";8:word="CLEAR           ";9:word="BACK            ";
  10:word="EMPTY           ";11:word="READY           ";12:word="ARM             ";13:word="SONG            ";14:word="CLEAR TO CHANGE ";default:word="TEST32          ";endcase end endfunction
 wire [7:0] hundreds=8'd48+bpm/100,tens=8'd48+(bpm/10)%10,units=8'd48+bpm%10;
 reg [8:0] volume_mark;reg [7:0] volume_tens,volume_units;
 function [8:0] percent_mark;input [6:0] p;begin case(p)
 7'd0:percent_mark=9'd80;
 7'd1:percent_mark=9'd82;
 7'd2:percent_mark=9'd84;
 7'd3:percent_mark=9'd86;
 7'd4:percent_mark=9'd89;
 7'd5:percent_mark=9'd91;
 7'd6:percent_mark=9'd93;
 7'd7:percent_mark=9'd95;
 7'd8:percent_mark=9'd98;
 7'd9:percent_mark=9'd100;
 7'd10:percent_mark=9'd102;
 7'd11:percent_mark=9'd104;
 7'd12:percent_mark=9'd107;
 7'd13:percent_mark=9'd109;
 7'd14:percent_mark=9'd111;
 7'd15:percent_mark=9'd113;
 7'd16:percent_mark=9'd116;
 7'd17:percent_mark=9'd118;
 7'd18:percent_mark=9'd120;
 7'd19:percent_mark=9'd122;
 7'd20:percent_mark=9'd125;
 7'd21:percent_mark=9'd127;
 7'd22:percent_mark=9'd129;
 7'd23:percent_mark=9'd131;
 7'd24:percent_mark=9'd134;
 7'd25:percent_mark=9'd136;
 7'd26:percent_mark=9'd138;
 7'd27:percent_mark=9'd141;
 7'd28:percent_mark=9'd143;
 7'd29:percent_mark=9'd145;
 7'd30:percent_mark=9'd147;
 7'd31:percent_mark=9'd150;
 7'd32:percent_mark=9'd152;
 7'd33:percent_mark=9'd154;
 7'd34:percent_mark=9'd156;
 7'd35:percent_mark=9'd159;
 7'd36:percent_mark=9'd161;
 7'd37:percent_mark=9'd163;
 7'd38:percent_mark=9'd165;
 7'd39:percent_mark=9'd168;
 7'd40:percent_mark=9'd170;
 7'd41:percent_mark=9'd172;
 7'd42:percent_mark=9'd174;
 7'd43:percent_mark=9'd177;
 7'd44:percent_mark=9'd179;
 7'd45:percent_mark=9'd181;
 7'd46:percent_mark=9'd183;
 7'd47:percent_mark=9'd186;
 7'd48:percent_mark=9'd188;
 7'd49:percent_mark=9'd190;
 7'd50:percent_mark=9'd193;
 7'd51:percent_mark=9'd195;
 7'd52:percent_mark=9'd197;
 7'd53:percent_mark=9'd199;
 7'd54:percent_mark=9'd202;
 7'd55:percent_mark=9'd204;
 7'd56:percent_mark=9'd206;
 7'd57:percent_mark=9'd208;
 7'd58:percent_mark=9'd211;
 7'd59:percent_mark=9'd213;
 7'd60:percent_mark=9'd215;
 7'd61:percent_mark=9'd217;
 7'd62:percent_mark=9'd220;
 7'd63:percent_mark=9'd222;
 7'd64:percent_mark=9'd224;
 7'd65:percent_mark=9'd226;
 7'd66:percent_mark=9'd229;
 7'd67:percent_mark=9'd231;
 7'd68:percent_mark=9'd233;
 7'd69:percent_mark=9'd235;
 7'd70:percent_mark=9'd238;
 7'd71:percent_mark=9'd240;
 7'd72:percent_mark=9'd242;
 7'd73:percent_mark=9'd244;
 7'd74:percent_mark=9'd247;
 7'd75:percent_mark=9'd249;
 7'd76:percent_mark=9'd251;
 7'd77:percent_mark=9'd254;
 7'd78:percent_mark=9'd256;
 7'd79:percent_mark=9'd258;
 7'd80:percent_mark=9'd260;
 7'd81:percent_mark=9'd263;
 7'd82:percent_mark=9'd265;
 7'd83:percent_mark=9'd267;
 7'd84:percent_mark=9'd269;
 7'd85:percent_mark=9'd272;
 7'd86:percent_mark=9'd274;
 7'd87:percent_mark=9'd276;
 7'd88:percent_mark=9'd278;
 7'd89:percent_mark=9'd281;
 7'd90:percent_mark=9'd283;
 7'd91:percent_mark=9'd285;
 7'd92:percent_mark=9'd287;
 7'd93:percent_mark=9'd290;
 7'd94:percent_mark=9'd292;
 7'd95:percent_mark=9'd294;
 7'd96:percent_mark=9'd296;
 7'd97:percent_mark=9'd299;
 7'd98:percent_mark=9'd301;
 7'd99:percent_mark=9'd303;
 7'd100:percent_mark=9'd306;
 default:percent_mark=306;endcase end endfunction
 reg [6:0] remainder;
 always @*begin
  if(master_percent>=100)begin remainder=0;volume_tens=48;end
  else if(master_percent>=90)begin remainder=master_percent-90;volume_tens=57;end
  else if(master_percent>=80)begin remainder=master_percent-80;volume_tens=56;end
  else if(master_percent>=70)begin remainder=master_percent-70;volume_tens=55;end
  else if(master_percent>=60)begin remainder=master_percent-60;volume_tens=54;end
  else if(master_percent>=50)begin remainder=master_percent-50;volume_tens=53;end
  else if(master_percent>=40)begin remainder=master_percent-40;volume_tens=52;end
  else if(master_percent>=30)begin remainder=master_percent-30;volume_tens=51;end
  else if(master_percent>=20)begin remainder=master_percent-20;volume_tens=50;end
  else if(master_percent>=10)begin remainder=master_percent-10;volume_tens=49;end
  else begin remainder=master_percent;volume_tens=48;end
  volume_units=48+remainder;
 end
 always @(posedge clk)volume_mark<=percent_mark(master_percent);
 reg [15:0] base;reg [127:0] message;reg [8:0] tx,ty;reg font_big;
 reg [1:0] row,card;reg [4:0] column;reg [8:0] row_y,card_x,card_y;reg [7:0] digit;
 always @*begin
  base=16'h0863;message=0;tx=0;ty=0;font_big=0;row=0;column=0;row_y=0;card=0;card_x=0;card_y=0;digit=32;
  if(y<33)base=16'h10a5;
  if(!picker)begin
   if(x>=8&&x<112&&y>=10&&y<24)begin message=word(test_mode?15:song_mode?13:0);tx=x-8;ty=y-10;font_big=1;end
   if(x>=120&&x<196&&y>=13&&y<20)begin message={"BPM ",hundreds,tens,units,72'b0};tx=x-120;ty=y-13;end
   if(x>=204&&x<226&&y>=8&&y<27)begin base=fx?16'hb3a0:16'h1907;if(y>=14&&y<21)begin message=fx_mode==1?{"DL",112'b0}:fx_mode==2?{"RV",112'b0}:fx_mode==3?{"CH",112'b0}:{"FX",112'b0};tx=x-209;ty=y-14;end end
   if(x>=236&&x<264&&y>=5&&y<29)begin base=16'h2945;if(y>=10&&y<24)begin message={"-",120'b0};tx=x-244;ty=y-10;font_big=1;end end
   if(x>=276&&x<304&&y>=5&&y<29)begin base=16'h2945;if(y>=10&&y<24)begin message={"+",120'b0};tx=x-284;ty=y-10;font_big=1;end end
   if(x>=112&&x<304&&y>=33&&y<40)begin digit=8'd49+(x-112)/24;message={digit,120'b0};tx=(x-112)%24;ty=y-33;end
   if(y>=40&&y<200)begin
    row=y<80?0:y<120?1:y<160?2:3;row_y=40+row*40;
    base=row==selected?16'h1948:16'h1083;
    if(y==row_y||y==row_y+39)base=16'h2945;
    if(x<108)begin
     if(row==selected&&x<3)base=recording?16'hf945:16'h2e5b;
     if(x>=7&&x<25&&y>=row_y+8&&y<row_y+15)begin message={"T",(8'd49+{6'b0,row}),112'b0};tx=x-7;ty=y-row_y-8;end
     if(x>=28&&x<80&&y>=row_y+8&&y<row_y+15)begin message=word(song_mode&&row==0?1:(1+instruments[row*2+:2]));tx=x-28;ty=y-row_y-8;end
     if(x>=28&&x<80&&y>=row_y+23&&y<row_y+30)begin message=word(filled[row]?11:10);tx=x-28;ty=y-row_y-23;end
     if(x>=84&&x<105&&y>=row_y+6&&y<row_y+33)begin base=muted[row]?16'hb3a0:16'h2945;if(x>=92&&y>=row_y+15&&y<row_y+22)begin message={"M",120'b0};tx=x-92;ty=y-row_y-15;end end
    end else if(x>=112&&x<304)begin
     column=(x-112)/6;
     base=((x-112)%24==0)?16'h4a69:16'h18e6;
     if(activity[{row,column}]&&y>=row_y+8&&y<row_y+31&&(x-112)%6<5)base=row==selected?16'h2e5b:16'h2354;
     if(playing&&column==step&&(x-112)%6<2)base=recording?16'hf945:16'hfd66;
    end
   end
   if(y>=208&&y<238)begin
    if(x>=5&&x<79)begin base=playing?16'h238c:16'h2945;if(y>=215&&y<229)begin message=word(5);tx=x-18;ty=y-215;font_big=1;end end
    if(x>=84&&x<158)begin base=recording?16'hd926:armed?16'hb3a0:16'h2945;if(y>=215&&y<229)begin message=word(armed?12:6);if(count_in!=0)message={"CNT",(8'd48+{5'b0,count_in}),96'b0};tx=x-98;ty=y-215;font_big=1;end end
    if(x>=163&&x<237)begin base=16'h2945;if(y>=215&&y<229)begin message=word(7);tx=x-174;ty=y-215;font_big=1;end end
    if(x>=242&&x<316)begin base=16'h2945;if(y>=215&&y<229)begin message=word(8);tx=x-248;ty=y-215;font_big=1;end end
   end
  end else begin
   if(x>=8&&x<78&&y>=5&&y<30)begin base=16'h2945;if(y>=14&&y<21)begin message=word(9);tx=x-23;ty=y-14;end end
   if(x>=112&&x<304&&y>=12&&y<26)begin message={"CHOOSE T",(8'd49+{6'b0,selected}),56'b0};tx=x-112;ty=y-12;font_big=1;end
   if(x>=8&&x<313&&y>=48&&y<197)begin
    card={y>=128,x>=164};card_x=card[0]?164:8;card_y=card[1]?128:48;
    if(x>=card_x&&x<card_x+148&&y>=card_y&&y<card_y+68)begin
     base=card==instruments[selected*2+:2]?16'h238c:16'h1907;
     if(x==card_x||x==card_x+147||y==card_y||y==card_y+67)base=16'h4a69;
     if(x>=card_x+20&&x<card_x+136&&y>=card_y+28&&y<card_y+42)begin message=word(1+card);tx=x-card_x-20;ty=y-card_y-28;font_big=1;end
    end
   end
   if(y>=208&&y<238)begin
    if(x>=4&&x<77)begin base=glide_on?16'h238c:16'h2945;if(y>=220&&y<227)begin message=glide_on?"GLI ON          ":"GLI OFF         ";tx=x-10;ty=y-220;end end
    if(x>=83&&x<156)begin base=vib_depth!=0?16'h238c:16'h2945;if(y>=220&&y<227)begin message={"VIB ",(8'd48+vib_depth/8'd100),(8'd48+(vib_depth/8'd10)%8'd10),(8'd48+vib_depth%8'd10),72'b0};tx=x-90;ty=y-220;end end
    if(x>=162&&x<235)begin base=guide_on?16'h238c:16'h2945;if(y>=220&&y<227)begin message=guide_on?"LED ON          ":"LED OFF         ";tx=x-169;ty=y-220;end end
    if(x>=241&&x<316)begin base=test_mode?16'hb3a0:16'h2945;if(y>=220&&y<227)begin message=test_mode?"T32 ON          ":"T32 OFF         ";tx=x-248;ty=y-220;end end
   end
  end
  // A dedicated strip stays visible on both workstation and picker pages.
  if(y>=198&&y<208)begin
   base=16'h0863;
   if(x>=8&&x<74&&y>=200&&y<207)begin
    message={master_muted?"MUTE ":"VOL  ",(master_percent>=100?8'd49:8'd48),volume_tens,volume_units,64'b0};tx=x-8;ty=y-200;font_big=0;
   end
   if(x>=80&&x<306&&y>=201&&y<206)base=(master_muted?16'hf945:(x<volume_mark?16'h2e5b:16'h2945));
  end
  if(x>=310&&x<317&&y>=12&&y<19)base=healthy?16'h2e5b:16'hf945;
 end
 reg [15:0] base_r,base_q;reg [127:0] message_r;reg [8:0] tx_r,ty_r;reg font_big_r;
 reg [7:0] char_q;reg [5:0] bit_q;reg valid_q;
 reg [4:0] char_position;reg [8:0] small_x,small_y;
 always @*begin small_x=font_big_r?(tx_r>>1):tx_r;small_y=font_big_r?(ty_r>>1):ty_r;char_position=small_x/6;end
 reg [34:0] glyph_bits;
 always @*glyph_bits=glyph(char_q);
 always @(posedge clk)begin
  base_r<=base;message_r<=message;tx_r<=tx;ty_r<=ty;font_big_r<=font_big;
  base_q<=base_r;
  char_q<=char_position<16?message_r[127-char_position*8-:8]:8'd32;
  bit_q<=34-small_y*5-small_x%6;
  valid_q<=message_r!=0&&small_y<7&&small_x%6<5&&char_position<16;
  rgb<=(valid_q&&glyph_bits[bit_q])?16'hefff:base_q;
 end
endmodule
