// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Board-independent integration. No physical pins, power or reset assumptions.
// reset must already assert asynchronously / release synchronously at board top.
module keyboard_audio_logic #(
    parameter integer ROW_CYCLES=2500,
    parameter integer DEBOUNCE_FRAMES=3,
    parameter integer ADC_HALF_CYCLES=25,
    parameter integer ADC_GAP_CYCLES=100,
    parameter [6:0] BASE_NOTE=7'd48 // TEMP: row-major mapping, C3..B4
) (
    input wire clk, input wire rst_n,
    input wire [3:0] columns_n,
    output wire [5:0] row_select,
    input wire adc_miso,
    output wire adc_sck,output wire adc_mosi,output wire [1:0] adc_cs_n,
    input wire triangle_timbre,
    output wire bck,output wire ws,output wire din,
    output wire [23:0] keys,
    output wire [3:0] voice_active,
    output wire [159:0] adc_values,
    output wire adc_sample_valid,
    output wire overflow
);
    wire frame_valid,sweep_valid;
    wire [3:0] adc_channel;
    wire [9:0] adc_value;
    key_matrix_6x4 #(.ROW_CYCLES(ROW_CYCLES),.DEBOUNCE_FRAMES(DEBOUNCE_FRAMES)) keyboard (
        .clk(clk),.rst_n(rst_n),.columns_n(columns_n),.row_select(row_select),
        .keys(keys),.frame_valid(frame_valid));
    mcp3008_scan16 #(.HALF_CYCLES(ADC_HALF_CYCLES),.GAP_CYCLES(ADC_GAP_CYCLES)) adc (
        .clk(clk),.rst_n(rst_n),.miso(adc_miso),.sck(adc_sck),.mosi(adc_mosi),
        .cs_n(adc_cs_n),.values(adc_values),.sample_valid(adc_sample_valid),
        .sampled_channel(adc_channel),.sampled_value(adc_value),.sweep_valid(sweep_valid));
    wire sample_tick;
    wire [3:0] gates,triggers;
    wire [19:0] owners;
    voice_allocator4 allocate (.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .keys(keys),.gates(gates),.triggers(triggers),.owners(owners),.overflow(overflow));
    wire [31:0] step0,step1,step2,step3;
    // The actual 7-white/5-black matrix->pitch mapping must replace this table
    // after the PCB owner confirms all 24 physical key positions.
    note_phase_step f0 (.note(BASE_NOTE+{2'b00,owners[4:0]}),.step(step0));
    note_phase_step f1 (.note(BASE_NOTE+{2'b00,owners[9:5]}),.step(step1));
    note_phase_step f2 (.note(BASE_NOTE+{2'b00,owners[14:10]}),.step(step2));
    note_phase_step f3 (.note(BASE_NOTE+{2'b00,owners[19:15]}),.step(step3));
    wire signed [15:0] sample;
    poly4_core engine (.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .gates(gates),.triggers(triggers),.step0(step0),.step1(step1),.step2(step2),.step3(step3),
        .triangle_timbre(triangle_timbre),.sample(sample),.active(voice_active));
    pt8211_tx dac (.clk(clk),.rst_n(rst_n),.sample_left(sample),.sample_right(sample),
        .sample_tick(sample_tick),.bck(bck),.ws(ws),.din(din));
endmodule
