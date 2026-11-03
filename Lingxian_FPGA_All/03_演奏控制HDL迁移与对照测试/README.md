# FPGA真实迁移：阶段1演奏控制核心

已实现HDL：钢琴/风琴键位与音域偏移、黑白键、吉他弦品和边界滞回、鼓垫、和弦、候选键稳定、纵向增益、12ms释放保护与毫秒计数回绕。
源文件：rtl/performance_control39.v。
输入frame_valid/pressed、校准后的横屏x/y、now_ms、instrument、piano_offset、chord；输出24位keys、gain和note。
采用常量增益表及比较/状态逻辑，未使用通用乘除法来实现增益转换。

验证：与原演奏控制实现做19514组差分输入对照，keys/gain/note全部一致。覆盖所有音域偏移与多种坐标、连续滑键、松手、和弦及时间回绕；结果在sim/result.log。对照测试数据随包提供，原C参考程序不包含在本交付中。
仿真示例：在sim目录，用Icarus执行iverilog -g2012 -s tb_performance_control39 -o test.vvp ../rtl/performance_control39.v tb_performance_control39.v，再执行vvp test.vvp。

这不是已经完成全部迁移的双屏工程，也没有新码流。触摸ADC读取/滤波/校准、第二屏总线及绘图、WiFi AT与应用协议、曲谱断电保存尚未迁移并集成。本模块尚未接入正式顶层，也未完成综合/布局布线/实机验证。
正式Tang37和原38组合保持不变，不能将此阶段模块当作可直接烧录的固件。

继续双屏迁移需要确认屏幕控制器型号、连接器针号、3.3V电平、原控制器停止驱动方案和WiFi模块实际引出点。详见双屏接口核对.md。
