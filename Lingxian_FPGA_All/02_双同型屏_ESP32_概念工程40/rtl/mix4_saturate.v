// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module mix4_saturate (
    input wire clk, input wire rst_n,
    input wire signed [15:0] voice0, voice1, voice2, voice3,
    output reg signed [15:0] sample
);
    // 18 bits hold the sum of four signed 16-bit samples without overflow.
    wire signed [17:0] sum = {{2{voice0[15]}},voice0}
                           + {{2{voice1[15]}},voice1}
                           + {{2{voice2[15]}},voice2}
                           + {{2{voice3[15]}},voice3};
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sample <= 0;
        else if (sum > 18'sd32767) sample <= 16'sh7fff;
        else if (sum < -18'sd32768) sample <= 16'sh8000;
        else sample <= sum[15:0];
    end
endmodule
