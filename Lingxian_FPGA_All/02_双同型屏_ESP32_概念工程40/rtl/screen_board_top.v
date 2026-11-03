`timescale 1ns/1ps
// Board wrapper hides diagnostic pins and de-selects the screen SD socket.
module screen_board_top #(parameter TEST_MODE=0,STANDARD_I2S=0,AUTO_LOOP=0)(input wire sys_clk,rst_button_n,play_button_n,mode_button_n,
 output wire [7:0] LED_N,
 input wire MIC_DO,
 input wire HOST_RX,output wire HOST_TX,
 inout wire CTP_SCL,CTP_SDA,output wire CTP_RST,
 output wire LCD_SCK,LCD_MOSI,LCD_RS,LCD_CS,LCD_RST,SD_CS,
 output wire HP_BCK,HP_WS,HP_DIN,PA_EN);
 wire healthy;wire [3:0] active;
 assign SD_CS=1'b1;
  touch_piano_top #(.TEST_MODE(TEST_MODE),.STANDARD_I2S(STANDARD_I2S),.AUTO_LOOP(AUTO_LOOP)) core(.MIC_DO(MIC_DO),.LED_N(LED_N),.HOST_RX(HOST_RX),.HOST_TX(HOST_TX),.sys_clk(sys_clk),.rst_button_n(rst_button_n),
   .play_button_n(play_button_n),.mode_button_n(mode_button_n),
   .CTP_SCL(CTP_SCL),.CTP_SDA(CTP_SDA),.CTP_RST(CTP_RST),
   .LCD_SCK(LCD_SCK),.LCD_MOSI(LCD_MOSI),.LCD_RS(LCD_RS),.LCD_CS(LCD_CS),.LCD_RST(LCD_RST),
   .HP_BCK(HP_BCK),.HP_WS(HP_WS),.HP_DIN(HP_DIN),.PA_EN(PA_EN),.touch_healthy(healthy),.voice_active(active));
endmodule
