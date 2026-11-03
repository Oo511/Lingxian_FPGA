`timescale 1ns/1ps
module tb_studio_pixels;
 reg clk=0;always #10 clk=~clk;reg [8:0] x=0,y=0;reg picker=0;wire [15:0] rgb;
 studio_pixels dut(clk,x,y,picker,2'd1,8'h93,8'd120,4'b0111,4'b0100,
  {32'b0,32'h0f0f0f0f,32'h00ff00ff,32'h11111111},5'd9,1'b1,1'b1,1'b0,3'd0,1'b0,1'b1,1'b1,rgb,1'b1,8'd192,1'b0,1'b0,3'd1,7'd60,1'b0);
 integer f,xx,yy,p;
 task at;input [8:0] a,b;begin @(negedge clk);x=a;y=b;repeat(3)@(negedge clk);end endtask
 initial begin
  at(166,65);if(rgb!==16'hf945)$fatal(1,"recording cursor not visible");
  at(115,180);if(rgb!==16'h18e6)$fatal(1,"empty track grid");
  for(p=0;p<2;p=p+1)begin
   picker=p;f=$fopen(p==0?"studio_main.ppm":"studio_picker.ppm","wb");$fwrite(f,"P6\n320 240\n255\n");
   for(yy=0;yy<240;yy=yy+1)for(xx=0;xx<320;xx=xx+1)begin at(xx,yy);$fwrite(f,"%c%c%c",{rgb[15:11],3'b0},{rgb[10:5],2'b0},{rgb[4:0],3'b0});end
   $fclose(f);
  end
  $display("PASS 320x240 studio/picker RTL renders, visible recording playhead and empty grid");$finish;
 end
 initial begin #30000000;$fatal(1,"pixel render timeout");end
endmodule
