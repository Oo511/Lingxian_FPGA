// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// PT8211 LSB-justified, MSB-first, exactly 16 bits/channel.
// Datasheet V1.7 p4: WS=0 RIGHT; WS=1 LEFT; latch DIN on BCK rising.
// Signals change on BCK falling. No standard I2S one-bit delay.
module pt8211_tx #(
    parameter integer BCK_HALF_CYCLES = 16
) (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] sample_left,
    input wire signed [15:0] sample_right,
    output wire sample_tick,
    output reg bck,
    output reg ws,
    output wire din
);
    reg [15:0] divider;
    reg [4:0] bit_index;
    reg [31:0] shift_data;
    // Both channels are captured atomically; upstream can advance on this tick.
    assign sample_tick = rst_n && (divider == BCK_HALF_CYCLES - 1)
                        && bck && (bit_index == 31);
    assign din = shift_data[31];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divider <= 0;
            bit_index <= 31;
            shift_data <= 0;
            bck <= 0;
            ws <= 1;
        end else if (divider == BCK_HALF_CYCLES - 1) begin
            divider <= 0;
            bck <= !bck;
            if (bck) begin
                if (bit_index == 31) begin
                    shift_data <= {sample_right, sample_left};
                    bit_index <= 0;
                    ws <= 0;
                end else begin
                    shift_data <= {shift_data[30:0], 1'b0};
                    bit_index <= bit_index + 1'b1;
                    if (bit_index == 15) ws <= 1;
                end
            end
        end else begin
            divider <= divider + 1'b1;
        end
    end
endmodule
