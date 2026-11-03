`timescale 1ns/1ps
// Capture the actual SPI pixel stream, first FX OFF then FX ON.
module tb_fx_frames;
 reg clk=0;always #10 clk=~clk;reg rst=0;reg [1:0] instrument=0;
 reg [3:0] features=0;
 wire sck,mosi,dc,cs,lreset,ready;
 ili9341_piano #(.RESET_CYCLES(4),.WAIT_CYCLES(8),.SPI_HALF_CYCLES(1))
  dut(clk,rst,24'b0,8'd180,instrument,1'b1,sck,mosi,dc,cs,lreset,ready,features,8'd0);
 reg [7:0] b=0,hi;integer bitno=0,pixels=0,frames=0,fd;reg collect=0,half=0;
 always @(posedge sck)begin
  b={b[6:0],mosi};bitno=bitno+1;
  if(bitno==8)begin
   bitno=0;
   if(!dc && b==8'h2c)begin collect=1;pixels=0;half=0;end
   else if(dc && collect)begin
    if(!half)hi=b;
    else begin
     $fdisplay(fd,"%h%h",hi,b);pixels=pixels+1;
     if(pixels==76800)begin
      collect=0;frames=frames+1;instrument=1;features=4'b0100;
      if(frames==2)begin $fclose(fd);$display("PASS actual SPI frames: piano FX OFF and guitar FX ON");$finish;end
     end
    end
    half=!half;
   end
  end
 end
 initial begin fd=$fopen("fx_pixels.txt","w");#100;rst=1;end
 initial begin #200000000;$fatal(1,"FX frame timeout");end
endmodule
