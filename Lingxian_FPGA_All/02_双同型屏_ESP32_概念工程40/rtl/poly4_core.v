// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module poly4_core (
    input wire clk, input wire rst_n, input wire sample_tick,
    input wire [3:0] gates,
    input wire [3:0] triggers,
    input wire [31:0] step0, step1, step2, step3,
    input wire triangle_timbre,
    output wire signed [15:0] sample,
    output wire [3:0] active
);
    wire signed [15:0] v0, v1, v2, v3;
    synth_voice voice0 (.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .gate(gates[0]),.trigger(triggers[0]),.phase_step(step0),.triangle_timbre(triangle_timbre),.sample(v0),.active(active[0]));
    synth_voice voice1 (.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .gate(gates[1]),.trigger(triggers[1]),.phase_step(step1),.triangle_timbre(triangle_timbre),.sample(v1),.active(active[1]));
    synth_voice voice2 (.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .gate(gates[2]),.trigger(triggers[2]),.phase_step(step2),.triangle_timbre(triangle_timbre),.sample(v2),.active(active[2]));
    synth_voice voice3 (.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .gate(gates[3]),.trigger(triggers[3]),.phase_step(step3),.triangle_timbre(triangle_timbre),.sample(v3),.active(active[3]));
    mix4_saturate mixer (.clk(clk),.rst_n(rst_n),.voice0(v0),.voice1(v1),
        .voice2(v2),.voice3(v3),.sample(sample));
endmodule
