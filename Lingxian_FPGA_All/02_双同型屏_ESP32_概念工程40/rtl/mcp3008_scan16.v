// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Two MCP3008s, mode 0, 24 clocks: 0x01, {1,channel[2:0],0000}, 0x00.
// The final 10 received bits are the conversion. 3.3V operation: 1MHz SCK.
module mcp3008_scan16 #(
    parameter integer HALF_CYCLES=25, // 1MHz @ 50MHz
    parameter integer GAP_CYCLES=100 // CS high 2us between conversions
) (
    input wire clk, input wire rst_n,
    input wire miso,
    output reg sck,
    output wire mosi,
    output reg [1:0] cs_n,
    output reg [159:0] values,
    output reg sample_valid,
    output reg [3:0] sampled_channel,
    output reg [9:0] sampled_value,
    output reg sweep_valid
);
    reg busy;
    reg [31:0] counter;
    reg [3:0] channel;
    reg [4:0] bit_index;
    reg [23:0] tx,rx;
    reg miso_a,miso_b;
    assign mosi = busy ? tx[23] : 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sck<=0;cs_n<=2'b11;busy<=0;counter<=0;channel<=0;bit_index<=23;
            tx<=0;rx<=0;values<=0;sample_valid<=0;sweep_valid<=0;
            sampled_channel<=0;sampled_value<=0;miso_a<=0;miso_b<=0;
        end else begin
            miso_a<=miso;miso_b<=miso_a;
            sample_valid<=0;sweep_valid<=0;
            if(!busy) begin
                if(counter==GAP_CYCLES-1) begin
                    busy<=1;counter<=0;bit_index<=23;rx<=0;sck<=0;
                    cs_n <= channel[3] ? 2'b01 : 2'b10;
                    tx <= {8'h01,1'b1,channel[2:0],4'b0000,8'h00};
                end else counter<=counter+1'b1;
            end else if(counter==HALF_CYCLES-1) begin
                counter<=0;sck<=!sck;
                if(!sck) rx<={rx[22:0],miso_b};
                else if(bit_index==0) begin
                    sck<=0;cs_n<=2'b11;busy<=0;
                    values[channel*10 +: 10]<=rx[9:0];
                    sampled_channel<=channel;sampled_value<=rx[9:0];sample_valid<=1;
                    if(channel==15) sweep_valid<=1;
                    channel<=channel+1'b1;
                end else begin bit_index<=bit_index-1'b1;tx<={tx[22:0],1'b0};end
            end else counter<=counter+1'b1;
        end
    end
endmodule
