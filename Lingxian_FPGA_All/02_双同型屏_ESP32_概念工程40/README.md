# 双同型触摸屏＋ESP32：假设性FPGA概念工程40

重要：这是按用户指定假设制作的概念代码，不是现有实物的硬件描述，也不是外部控制器所有功能已完整迁入FPGA的交付。不可用于提交实物验证结论或直接烧录。

## 假设

- 两块屏均为320×240横屏SPI LCD（ILI9341兼容），每块独立使用FT6x36 I²C触摸。
- ESP32是外置无线网桥，运行匹配下述串口协议的固件。
- FPGA参考时钟50MHz，I/O电平、可用引脚和实际屏幕初始化尚未核对。

## 实际包含的HDL

- 新顶层：rtl/fpga_dual_screen_concept40.v。
- 第一屏复用现有工作台的显示、触摸和音轨操作。
- 第二屏增加独立触摸读取器、复位/故障重启逻辑、演奏控制和流式显示。
- performance_control39将校准后横屏坐标转换为24位键位与增益，含钢琴/风琴、吉他弦品、鼓垫、和弦接口及掉点保护。本概念顶层固定钢琴偏移为0、和弦接口为关闭，未移植原屏完整音域拖动等全部UI。
- 第二屏的本地触摸控制可直接进入FPGA实时合成链路。没有通过外部控制器转发第二屏按键。
- performance_pixels40为简化键盘/弦品/鼓垫界面，不是原外部屏UI的逐像素等价移植。
- 当前第二屏显示按状态变化进行整屏更新，只是功能概念，尚未优化高亮刷新速度。
- 32声部、混音、效果、四轨、旋钮和LED等复用Tang37 HDL。

## ESP32接口合同，不是已完成的WiFi实现

FPGA输入ESP32_RX连接ESP32的TX；FPGA输出ESP32_TX连接ESP32的RX。串口115200、8N1。
演奏控制帧共8字节：A5 5A instrument keys[7:0] keys[15:8] keys[23:16] gain XOR(bytes0..6)。instrument为0钢琴、1吉他、2风琴、3鼓。
复用的接收器还接受原0x40—0x44曲谱暂存/提交/播放控制帧，具体校验见smart_uart.v与smart_guide.v。
本包没有ESP32网桥固件，也没有实现ESP-AT启动、+IPD解帧、手机LX帧CRC/服务回复与原App的完整适配。不能把ESP32换成任意出厂固件就期待原App直接可用。
原外部Flash的双页曲谱保存也没有移植；FPGA RAM中的数据不等于断电保存。

## 已完成的检查

1. 继承的演奏映射模块与原算法19514组差分向量结果一致，见sim/result.log与performance_vectors.txt。
2. 概念顶层可由Icarus展开编译；tb_dual_screen_concept40验证了第二屏触摸帧→键位/增益→现有合成器PCM、独立工作台状态及松手。
3. tb_performance_pixels40验证基础钢琴/吉他/鼓垫活动像素。
这些都是软件仿真，不是硬件实测。顶层测试使用受控触摸帧刺激，不证明真实屏幕电气通信或ESP32联网通过。

## 没有提供的内容

- 没有新的Gowin管脚约束、布局布线、时序通过报告、资源占用结果或FS码流。
- reference中的CST只供理解旧37版，不能用于本概念顶层新增接口。
- 没有宣称双屏实物接线完成、全功能迁移完成、App/WiFi可用、全链路延迟或接口合规通过。

## 本地仿真示例

在工程根目录运行iverilog -g2012 -s tb_dual_screen_concept40 -o sim/test.vvp -c files.f sim/tb_dual_screen_concept40.v，再运行vvp sim/test.vvp。
差分向量测试需在sim目录运行，使performance_vectors.txt可以被读到。
