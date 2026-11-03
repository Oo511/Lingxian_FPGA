# 灵弦 FPGA 独立工程 · Tang37

本包只包含高云FPGA工程：HDL源码、Gowin工程配置、引脚/时序约束、波表资源、仿真测试、发布固件和验证报告。
不包含外部控制器固件、手机App或它们的源码。本包对应已发布的Tang37，没有为打包修改HDL或码流。

## 入口

- 工程：FPGA/screen_board.gprj
- 顶层：FPGA/src/studio_board_top.v，模块studio_board_top
- 引脚约束：FPGA/src/screen_board.cst
- 时序约束：FPGA/src/timing.sdc，50MHz/20ns
- 固件：download/music_perform.fs，与FPGA/impl/pnr/screen_board.fs一致
- 仿真：FPGA/sim/run.ps1，可用-IcarusLibrary指定Icarus安装目录
- 构建：build.ps1，可用-Gowin和-BuildDirectory指定本机工具及构建路径

## FPGA内实现

32独立声部实时合成、ADSR包络、多级混音、滑音/颤音、鼓声生成、混响/延迟/合唱、四轨事件循环叠录、轨道音色切换、主音量编码器、控制屏显示/触摸、麦克风门控及LED曲目指引。
外部演奏控制通过HOST_RX/HOST_TX接口传输。省略外部控制器源码不代表对应采集与无线功能已迁入FPGA。若脱离原外部模块使用，需要另行提供兼容的控制输入。

## 验证与使用

原发布报告：50MHz下建立/保持违例均为0，静态时序Fmax60.986MHz。六项针对性仿真记录保留在reports/sim。
实际音频输出为PT8211的LSBJ格式；标准i2s_tx模块随源码提供，但当前顶层实际连接pt8211_tx。
重新下载或复位Tang会清空四轨RAM录音。没有新增硬件迁移、实测延迟或实机验收结论。
GNU/第三方模块原有许可证和署名随源码保留。
