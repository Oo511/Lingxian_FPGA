`timescale 1ns/1ps
module tb_performance_control39;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,valid=0,pressed=0,chord=0;reg [8:0] x=0,y=0;
 reg [1:0] inst=0;reg [2:0] off=0;reg [31:0] ms=0;
 wire [23:0] keys;wire [7:0] gain,note;
 performance_control39 dut(clk,rst,valid,pressed,x,y,ms,inst,off,chord,keys,gain,note);
 integer fd,status,count=0,r,i,o,c,p,xx,yy,eg,en;reg [31:0] tm;reg [23:0] ek;
 initial begin
  fd=$fopen("performance_vectors.txt","r");if(!fd)$fatal(1,"missing reference vectors");
  while(!$feof(fd))begin
   status=$fscanf(fd,"%d %d %d %d %d %d %d %h %h %d %d\n",r,i,o,c,p,xx,yy,tm,ek,eg,en);
   if(status==11)begin
    @(negedge clk);valid=0;inst=i;off=o;chord=c;pressed=p;x=xx;y=yy;ms=tm;
    if(r)begin rst=0;repeat(2)@(negedge clk);rst=1;repeat(3)@(negedge clk);end
    valid=1;@(negedge clk);valid=0;
    if(keys!==ek||gain!==eg[7:0]||note!==en[7:0])$fatal(1,"vector %d inst=%d x=%d y=%d got keys=%h gain=%d note=%d expected %h %d %d",count,i,xx,yy,keys,gain,note,ek,eg,en);
    count=count+1;
   end
  end
  $display("PASS %0d original-controller differential vectors: piano/organ all offsets, guitar geometry/hysteresis, drums, chords, gain, stable note change, release protection and tick rollover",count);$finish;
 end
endmodule
