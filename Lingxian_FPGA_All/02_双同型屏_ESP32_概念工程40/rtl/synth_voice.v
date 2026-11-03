// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Independent frequency, phase and ADSR for one voice.
module synth_voice (
    input wire clk, input wire rst_n, input wire sample_tick,
    input wire gate, input wire [31:0] phase_step,
    input wire trigger,
    input wire triangle_timbre,
    output reg signed [15:0] sample,
    output wire active
);
    reg [31:0] phase;
    reg previous_gate, timbre_latched;
    wire [15:0] envelope;
    wire [2:0] envelope_state;
    adsr_envelope envelope_unit (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .gate(gate), .trigger(trigger),
        .level(envelope), .active(active), .state(envelope_state)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0; previous_gate <= 0; timbre_latched <= 0;
        end else if (sample_tick) begin
            previous_gate <= gate;
            // Latch timbre on note-on. Do not introduce waveform jumps mid-note.
            if (gate && (!previous_gate || trigger)) timbre_latched <= triangle_timbre;
            // Keep phase continuous during retrigger; reset only when idle.
            if (!active && !gate) phase <= 0;
            else phase <= phase + phase_step;
        end
    end
    wire signed [12:0] sine_sample;
    sine_lut wave_rom (.address(phase[31:24]), .value(sine_sample));
    wire [11:0] folded = phase[31] ? ~phase[30:19] : phase[30:19];
    wire signed [12:0] triangle_sample = $signed({1'b0, folded}) - 13'sd2048;
    wire signed [12:0] wave = timbre_latched ? triangle_sample : sine_sample;
    // Explicit signed positive extension of the unsigned envelope.
    reg signed [29:0] product;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin product <= 0; sample <= 0; end
        else begin
            product <= wave * $signed({1'b0, envelope});
            sample <= product >>> 16;
        end
    end
endmodule
