# 灵弦 · 复现与目录说明

## 正式 FPGA 工程

工作目录为 `Lingxian_FPGA_All/01_Tang37_现有FPGA完整工程`。工程器件是 GW5AT-60B / `GW5AT-LV60PG484AC1/I0`，原报告工具为 Gowin V1.9.11.03 Education。

```powershell
cd Lingxian_FPGA_All/01_Tang37_现有FPGA完整工程
.\build.ps1 -Gowin 'D:/Gowin/IDE/bin/gw_sh.exe' -BuildDirectory 'D:/FPGA/lingxian_build'
```

将工具路径替换为自己的安装目录。脚本为每次构建创建独立工作目录，选择 `studio_board_top`，完成综合、布局布线，并检查报告中的 Setup / Hold 违例是否为 0；通过后复制码流到 `download/music_perform.fs`。`-Test32` 选择独立 32 音测试顶层 `contest_spectrum_top`。

GUI 打开 `FPGA/screen_board.gprj` 时，应在配置中确认顶层为 `studio_board_top`，并参考 `FPGA/impl/screen_board_process_config.json`。工程内存在其他历史 / 测试顶层，不能仅凭文件名选择。

### Icarus 仿真

原 PowerShell 运行器使用带 `bin`、`lib/ivl` 目录的 Icarus `Library` 目录：

```powershell
.\FPGA\sim\run.ps1 -IcarusLibrary 'C:/tools/iverilog/Library'
```

默认回归项目由 `run.ps1` 定义，输出至 `FPGA/sim/results`。本目录中的测试台多于默认回归集合，可通过 `-Testbenches` 指定。原已归档的 6 项发布测试在 `reports/sim`，不应将“测试台存在”等同于“全部测试已通过”。

### 烧录与连接

- 使用 `FPGA/src/screen_board.cst` 对应的原硬件引脚与电平。
- 外部演奏 / 曲谱控制通过 `HOST_RX/HOST_TX`，该外部控制器固件不在此仓库。
- 当前正式音频输出为 PT8211 的 LSBJ 格式；不能按标准 I²S 引脚时序直接替换 DAC。
- 工作台屏幕与触摸、主音量编码器、麦克风门控和 LED 的连接见正式顶层和 CST。
- 四轨事件存于 RAM；断电、复位或重新配置会丢失。
- `download/music_perform.fs` 与归档 `FPGA/impl/pnr/screen_board.fs` 内容一致。

## 演奏控制核心与双屏概念工程

独立核心测试必须在 `03_演奏控制HDL迁移与对照测试/sim` 中执行，以读取向量文件：

```powershell
iverilog -g2012 -s tb_performance_control39 -o test.vvp ../rtl/performance_control39.v tb_performance_control39.v
vvp test.vvp
```

双屏概念顶层测试在 `02_双同型屏_ESP32_概念工程40` 中执行：

```powershell
iverilog -g2012 -s tb_dual_screen_concept40 -o sim/test.vvp -c files.f sim/tb_dual_screen_concept40.v
vvp sim/test.vvp
```

概念工程假设两块 320 × 240 SPI LCD 与独立 FT6x36 触摸，以及一个实现匹配串口协议的 ESP32 网桥。尚无适配新硬件的引脚约束、布局布线报告或码流；ESP32 固件、App 完整协议适配及断电保存未实现。`reference` 中旧版 CST 仅供参考。

## Android App 与 Web 界面

工作目录为 `Lingxian_FPGA_All/04_Android_App_34`。

```powershell
# Web 构建与协议测试，需要 Node.js
node tools/build_web.mjs
node --test tests/protocol.test.mjs

# APK 构建，需要 JDK 17、Android SDK / Build Tools 与 API 35
$env:LINGXIAN_ANDROID_SDK = 'C:/Android/sdk'
python tools/build_apk.py
```

App 最低 Android 8.0 / API 26，target API 35。这是 Java / DEX / APK 脚本流程，未提供 Gradle 模板。

原私有演示签名未公开。脚本首次构建会在 `.signing/local-demo.jks` 生成新的本地演示密钥，目录已被 Git 忽略。新密钥签出的 APK 无法直接覆盖不同签名的已安装版本，应先处理原安装与必要数据。

`tests/ui.test.mjs` 是原环境的浏览器检查脚本，包含其 Playwright 工具位置与 Windows Chrome 路径；在其他环境运行需要调整这些路径。`tests/cross_c.py` 依赖未收录的外部 C 参考实现。它们的原始记录保留在 `reports`，不代表在任意新环境可直接执行。

原 App 使用配套无线控制链路；概念 40 不会自动获得这条链路的协议适配。脱离硬件时，可打开 `dist/quick-open.html`，选择模拟设备体验页面交互。

## 本地预览作品主页

```powershell
python -m http.server 8080 --directory docs
```

浏览器访问 `http://localhost:8080`。页面无需 npm 或前端构建，使用原生 HTML / CSS / JavaScript，视频默认从 GitHub Release 加载。

## 校验文件

公开包中的 SHA256 清单针对各自目录的公开文件重新生成，排除校验清单本身与私有签名 / 缓存。`Lingxian_FPGA_All/ALL_FILES_SHA256.json` 汇总整个公开代码包。Release 另附下载文件的 `SHA256SUMS.txt`。
