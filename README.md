<p align="center">
  <p align="center">
   <img width="150" height="150" src="./apps/desktop/src-tauri/icons/Square310x310Logo.png" alt="Logo">
  </p>
	<h1 align="center"><b>Cap 中文版</b></h1>
	<p align="center">
		开源屏幕录制工具，基于原项目汉化并优化
    <br />
    <a href="https://github.com/Lkkisme/Cap"><strong>GitHub 仓库 »</strong></a>
    <br />
    <br />
    <b>支持平台：</b>
		macOS & Windows
    <br />
  </p>
</p>
<br/>

## 📖 项目简介

Cap 中文版是基于 <a href="https://github.com/CapSoftware/Cap">Cap 官方项目</a> 进行汉化和优化的开源屏幕录制工具，是 Loom 的开源替代方案。它允许您在几秒钟内录制、编辑和分享视频。

## ✨ 主要特性

- **完全汉化**：界面和功能说明已全部汉化，提供更友好的中文用户体验
- **移除登录限制**：无需登录即可使用所有功能
- **去除付费板块**：所有功能完全免费使用
- **同步官方版本**：已同步官方 0.4.3 版本
- **编辑器优化**：优化了视频编辑功能，使用更流畅
- **多平台支持**：支持 macOS 和 Windows 系统

## 📸 界面预览

### 首页
<img src="./UI界面/首页.png" alt="首页" width="800" />

### 编辑器页面
<img src="./UI界面/编辑器页面.png" alt="编辑器页面" width="800" />

### 设置页面
<img src="./UI界面/设置页面.png" alt="设置页面" width="800" />

## 🚀 安装使用

### 方法一：直接运行
1. 打开 <a href="https://github.com/Lkkisme/Cap/releases">GitHub Releases</a>
2. Windows 下载 `windows-x64.exe` 或 `windows-x64.msi`
3. Apple Silicon Mac 下载 `macos-arm64.dmg`
4. Intel Mac 下载 `macos-x64.dmg`
5. 安装后直接运行，无需安装 Node.js、Rust、pnpm 或其他开发环境

> 当前发布包未配置商业代码签名。Windows 可能出现 SmartScreen 提示，macOS 可能需要在系统设置中允许打开。

### 方法二：源码构建
```bash
# 克隆仓库
git clone https://github.com/lid664951-crypto/Cap.git
cd Cap

# 安装依赖
pnpm install

# 构建桌面应用
pnpm tauri:build

# 运行开发版本
pnpm dev:desktop
```

## 🛠️ 技术栈

- **前端**：React (Next.js)、TypeScript、SolidStart、TailwindCSS
- **后端**：Rust、Tauri、Drizzle (ORM)、MySQL
- **构建工具**：Turborepo

## 📄 许可证

本项目基于原项目的许可证进行分发：

- `cap-camera*` 和 `scap-*` 系列代码使用 MIT 许可证
- 第三方组件使用其原始许可证
- 其他内容使用 AGPLv3 许可证

详细信息请查看 [LICENSE](LICENSE) 文件。

## 🔗 相关链接

- **官方项目**：<a href="https://github.com/CapSoftware/Cap">https://github.com/CapSoftware/Cap</a>
- **本项目**：<a href="https://github.com/Lkkisme/Cap">https://github.com/Lkkisme/Cap</a>

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目！

## 📞 联系方式

如有问题或建议，请在 GitHub 仓库中提交 Issue。
