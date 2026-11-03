`timescale 1ns/1ps
module voice_allocator4(input wire clk,rst_n,sample_tick,input wire [23:0] keys,
 output reg [3:0] gates,triggers,output reg [19:0] owners,output reg overflow);
 reg [23:0] previous_keys,snapshot;reg [3:0] work_gates,work_triggers;
 reg [19:0] work_owners;reg work_overflow;reg [1:0] state;reg [4:0] cursor;
 integer v,slot;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin gates<=0;triggers<=0;owners<=0;overflow<=0;previous_keys<=0;
 snapshot<=0;work_gates<=0;work_triggers<=0;work_owners<=0;work_overflow<=0;state<=0;cursor<=0;end
 else if(sample_tick) begin
  gates<=work_gates;triggers<=work_triggers;owners<=work_owners;overflow<=work_overflow;
  snapshot<=keys;work_triggers<=0;work_overflow<=0;cursor<=0;state<=1;
 end else if(state==1) begin
  if(work_gates[cursor] && !snapshot[work_owners[cursor*5+:5]]) work_gates[cursor]<=0;
  if(cursor==3) begin cursor<=0;state<=2;end else cursor<=cursor+1'b1;
 end else if(state==2) begin
  if(snapshot[cursor] && !previous_keys[cursor]) begin
   slot=-1;
   for(v=0;v<4;v=v+1) if(!work_gates[v] && slot==-1) slot=v;
   if(slot>=0) begin work_gates[slot]<=1;work_triggers[slot]<=1;work_owners[slot*5+:5]<=cursor;end
   else work_overflow<=1;
  end
  if(cursor==23) begin previous_keys<=snapshot;state<=0;end else cursor<=cursor+1'b1;
 end
endmodule
