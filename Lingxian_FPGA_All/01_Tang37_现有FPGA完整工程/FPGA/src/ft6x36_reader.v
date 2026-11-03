`timescale 1ns/1ps
// Fixed register burst: START 0x70 0x02 RESTART 0x71, 13 bytes, STOP.
// Open drain on both lines, supports clock stretching; no INT dependency.
module ft6x36_reader #(parameter HALF_CYCLES=250,POLL_CYCLES=100000,
 TIMEOUT_CYCLES=1000000,parameter [6:0] ADDRESS=7'h38)(
 input wire clk,rst_n,inout wire scl,sda,
 output reg frame_valid,healthy,output reg [1:0] count,
 output reg [11:0] x0,y0,x1,y1,output reg [15:0] errors);
 reg scl_low,sda_low;assign scl=scl_low?1'b0:1'bz;assign sda=sda_low?1'b0:1'bz;
 (* ASYNC_REG="TRUE" *) reg [1:0] sc,sd;
 always @(posedge clk) begin sc<={sc[0],scl};sd<={sd[0],sda};end
 reg [4:0] state;reg [31:0] timer,poll,watchdog;
 reg [7:0] shift;reg [3:0] bitno,index;reg [1:0] txindex;
 reg reading;reg [7:0] bytes[0:12];
 localparam IDLE=0,START=1,LOW=2,HIGH=3,ACKLOW=4,ACKHIGH=5,
 NEXT=6,RSLOW=7,RSHIGH=8,RSSTART=9,STOPLOW=10,STOPHIGH=11,STOPEND=12,FAIL=13;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=IDLE;scl_low<=0;sda_low<=0;timer<=0;poll<=0;watchdog<=0;
   frame_valid<=0;healthy<=0;count<=0;x0<=0;y0<=0;x1<=0;y1<=0;
   errors<=0;shift<=0;bitno<=7;index<=0;txindex<=0;reading<=0;
  end else begin
   frame_valid<=0;
   if(state==IDLE) watchdog<=0;else watchdog<=watchdog+1;
   if(state!=IDLE && watchdog>=TIMEOUT_CYCLES) begin
    state<=FAIL;watchdog<=0;timer<=0;
   end else if(state==FAIL) begin
    scl_low<=0;sda_low<=0;healthy<=0;count<=0;errors<=errors+1;
    state<=IDLE;poll<=0;timer<=0;
   end else if(state==IDLE) begin
    if(poll>=POLL_CYCLES-1) begin
     poll<=0;
     if(sc[1] && sd[1]) begin sda_low<=1;state<=START;timer<=0;end
     else begin healthy<=0;errors<=errors+1;end
    end else poll<=poll+1;
   end else if((state==HIGH || state==ACKHIGH || state==RSHIGH || state==STOPHIGH) && !sc[1]) timer<=0;
   else if(timer<HALF_CYCLES-1) timer<=timer+1;
   else begin
    timer<=0;
    case(state)
     START:begin scl_low<=1;shift<={ADDRESS,1'b0};txindex<=0;reading<=0;bitno<=7;state<=LOW;end
     LOW:begin sda_low<=reading?0:!shift[bitno];state<=14;end
     14:begin scl_low<=0;state<=HIGH;end
     HIGH:begin
      if(reading) shift[bitno]<=sd[1];
      scl_low<=1;
      if(bitno==0) state<=ACKLOW;else begin bitno<=bitno-1;state<=LOW;end
     end
     ACKLOW:begin sda_low<=reading?(index!=12):0;state<=15;end
     15:begin scl_low<=0;state<=ACKHIGH;end
     ACKHIGH:begin
      scl_low<=1;sda_low<=0;
      if(!reading && sd[1]) state<=FAIL;
      else begin if(reading) bytes[index]<=shift;state<=NEXT;end
     end
     NEXT:begin
      bitno<=7;
      if(reading) begin
       if(index==12) state<=STOPLOW;
       else begin index<=index+1;shift<=0;state<=LOW;end
      end else if(txindex==0) begin shift<=8'h02;txindex<=1;state<=LOW;end
      else if(txindex==1) state<=RSLOW;
      else begin reading<=1;index<=0;shift<=0;state<=LOW;end
     end
     RSLOW:begin sda_low<=0;scl_low<=0;state<=RSHIGH;end
     RSHIGH:begin sda_low<=1;state<=RSSTART;end
     RSSTART:begin scl_low<=1;shift<={ADDRESS,1'b1};txindex<=2;state<=LOW;end
     STOPLOW:begin sda_low<=1;state<=16;end
     16:begin scl_low<=0;state<=STOPHIGH;end
     STOPHIGH:begin sda_low<=0;state<=STOPEND;end
     STOPEND:begin
      // Reject impossible touch counts rather than playing corrupt coordinates.
      if(bytes[0][3:0]<=2) begin
       count<=bytes[0][1:0];x0<={bytes[1][3:0],bytes[2]};y0<={bytes[3][3:0],bytes[4]};
       x1<={bytes[7][3:0],bytes[8]};y1<={bytes[9][3:0],bytes[10]};
       frame_valid<=1;healthy<=1;
      end else begin healthy<=0;count<=0;errors<=errors+1;end
      state<=IDLE;
     end
     default:state<=FAIL;
    endcase
   end
  end
 end
endmodule
