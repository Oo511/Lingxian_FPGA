# Android App34：源码及构建入口

- 直接安装：dist/Lingxian-Android.apk（原已构建APK，本次未重新编译）。
- 原生壳：app/src/main/java/com/lingxian/practice/MainActivity.java。
- Android配置：app/src/main/AndroidManifest.xml。
- 网页界面与协议：web；构建后网页：dist/web。
- 曲谱资源：web及dist/web中的JSON文件。
- 网页构建：node tools/build_web.mjs。
- APK构建：python tools/build_apk.py；需要JDK17和Android SDK（包含API35），用LINGXIAN_ANDROID_SDK指定SDK位置。
- 测试：tests目录，已有构建/协议/UI检查记录位于reports。
- 公开仓库不提供原私有演示签名密钥；构建脚本首次运行会在.signing/local-demo.jks生成自己的本地演示签名。不同签名的APK不能直接覆盖安装。向最终用户分发只需要APK，私钥应自行保管。

本App并非完整Android Studio/Gradle模板，原项目使用上述Java/DEX/APK脚本构建流程；构建所需系统JDK和SDK不在本包内。
支持现有WiFi联网、曲谱/键位配置与保存读回，实物功能以已验收组合为准。概念40的ESP32网桥并没有在本包中实现，不宣称原App直接兼容任意ESP32固件。
