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
- `Windows Release Audit` 通过后会把 `windows-smartscreen-report-<tag>.md` 和 `windows-release-assets-<tag>.json` 上传到同一个 GitHub Release，方便用户、WinGet/WDSI 准备流程和你自己核验签名、时间戳、checksum、artifact attestation 与 Microsoft Defender 扫描结果。
- Release 文案已更新为 Windows 下载说明。
- 已公开的 `cap-v*` Release 不允许被同一个 workflow 覆盖；如果安装包需要重发，必须创建新的 tag。
- 正式签名 Release 会先创建为 draft，`Windows Release` 主动触发并等待 Release 审计、安装器 smoke test、WinGet manifest 和 WDSI 证据包 workflow；全部通过后才会自动公开，任一失败都会让 Release 保持 draft。
- `Windows Release` 触发的后续证据 workflow 会带上父 run id，避免并发手动重跑时等待到错误的检查结果。
- `Windows Release` 在公开 draft 前会重新读取 GitHub Release 资产，确认 Windows EXE、MSI、`SHA256SUMS.txt`、SmartScreen 审核报告、资产清单、安装器 smoke test 报告、安装器 smoke test JSON 结果、WinGet manifest 包、WinGet 提交说明、WDSI checklist 和 WDSI 提交文本包都已经存在，并再次用 quarantine 脚本校验资产清单内容。
- 旧的 `publish` workflow 已禁用，避免绕过 Windows 签名检查发布安装包。
- GitHub Release 安装包使用离线 WebView2 安装模式，减少新电脑或离线环境缺少 WebView2 时的安装失败。
- Web 下载入口的 Windows 路由已改为优先使用 Microsoft Store；部署时配置 `NEXT_PUBLIC_WINDOWS_STORE_URL`、`WINDOWS_STORE_URL` 或 `CAP_WINDOWS_STORE_URL` 为官方 Microsoft Store HTTPS 详情页或应用页链接后，`/download/windows` 会跳到 Store。未配置 Store 链接时，`/download/windows`、`/download/windows-exe` 和 `/download/windows-msi` 只会直跳同时带 `SHA256SUMS.txt`、当前 tag 对应的 `windows-smartscreen-report-<tag>.md`、`windows-release-assets-<tag>.json`、`windows-installer-smoke-test-report-<tag>.md`、`windows-installer-smoke-test-results-<tag>.json`、`windows-winget-manifest-<tag>.zip`、`windows-winget-submission-<tag>.md`、`windows-wdsi-submission-checklist-<tag>.md` 和 `windows-wdsi-submission-text-<tag>.zip`，并且 `windows-release-assets-<tag>.json` 中每个 Windows 安装包的签名、时间戳、SignTool、checksum、attestation 和 Defender 状态都有效的 Release 资产；没有可信 Windows 包时会进入 `/download/windows-status`，避免把旧的未签名包、未完成审计的包或未通过安装器 smoke test/WinGet/WDSI 材料生成的包作为推荐下载。All Versions 页面也只会给证据齐全且清单内容有效的 Windows Release 展示 EXE/MSI 直链。
- Tauri updater API 已改为读取本仓库 Release；Windows target 在缺少 checksum、SmartScreen audit、安装器 smoke test、WinGet、WDSI 证据或有效 `windows-release-assets-<tag>.json` 清单时返回 204，不再从上游仓库或未验证 Release 提供更新包。

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
- 新增 `.github/workflows/windows-trust-readiness.yml`。
- 新增 `scripts/validate-windows-signing.ps1`。
- 新增 `scripts/validate-windows-app-metadata.ps1`。
- 新增 `scripts/test-windows-trust-readiness.ps1`。
- 配置签名或 Store 前可以先手动运行 `Windows Trust Readiness`，它会生成一份报告，检查 Microsoft Store URL、Partner Center 自动提交凭据、Windows 签名 provider、发布者正则、Windows 发布 workflow、WinGet/WDSI workflow 和最新公开 Release 证据是否齐全；它也会在相关 Windows 信任链文件变更时自动运行，并每周定期检查一次。
- 配置签名前可以先手动运行 `Windows Signing Check`，它会检查 GitHub Variables 和 Secrets 是否齐全，并签名一个临时 Windows EXE 探针，验证 Authenticode 签名、可信时间戳、发布者匹配和 SignTool 结果；配置签名 provider 后，它也会在相关签名文件变更时自动运行，并每周定期签名探针，未配置 provider 时自动运行只做跳过式检查。
- `Windows Signing Check`、`Windows Release` 和 `Windows Store Package` 都会检查 Windows 包元数据、签名证书发布者模式和离线 WebView2 配置，避免公开安装包带着占位 publisher、错误签名身份、`authors = ["you"]` 或依赖在线 WebView2 bootstrapper。
- `Windows Release` 默认要求 Windows Authenticode 签名；通过 `cap-v*` tag 触发的正式发布不能关闭签名要求。
- 手动运行 `Windows Release` 时，只有把 `require_signing` 显式设置为 `false`，才会允许生成未签名草稿测试包；未签名构建不能创建公开 Release。

### 4. Microsoft Store 准备

- 新增 `.github/workflows/windows-store-package.yml`。
- 新增 `.github/workflows/windows-msix-store-package.yml`。
- 新增 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`。
- 新增 `scripts/new-windows-store-submission-package.ps1`。
- 新增 `scripts/new-windows-msix-layout.ps1`。
- 新增 `scripts/test-windows-msix-layout.ps1`。
- `apps/desktop/src-tauri/tauri.conf.json` 已固定 `bundle.publisher`、homepage、license、description 和稳定 MSI `upgradeCode`。
- `apps/desktop/src-tauri/Cargo.toml` 已移除 `authors = ["you"]` 占位值，改为稳定发布者元数据。
- Store workflow 会生成适合 Microsoft Store 提交的 Windows 离线安装包。
- Store workflow 会额外生成 `store-submission-package`，里面包含 Partner Center 可照填的安装包 URL、架构、语言、静默安装参数、SHA256、签名状态和发布者信息。
- `Windows MSIX Store Package` 会用 Microsoft WinApp CLI 生成 MSIX layout、`Package.appxmanifest` 和 Store 用 `.msix` 包，作为 Microsoft Store 直接重新签名路线的优先尝试；配置 Partner Center secrets 后，也可以把生成的 MSIX 直接提交到 Microsoft Store。
- `Windows MSIX Store Package` 会在打包前校验 MSIX layout、package identity、publisher、version、主程序、Store logo、tile logo、splash asset、protocol 和 `runFullTrust` capability，避免把缺图标或 manifest 不完整的包提交到 Store。
- Release 和 Store 配置都使用离线 WebView2 安装模式，减少用户机器缺少 WebView2 时的安装问题。
- Store 产物同样支持签名、可信时间戳验证、SHA256 和 artifact attestation。

### 5. 发布后验证和 WDSI 提交流程

- 新增 `.github/workflows/windows-release-audit.yml`。
- 新增 `.github/workflows/windows-installer-smoke-test.yml`。
- 新增 `.github/workflows/windows-release-quarantine.yml`。
- 新增 `.github/workflows/windows-wdsi-package.yml`。
- 新增 `scripts/verify-windows-release.ps1`。
- 新增 `scripts/scan-windows-assets.ps1`。
- 新增 `scripts/new-wdsi-submission-package.ps1`。
- 新增 `scripts/protect-windows-release-assets.ps1`。
- 新增 `scripts/test-windows-authenticode.ps1`。
- 新增 `scripts/test-windows-installers.ps1`。
- `Windows Release Audit` 会在 `cap-v*` Release published 后自动审计；由 `Windows Release` workflow 创建正式签名 Release 时，会在公开前被主动触发并等待结果。
- `Windows Release Audit` 通过后会把审核报告和 Release 资产清单作为 Release 资产上传，正式签名 Release 在这些证据上传成功后才会从 draft 自动公开。
- `Windows Installer Smoke Test` 通过后会把安装卸载报告和 JSON 结果作为 Release 资产上传。
- `Windows WDSI Package` 通过后会把 WDSI checklist 和提交文本压缩包作为 Release 资产上传，方便 SmartScreen 误拦截时直接提交复核。
- `Windows WinGet Manifest` 通过后会把 WinGet manifest 压缩包和提交说明作为 Release 资产上传，方便后续提交到 `microsoft/winget-pkgs`。
- `Windows Release` 公开前会额外校验 Release 页面上已经带有 EXE、MSI、`SHA256SUMS.txt`、`windows-smartscreen-report-<tag>.md`、`windows-release-assets-<tag>.json`、`windows-installer-smoke-test-report-<tag>.md`、`windows-installer-smoke-test-results-<tag>.json`、`windows-winget-manifest-<tag>.zip`、`windows-winget-submission-<tag>.md`、`windows-wdsi-submission-checklist-<tag>.md` 和 `windows-wdsi-submission-text-<tag>.zip`，并确认 `windows-release-assets-<tag>.json` 里的每个 Windows 安装包状态都有效。
- `Windows Installer Smoke Test` 会在 `cap-v*` Release 发布后自动下载已签名 Release，审计签名/checksum/attestation 后测试 EXE/MSI 静默安装和卸载。
- `Windows WDSI Package` 会在 `cap-v*` Release 发布后自动为已签名、已审计的 Release 生成微软复核材料包。
- `Windows Release Quarantine` 会在 Release 发布或编辑时自动检查是否仍挂着未验证 Windows EXE/MSI，并会读取 `windows-release-assets-<tag>.json` 确认每个安装包的签名、时间戳、SignTool、checksum、attestation 和 Defender 状态都有效；手动运行时默认只生成报告，只有输入 `mark-prerelease:<tag>` 或 `delete-windows-assets:<tag>` 确认字符串时才会把旧 Release 标记为 prerelease 或删除 Windows 安装资产。
- `Windows Release` 和 `Windows Store Package` 会在上传产物前用 Microsoft Defender 扫描 Windows EXE/MSI；`Windows Release Audit`、`Windows Installer Smoke Test`、`Windows WinGet Manifest` 和 `Windows WDSI Package` 会重新下载 Release 资产并再次扫描，避免被替换或误报的安装包进入公开证据链。
- 脚本可以下载指定 GitHub Release 的 Windows EXE/MSI。
- 脚本通过 GitHub Release Asset API 下载资产，正式 Release 还处于 draft 门禁阶段时也能验证安装包。
- 脚本会计算 SHA256。
- 脚本可以核对 Release 中的 `SHA256SUMS.txt`。
- 脚本可以用 GitHub CLI 验证 artifact attestation，确认安装包来自本仓库 GitHub Actions 构建。
- 脚本会检查 Authenticode 签名状态、可信时间戳、`signtool verify /pa /tw` 结果、checksum、artifact attestation 和 Microsoft Defender 扫描结果。
- 脚本支持用正则检查 Authenticode 发布者名称。
- 脚本会生成 `.release-verification/<tag>/windows-smartscreen-report.md`。
- 脚本会生成每个 EXE/MSI 对应的 WDSI 提交说明文本和证据文件。
- 文档中加入了 Microsoft WDSI 提交说明和可复制的开发者说明模板。

### 6. WinGet 分发准备

- 新增 `.github/workflows/windows-winget-manifest.yml`。
- 新增 `scripts/generate-winget-manifest.ps1`。
- `cap-v*` Release 发布后会自动运行 `Windows WinGet Manifest`；也可以手动输入 tag 重跑。
- `Windows WinGet Manifest` 会先审计 Release 签名、可信时间戳、SignTool 复核、SHA256 和 artifact attestation，再生成 WinGet manifest。
- `Windows WinGet Manifest` 通过后会把 `windows-winget-manifest-<tag>.zip` 和 `windows-winget-submission-<tag>.md` 上传到同一个 GitHub Release。
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
2. 优先运行 `Windows MSIX Store Package` workflow，下载 `windows-msix-store-package-<version>` artifact，并尝试把 `.msix` 提交到 Microsoft Store。
   如果 Store 应用已经创建并且 GitHub secrets 已配置，可以把 `publish_to_store` 设为 `true`，填写 `store_product_id`，让 workflow 直接提交 MSIX。
3. Store 上架后，把 `NEXT_PUBLIC_WINDOWS_STORE_URL`、`WINDOWS_STORE_URL` 或 `CAP_WINDOWS_STORE_URL` 配置为官方 Microsoft Store HTTPS 链接，让 `/download/windows` 默认跳 Store。
4. 如果 MSIX 认证不适合当前 Tauri 构建，再创建 `EXE or MSI app`。
5. 运行 `Windows Store Package` workflow；如果已经把签名安装包放到版本化 HTTPS 下载地址，可以填写 `package_url_base`。
6. 下载 workflow 生成的 `windows-store-package-<version>` artifact。
7. 按 `store-submission-package` 里的 checklist、JSON 或 CSV 填写 Partner Center 包信息。
8. 提交审核。

自动提交 MSIX 到 Store 需要这些 GitHub Secrets：`AZURE_AD_APPLICATION_CLIENT_ID`、`AZURE_AD_APPLICATION_SECRET`、`AZURE_AD_TENANT_ID`、`SELLER_ID`。

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
2. 手动运行 `Windows Trust Readiness`，确认主要信任链路没有缺关键配置；如果希望缺关键项时 workflow 直接失败，把 `fail_on_missing` 设为 `true`。之后它会在相关 Windows 信任链文件变更时自动运行，并每周定期检查一次。
3. 确认配置检查和临时 EXE 签名探针都通过。
4. 手动运行 `Windows Release` 或创建新的 `cap-v*` tag；正式发布保持 `require_signing=true`，未签名测试只能作为 draft。
5. 等待自动触发的 `Windows Release Audit` 通过，或手动输入刚发布的 tag 重新审计，确认签名发布者、可信时间戳、SignTool 复核、SHA256 和 artifact attestation 都通过。
6. 等待自动触发的 `Windows Installer Smoke Test` 通过，确认 EXE/MSI 可以静默安装和卸载。
7. 如需 WinGet 分发，下载自动生成的 `winget-manifest-<tag>` artifact，运行 `winget validate`，再提交到 `microsoft/winget-pkgs`。
8. 下载 EXE/MSI，用 `Get-AuthenticodeSignature` 确认签名为 `Valid`，并确认存在 `TimeStamperCertificate`。
9. 如仍出现 SmartScreen 误拦截，下载自动生成的 `windows-wdsi-package-<tag>` artifact，再把安装包和生成的说明文本提交到 Microsoft WDSI。

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
