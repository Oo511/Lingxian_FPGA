`timescale 1ns/1ps
module tb_latency;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,host=1;
 wire [23:0] keys;wire [7:0] gain;wire [1:0] instrument;wire online,valid;wire [15:0] errors;
 wire signed [15:0] pcm,left,right;wire [31:0] active;
 wire tick,bck,ws,din;
 integer cycles=0,sound_cycle=-1,start_cycle,latency_cycles,fd;
 link_uart_rx receiver(clk,rst,host,keys,gain,instrument,online,valid,errors);
 poly32_engine engine(clk,rst,tick,keys,2'd0,2'd0,1'b0,8'd0,7'd60,pcm,active);
 audio_fx #(.ADDRESS_BITS(4)) effects(clk,rst,tick,pcm,gain,1'b0,1'b0,1'b0,left,right);
 pt8211_tx dac(clk,rst,left,right,tick,bck,ws,din);
 always @(posedge clk)begin
  cycles=cycles+1;
  if(rst && left!=0 && sound_cycle<0)sound_cycle=cycles;
 end
 task send_byte(input [7:0] value);integer bitno;begin
  @(negedge clk);host=0;repeat(434)@(negedge clk);
  for(bitno=0;bitno<8;bitno=bitno+1)begin host=value[bitno];repeat(434)@(negedge clk);end
  host=1;repeat(434)@(negedge clk);
 end endtask
 initial begin
  #100;rst=1;repeat(40)@(negedge clk);
  start_cycle=cycles;
  send_byte(8'ha5);send_byte(8'h5a);send_byte(8'd0);send_byte(8'd1);
  send_byte(8'd0);send_byte(8'd0);send_byte(8'd180);
  send_byte(8'ha5^8'h5a^8'd0^8'd1^8'd0^8'd0^8'd180);
  while(!online)@(negedge clk);
  while(sound_cycle<0)@(negedge clk);
  latency_cycles=sound_cycle-start_cycle;
  if(!active[0])$fatal(1,"audio returned before independent voice allocation");
  if(latency_cycles>500000)$fatal(1,"UART-to-first-PCM exceeds 10ms: %0d cycles",latency_cycles);
  fd=$fopen("latency.txt","w");
  $fdisplay(fd,"source=RTL UART input frame start to first nonzero FPGA PCM");
  $fdisplay(fd,"clock_hz=50000000 cycles=%0d latency_us=%0d",latency_cycles,latency_cycles/50);
  $fclose(fd);
  $display("PASS UART-frame to nonzero audio PCM: %0d cycles (%0d us), <10ms",latency_cycles,latency_cycles/50);
  $finish;
 end
 initial begin #20000000;$fatal(1,"latency timeout");end
endmodule
