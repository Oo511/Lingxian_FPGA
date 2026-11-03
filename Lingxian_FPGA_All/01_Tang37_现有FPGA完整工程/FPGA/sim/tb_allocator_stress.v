`timescale 1ns/1ps
module tb_allocator_stress;
 reg clk=0;always #10 clk=~clk;reg rst=0,tick=0,glide=0;
 reg [23:0] keys=0;wire [31:0] active;wire signed [15:0] pcm;
 reg [31:0] random_state=32'h9e3779b9;
 poly32_engine dut(clk,rst,tick,keys,2'd0,2'd0,glide,8'd0,7'd60,pcm,active);
 task step;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(100)@(negedge clk);end endtask
 integer iteration,v;reg [23:0] allocated;reg [4:0] owner;
 initial begin
  #100;rst=1;
  for(iteration=0;iteration<250;iteration=iteration+1)begin
   random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   case(iteration%6)
    0:keys=24'hffffff; /* full held chord plus existing release tails */
    1:keys=0;
    2:keys=24'b1<<(random_state%24);
    default:keys=random_state[23:0];
   endcase
   glide=random_state[31];repeat(4)step;
   allocated=0;
   for(v=0;v<32;v=v+1)if(dut.gates[v])begin
    owner=dut.owners[v*5+:5];
    if(owner>=24)$fatal(1,"allocator published invalid key owner");
    if(allocated[owner])$fatal(1,"duplicate held voice for key=%d iteration=%d",owner,iteration);
    allocated[owner]=1;
   end
   if(allocated!==keys)$fatal(1,"lost/stuck keys iteration=%d requested=%h allocated=%h",iteration,keys,allocated);
   if(^pcm===1'bx)$fatal(1,"unknown audio after stress allocation");
  end
  keys=0;repeat(4)step;if(dut.gates!==0)$fatal(1,"all-note-off left gates held");
  $display("PASS 250 rapid randomized 0/1/24-key transitions, release-tail pressure and glide: no lost/duplicate/stuck held notes");$finish;
 end
endmodule
