`timescale 1ns/1ps
module contest_spectrum_top(input wire sys_clk,rst_button_n,play_button_n,mode_button_n,
 input wire MIC_DO,
 input wire HOST_RX,output wire HOST_TX,output wire [7:0] LED_N,
 inout wire CTP_SCL,CTP_SDA,output wire CTP_RST,
 output wire LCD_SCK,LCD_MOSI,LCD_RS,LCD_CS,LCD_RST,SD_CS,
 output wire HP_BCK,HP_WS,HP_DIN,PA_EN);
 screen_board_top #(.TEST_MODE(1)) test(
 .sys_clk(sys_clk),.rst_button_n(rst_button_n),.play_button_n(play_button_n),.mode_button_n(mode_button_n),
 .MIC_DO(MIC_DO),.HOST_RX(HOST_RX),.HOST_TX(HOST_TX),.LED_N(LED_N),.CTP_SCL(CTP_SCL),.CTP_SDA(CTP_SDA),.CTP_RST(CTP_RST),
 .LCD_SCK(LCD_SCK),.LCD_MOSI(LCD_MOSI),.LCD_RS(LCD_RS),.LCD_CS(LCD_CS),.LCD_RST(LCD_RST),.SD_CS(SD_CS),
 .HP_BCK(HP_BCK),.HP_WS(HP_WS),.HP_DIN(HP_DIN),.PA_EN(PA_EN));
endmodule
