// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Active-low asynchronous button, two-flop synchronizer + stable-time filter.
module button_debounce #(
    parameter integer STABLE_CYCLES = 50000
) (
    input wire clk,
    input wire rst_n,
    input wire button_n,
    output reg pressed
);
    reg sync_a, sync_b;
    reg [31:0] stable_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_a <= 1'b1;
            sync_b <= 1'b1;
            pressed <= 1'b0;
            stable_count <= 0;
        end else begin
            sync_a <= button_n;
            sync_b <= sync_a;
            if ((!sync_b) == pressed) begin
                stable_count <= 0;
            end else if (stable_count == STABLE_CYCLES - 1) begin
                pressed <= !sync_b;
                stable_count <= 0;
            end else begin
                stable_count <= stable_count + 1'b1;
            end
        end
    end
endmodule
