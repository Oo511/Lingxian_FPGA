`timescale 1ns/1ps
// Shared by the renderer and touch decoder. Landscape 320x240.
module piano_geometry(input wire [8:0] x,input wire [8:0] y,
 output reg valid,output reg [3:0] note,output reg black);
 integer w;
 always @* begin
  valid=(x<315 && y>=32 && y<240); black=0; note=0;
  w=x/45;
  case(w)
   0:note=0;1:note=2;2:note=4;3:note=5;
   4:note=7;5:note=9;6:note=11;default:note=0;
  endcase
  if(y<150 && y>=32) begin
   if(x>=33 && x<57) begin note=1;black=1;end
   else if(x>=78 && x<102) begin note=3;black=1;end
   else if(x>=168 && x<192) begin note=6;black=1;end
   else if(x>=213 && x<237) begin note=8;black=1;end
   else if(x>=258 && x<282) begin note=10;black=1;end
  end
 end
endmodule
