// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// COL->diode->switch->ROW: pull up columns, drive ONLY selected row low.
// Output row_select is an enable mask. Put tri-state buffers at top-level IO.
module key_matrix_6x4 #(
    parameter integer ROW_CYCLES = 2500, // 50us @ 50MHz; 0.3ms/full scan
    parameter integer DEBOUNCE_FRAMES = 3
) (
    input wire clk, input wire rst_n,
    input wire [3:0] columns_n,
    output wire [5:0] row_select,
    output reg [23:0] keys,
    output reg frame_valid
);
    reg [2:0] row;
    reg [31:0] count;
    reg [3:0] sync_a, sync_b;
    reg [23:0] raw;
    reg [7:0] stable_count [0:23];
    reg [23:0] completed;
    integer i;
    assign row_select = rst_n ? (6'b000001 << row) : 6'b000000;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row <= 0; count <= 0; raw <= 0; keys <= 0; frame_valid <= 0;
            sync_a <= 4'b1111; sync_b <= 4'b1111;
            for(i=0;i<24;i=i+1) stable_count[i] <= 0;
        end else begin
            sync_a <= columns_n; sync_b <= sync_a;
            frame_valid <= 0;
            if(count == ROW_CYCLES-1) begin
                count <= 0;
                raw[row*4 +: 4] <= ~sync_b;
                if(row == 5) begin
                    row <= 0;
                    completed = {~sync_b,raw[19:0]};
                    frame_valid <= 1;
                    for(i=0;i<24;i=i+1) begin
                        if(completed[i] == keys[i]) stable_count[i] <= 0;
                        else if(stable_count[i] == DEBOUNCE_FRAMES-1) begin
                            keys[i] <= completed[i]; stable_count[i] <= 0;
                        end else stable_count[i] <= stable_count[i]+1'b1;
                    end
                end else row <= row+1'b1;
            end else count <= count+1'b1;
        end
    end
endmodule
