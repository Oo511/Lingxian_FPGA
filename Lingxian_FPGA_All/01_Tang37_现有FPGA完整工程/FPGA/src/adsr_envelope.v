// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module adsr_envelope #(
    parameter [15:0] ATTACK_STEP = 16'd256,
    parameter [15:0] DECAY_STEP = 16'd64,
    parameter [15:0] SUSTAIN_LEVEL = 16'd32768,
    parameter [15:0] RELEASE_STEP = 16'd16
) (
    input wire clk, input wire rst_n, input wire sample_tick,
    input wire gate,
    input wire trigger,
    output reg [15:0] level,
    output wire active,
    output reg [2:0] state
);
    localparam IDLE=0, ATTACK=1, DECAY=2, SUSTAIN=3, RELEASE=4;
    reg previous_gate;
    wire [16:0] attack_sum = {1'b0, level} + {1'b0, ATTACK_STEP};
    wire [16:0] decay_floor = {1'b0, SUSTAIN_LEVEL} + {1'b0, DECAY_STEP};
    assign active = state != IDLE;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            level <= 0; state <= IDLE; previous_gate <= 0;
        end else if (sample_tick) begin
            previous_gate <= gate;
            if (gate && (!previous_gate || trigger)) begin
                // A retrigger preserves the current level to avoid an abrupt
                // amplitude drop. It returns to the attack stage.
                state <= ATTACK;
            end else if (!gate && previous_gate) begin
                state <= RELEASE;
            end else begin
                case (state)
                    IDLE: level <= 0;
                    ATTACK: begin
                        if (attack_sum >= 17'd65535) begin
                            level <= 16'd65535; state <= DECAY;
                        end else level <= attack_sum[15:0];
                    end
                    DECAY: begin
                        if ({1'b0, level} <= decay_floor) begin
                            level <= SUSTAIN_LEVEL; state <= SUSTAIN;
                        end else level <= level - DECAY_STEP;
                    end
                    SUSTAIN: level <= SUSTAIN_LEVEL;
                    RELEASE: begin
                        if (level <= RELEASE_STEP) begin
                            level <= 0; state <= IDLE;
                        end else level <= level - RELEASE_STEP;
                    end
                    default: begin level <= 0; state <= IDLE; end
                endcase
            end
        end
    end
endmodule
