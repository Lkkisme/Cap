# Cap 中文版

Cap 中文版是基于 [Cap 官方项目](https://github.com/CapSoftware/Cap) 汉化和调整的开源屏幕录制工具。本仓库当前重点整理了 Windows 可下载发布、代码签名、SmartScreen 声誉建立和发布验证流程。

仓库地址：[https://github.com/Lkkisme/Cap](https://github.com/Lkkisme/Cap)

## 当前状态

- GitHub 仓库：公开仓库
- 主要发布目标：Windows x64
- 下载入口：[GitHub Releases](https://github.com/Lkkisme/Cap/releases)
- 当前已生成过的公开 Release：[cap-v0.4.3-cn](https://github.com/Lkkisme/Cap/releases/tag/cap-v0.4.3-cn)
- 当前 `cap-v0.4.3-cn` 的 Windows EXE/MSI 尚未签名，因此 Windows SmartScreen 仍可能提示

Windows 用户下载 Release 里的 `windows-x64.exe` 或 `windows-x64.msi` 即可安装，不需要安装 Node.js、Rust、pnpm 或开发环境。

## Windows SmartScreen 说明

SmartScreen 不能靠项目配置强行关闭。微软当前机制主要看下载来源、文件 hash、发布者签名和发布者声誉。要减少 SmartScreen 警告，需要走正规信任链路：

1. 使用 Microsoft Store 发布，这是最接近普通用户无警告安装的方式。
2. 使用 Azure Artifact Signing、SignPath 或代码签名证书签名 Windows EXE/MSI，并确保签名带可信时间戳。
3. 保持同一个发布者身份、同一个官方下载入口和稳定的 Release 文件。
4. 如果签名后仍被误拦截，把签名后的安装包提交到 Microsoft WDSI 复核。

详细操作文档见 [docs/windows-smartscreen.md](docs/windows-smartscreen.md)。

## 我做出的主要改动

### 1. Windows Release 发布链路

- 新增并调整 `.github/workflows/release-desktop.yml`，现在 workflow 名称为 `Windows Release`。
- Release 构建矩阵已收窄到 Windows x64：`x86_64-pc-windows-msvc`。
- Windows Release 只产出 Windows 安装包，不再把 macOS DMG 作为本目标的一部分。
- Release 产物会收集 NSIS `.exe` 和 MSI `.msi`。
- Release 会生成 `SHA256SUMS.txt`，方便用户校验下载文件。
- Release 会生成 GitHub artifact attestations，用于证明产物来自本仓库 GitHub Actions 构建。
- Release 文案已更新为 Windows 下载说明。
- 已公开的 `cap-v*` Release 不允许被同一个 workflow 覆盖；如果安装包需要重发，必须创建新的 tag。
- 旧的 `publish` workflow 已禁用，避免绕过 Windows 签名检查发布安装包。
- GitHub Release 安装包使用离线 WebView2 安装模式，减少新电脑或离线环境缺少 WebView2 时的安装失败。

### 2. Windows 代码签名支持

Release workflow 已支持三种 Windows 签名方式：

- `azure-artifact-signing`：使用 Azure Artifact Signing 在 GitHub Actions 中签名。
- `signpath`：把 Windows 主程序/DLL 和 EXE/MSI 安装包提交给 SignPath 签名。
- `pfx`：使用已有 PFX 代码签名证书和 `signtool.exe` 签名。

签名链路覆盖两层文件：

- 主程序和 DLL。
- 最终上传到 GitHub Release 的 EXE/MSI 安装包。

主程序/DLL 和安装包签名完成后，workflow 会用 `Get-AuthenticodeSignature` 验证签名状态、可信时间戳和证书发布者，并用 Windows SDK `signtool verify /pa /tw` 复核；签名无效、缺少时间戳、发布者不匹配或 SignTool 验证失败都会直接失败。

### 3. Windows 签名配置检查

- 新增 `.github/workflows/windows-signing-check.yml`。
- 新增 `scripts/validate-windows-signing.ps1`。
- 新增 `scripts/validate-windows-app-metadata.ps1`。
- 配置签名前可以先手动运行 `Windows Signing Check`，它会检查 GitHub Variables 和 Secrets 是否齐全。
- `Windows Signing Check`、`Windows Release` 和 `Windows Store Package` 都会检查 Windows 包元数据、签名证书发布者模式和离线 WebView2 配置，避免公开安装包带着占位 publisher、错误签名身份、`authors = ["you"]` 或依赖在线 WebView2 bootstrapper。
- `Windows Release` 默认要求 Windows Authenticode 签名；通过 `cap-v*` tag 触发的正式发布不能关闭签名要求。
- 手动运行 `Windows Release` 时，只有把 `require_signing` 显式设置为 `false`，才会允许生成未签名草稿测试包；未签名构建不能创建公开 Release。

### 4. Microsoft Store 准备

- 新增 `.github/workflows/windows-store-package.yml`。
- 新增 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`。
- `apps/desktop/src-tauri/tauri.conf.json` 已固定 `bundle.publisher`、homepage、license、description 和稳定 MSI `upgradeCode`。
- `apps/desktop/src-tauri/Cargo.toml` 已移除 `authors = ["you"]` 占位值，改为稳定发布者元数据。
- Store workflow 会生成适合 Microsoft Store 提交的 Windows 离线安装包。
- Release 和 Store 配置都使用离线 WebView2 安装模式，减少用户机器缺少 WebView2 时的安装问题。
- Store 产物同样支持签名、可信时间戳验证、SHA256 和 artifact attestation。

### 5. 发布后验证和 WDSI 提交流程

- 新增 `.github/workflows/windows-release-audit.yml`。
- 新增 `.github/workflows/windows-installer-smoke-test.yml`。
- 新增 `.github/workflows/windows-wdsi-package.yml`。
- 新增 `scripts/verify-windows-release.ps1`。
- 新增 `scripts/scan-windows-assets.ps1`。
- 新增 `scripts/new-wdsi-submission-package.ps1`。
- 新增 `scripts/test-windows-authenticode.ps1`。
- 新增 `scripts/test-windows-installers.ps1`。
- `Windows Release Audit` 会在 `cap-v*` Release published 后自动审计，也可以手动对指定 Release tag 执行审计。
- `Windows Installer Smoke Test` 会下载已签名 Release，审计签名/checksum/attestation 后测试 EXE/MSI 静默安装和卸载。
- `Windows WDSI Package` 可以为已签名、已审计的 Release 生成微软复核材料包。
- `Windows Release` 和 `Windows Store Package` 会在上传产物前用 Microsoft Defender 扫描 Windows EXE/MSI。
- 脚本可以下载指定 GitHub Release 的 Windows EXE/MSI。
- 脚本会计算 SHA256。
- 脚本可以核对 Release 中的 `SHA256SUMS.txt`。
- 脚本可以用 GitHub CLI 验证 artifact attestation，确认安装包来自本仓库 GitHub Actions 构建。
- 脚本会检查 Authenticode 签名状态、可信时间戳和 `signtool verify /pa /tw` 结果。
- 脚本支持用正则检查 Authenticode 发布者名称。
- 脚本会生成 `.release-verification/<tag>/windows-smartscreen-report.md`。
- 脚本会生成每个 EXE/MSI 对应的 WDSI 提交说明文本和证据文件。
- 文档中加入了 Microsoft WDSI 提交说明和可复制的开发者说明模板。

### 6. WinGet 分发准备

- 新增 `.github/workflows/windows-winget-manifest.yml`。
- 新增 `scripts/generate-winget-manifest.ps1`。
- `Windows WinGet Manifest` 会先审计 Release 签名、可信时间戳、SignTool 复核和 SHA256，再生成 WinGet manifest。
- 默认生成 `Lkkisme.CapCN` 的 Windows x64 MSI manifest。
- 生成器会下载安装包并按 `SHA256SUMS.txt` 复核 hash；MSI manifest 会写入静默安装参数、`ProductCode`、固定 `UpgradeCode` 和 Add/Remove Programs 升级身份，EXE manifest 会写入 NSIS 静默安装参数。
- 生成的文件位于 `packaging/winget/manifests/...`，可用于提交到 `microsoft/winget-pkgs`。
- WinGet 不能替代代码签名或 Store，但它可以提供更标准的 Windows 包管理器安装入口。

### 7. CI 和 Windows 构建稳定性

- CI 的 Windows runner 固定为 `windows-2022`，避免 `windows-latest` 切换到更新系统镜像后带来的 FFmpeg/bindgen 不稳定问题。
- Rust cache job 安装 `clippy` component，避免 macOS/Windows cache 流程在 Clippy 步骤缺组件。
- 修复了 Windows Clippy 中的 dead code 问题，让 macOS 专用 FFmpeg helper 只在 macOS 编译。
- 修复了 desktop Rust 代码里的 Clippy 警告。
- 修复了当前语言 accessor 的调用方式。
- 保留了仓库 workspace lints 的严格设置，不通过 `allow(dead_code)` 这类豁免绕过问题。

### 8. SmartScreen 文档

- 新增 [docs/windows-smartscreen.md](docs/windows-smartscreen.md)。
- 文档说明了 Microsoft Store、Azure Artifact Signing、SignPath、PFX/signtool、WDSI 的适用场景。
- 文档列出了需要配置的 GitHub Variables 和 Secrets。
- 文档说明了现实预期：签名能建立发布者信任，但新发布者或新文件仍可能短期出现 SmartScreen 提示。
- 文档明确说明 EV 证书已经不再保证自动绕过 SmartScreen。

## 需要你继续配置的内容

代码和 workflow 已经准备好，但真正减少 SmartScreen 还需要一个可信发布者身份。推荐优先选择：

### 方案 A：Microsoft Store

1. 注册 Microsoft Partner Center。
2. 创建 `EXE or MSI app`。
3. 运行 `Windows Store Package` workflow。
4. 上传 workflow 生成的 Windows 安装包。
5. 提交审核。

### 方案 B：Azure Artifact Signing

在 GitHub 仓库 Variables 中配置：

| Name | Example |
| --- | --- |
| `WINDOWS_SIGNING_PROVIDER` | `azure-artifact-signing` |
| `WINDOWS_PACKAGE_PUBLISHER` | Optional, defaults to `Lkkisme` |
| `WINDOWS_SIGNING_PUBLISHER_PATTERN` | Regex matching the Authenticode subject, e.g. `Lkkisme` |
| `AZURE_ARTIFACT_SIGNING_ENDPOINT` | `https://eus.codesigning.azure.net/` |
| `AZURE_ARTIFACT_SIGNING_ACCOUNT_NAME` | Azure Artifact Signing account name |
| `AZURE_ARTIFACT_SIGNING_CERTIFICATE_PROFILE_NAME` | Certificate profile name |

在 GitHub 仓库 Secrets 中配置：

| Name | Purpose |
| --- | --- |
| `AZURE_CLIENT_ID` | Microsoft Entra app registration client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

配置完成后：

1. 手动运行 `Windows Signing Check`。
2. 确认通过。
3. 手动运行 `Windows Release` 或创建新的 `cap-v*` tag；正式发布保持 `require_signing=true`，未签名测试只能作为 draft。
4. 等待自动触发的 `Windows Release Audit` 通过，或手动输入刚发布的 tag 重新审计，确认签名发布者、可信时间戳、SignTool 复核、SHA256 和 artifact attestation 都通过。
5. 手动运行 `Windows Installer Smoke Test`，确认 EXE/MSI 可以静默安装和卸载。
6. 如需 WinGet 分发，手动运行 `Windows WinGet Manifest`，下载生成的 manifest，运行 `winget validate`，再提交到 `microsoft/winget-pkgs`。
7. 下载 EXE/MSI，用 `Get-AuthenticodeSignature` 确认签名为 `Valid`，并确认存在 `TimeStamperCertificate`。
8. 如仍出现 SmartScreen 误拦截，运行 `Windows WDSI Package`，再把安装包和生成的说明文本提交到 Microsoft WDSI。

### 方案 C：SignPath 或 PFX

如果你已经有 SignPath 账号或 PFX 代码签名证书，可以按 [docs/windows-smartscreen.md](docs/windows-smartscreen.md) 配置对应 Secrets，然后运行 `Windows Signing Check` 和 `Windows Release`。

## 本地开发

```bash
pnpm install
pnpm env-setup
pnpm cap-setup
pnpm dev:desktop
```

构建 Windows 桌面应用：

```bash
pnpm tauri:build
```

## 技术栈

- Tauri v2
- Rust
- SolidStart
- Next.js
- TypeScript
- Turborepo
- pnpm

## 许可证

本项目基于原项目许可证继续分发。详细信息见 [LICENSE](LICENSE)。

## 相关链接

- 原始 Cap 项目：[https://github.com/CapSoftware/Cap](https://github.com/CapSoftware/Cap)
- 本仓库：[https://github.com/Lkkisme/Cap](https://github.com/Lkkisme/Cap)
- Windows SmartScreen 文档：[docs/windows-smartscreen.md](docs/windows-smartscreen.md)
