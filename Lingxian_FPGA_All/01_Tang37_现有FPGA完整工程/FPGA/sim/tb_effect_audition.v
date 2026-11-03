`timescale 1ns/1ps
// Real voice/chorus/effect datapaths, compressed system-clock spacing between
// audio ticks. File samples still represent the actual 48828.125 Hz DAC rate.
module tb_effect_audition;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,gate=0,enable=1;
 wire signed [15:0] voice,chorus,old_l,old_r,new_l,new_r;
 wire active;
 voice_ex piano(clk,rst,tick,gate,1'b0,32'd23012828,2'd0,2'd0,1'b0,1'b0,9'sd0,voice,active);
 chorus_fx c(clk,rst,tick,enable,voice,chorus);
 audio_fx #(.ADDRESS_BITS(12)) baseline(clk,rst,tick,chorus,8'd180,1'b0,enable,enable,old_l,old_r);
 audio_fx #(.ADDRESS_BITS(14)) candidate(clk,rst,tick,chorus,8'd180,1'b0,enable,enable,new_l,new_r);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(18)@(negedge clk);end endtask
 integer i,fd;
 real old_energy,new_energy;
 initial begin
  #100;rst=1;repeat(18000)step;
  fd=$fopen("effect_audition.csv","w");
  $fdisplay(fd,"sample,dry,old_left,old_right,new_left,new_right");
  old_energy=0;new_energy=0;
  for(i=0;i<64000;i=i+1)begin
   if(i==0)gate=1;
   if(i==6000)gate=0;
   step;
   if(new_l===16'sh7fff || new_l===16'sh8000 || new_r===16'sh7fff || new_r===16'sh8000)
    $fatal(1,"candidate clipped");
   $fdisplay(fd,"%d,%d,%d,%d,%d,%d",i,voice,old_l,old_r,new_l,new_r);
   if(i>=16500 && i<22000)begin
    old_energy=old_energy+$itor($signed(old_r))*$itor($signed(old_r));
    new_energy=new_energy+$itor($signed(new_r))*$itor($signed(new_r));
   end
  end
  $fclose(fd);
  if(new_energy<=100000 || new_energy<=old_energy*4)
   $fatal(1,"candidate repeat not distinguishable: old=%f new=%f",old_energy,new_energy);
  // Turning off must recover bit-identical dry output with the same voice.
  enable=0;repeat(600)step;gate=1;
  repeat(1000)begin
   step;
   if(new_l!==old_l || new_r!==old_r)$fatal(1,"bypass changed dry audio");
  end
  gate=0;repeat(22000)step;
  if(new_l!==0 || new_r!==0 || old_l!==0 || old_r!==0)$fatal(1,"disable tail never reaches exact silence");
  $display("PASS 335ms repeat exceeds old 84ms tail, no single-note clipping, bit-identical bypass and exact silence");
  $finish;
 end
endmodule
