# Windows SmartScreen 处理方案

SmartScreen 是基于声誉的保护系统，不能通过项目配置强行关闭。正确方向是让用户拿到可验证、可积累声誉的官方安装包。

## 最有效路线

1. Microsoft Store

   微软文档说明，Store 安装的应用由 Microsoft 证书覆盖，用户不会看到 SmartScreen 警告。这个路线需要注册 Microsoft Partner Center，并提交 EXE/MSI 应用。本仓库已提供 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`，用于生成 Store 要求的离线 WebView2 安装包配置。

   运行 GitHub Actions 中的 `Windows Store Package` workflow 可以生成 Store 用离线安装包。默认情况下该 workflow 要求 Windows 签名已配置；如需测试构建，可以手动把 `require_signing` 设为 `false`。

   GitHub Release 安装包也使用离线 WebView2 安装模式。安装包体积会更大，但新电脑、离线环境或 WebView2 损坏环境不需要在安装时再下载 bootstrapper，安装失败和用户误以为软件不可信的概率更低。

2. Azure Artifact Signing

   微软推荐非 Store 分发使用 Azure Artifact Signing。它不需要本地硬件 token，能在 GitHub Actions 中签名，当前基础套餐约为每月 9.99 美元。签名后 Windows 会显示已验证发布者，并且后续版本可以积累发布者声誉。发布安装包必须带可信时间戳，否则证书过期或吊销后的长期验证会变差，本仓库的正式发布、审计、WinGet 和 WDSI 流程都会拒绝缺少时间戳的安装包。

3. SignPath

   SignPath 是另一个适合 CI 的签名服务，开源项目可以申请 SignPath Foundation。仓库已有 `.github/signpath/artifact-configuration.xml`，会对 Windows 主程序、DLL 和 GitHub Release 中的 Windows EXE/MSI 执行 Authenticode 签名。

4. PFX/signtool

   如果已经有可导出的 PFX 代码签名证书，可以临时使用 `signtool.exe` 在 GitHub Actions 中签名。这个方式不如云签名安全，现代 OV/EV 证书通常也不能导出为 PFX，但它适合作为已有证书的过渡方案。

5. Microsoft WDSI 提交

   如果签名后的安装包仍被错误拦截，可以通过 Microsoft Security Intelligence 的文件提交入口，以 Software developer 身份提交文件，让微软人工分析。这个方式不能代替签名，但可以帮助特定版本移除误报。

6. Windows Package Manager / WinGet

   WinGet 不能代替代码签名，也不能保证绕过 SmartScreen，但它是 Windows 官方包管理器入口。提交到 `microsoft/winget-pkgs` 后，manifest 会经过自动验证，用户可以用 `winget install` 安装。仓库已提供 `Windows WinGet Manifest` workflow，会在签名、可信时间戳、SignTool、checksum 和 artifact attestation 审计通过后生成 WinGet manifest，避免把未签名或 hash 不可核对的安装包提交到包管理器生态。该 workflow 会在 `cap-v*` Release 发布后自动运行，也可以手动输入 tag 重跑。生成器会写入静默安装参数；MSI manifest 还会写入 `ProductCode`、固定 `UpgradeCode` 和 Add/Remove Programs 升级身份，方便 WinGet 识别安装状态和后续升级。

## GitHub Actions 签名配置

`Windows Release` workflow 默认要求 Windows Authenticode 签名。通过 `cap-v*` tag 触发的正式 Release 不能关闭签名要求；手动运行 workflow 时，只有把 `require_signing` 输入显式设置为 `false`，才会允许生成未签名草稿测试包。未签名构建会被强制为 draft，并且 publish 阶段还有额外防线阻止未签名公开 Release。启用签名时必须配置 `WINDOWS_SIGNING_PUBLISHER_PATTERN`，让 workflow 在签名后确认 Authenticode subject 是预期发布者。把 `WINDOWS_SIGNING_PROVIDER` 设置为 `azure-artifact-signing` 或 `pfx` 后，Windows 构建会：

1. 先构建未打包的 Windows 主程序
2. 签名主程序和 DLL
3. 再生成 NSIS EXE 和 MSI 安装包
4. 再签名最终上传到 GitHub Release 的 EXE/MSI

把 `WINDOWS_SIGNING_PROVIDER` 设置为 `signpath` 后，workflow 会先构建未打包的 Windows 主程序，把主程序和 DLL 提交到 SignPath 签名并验证，再生成 NSIS EXE 和 MSI 安装包，然后把 EXE/MSI 再提交到 SignPath 签名，最后验证签名状态、可信时间戳和 `signtool verify /pa /tw` 结果。

在 GitHub 仓库中添加这些 Variables：

| Name | Example |
| --- | --- |
| `WINDOWS_SIGNING_PROVIDER` | `azure-artifact-signing`, `signpath`, or `pfx` |
| `WINDOWS_PACKAGE_PUBLISHER` | Optional, defaults to `Lkkisme` |
| `WINDOWS_SIGNING_PUBLISHER_PATTERN` | Regex matching the Authenticode subject, e.g. `Lkkisme` |
| `AZURE_ARTIFACT_SIGNING_ENDPOINT` | `https://eus.codesigning.azure.net/` |
| `AZURE_ARTIFACT_SIGNING_ACCOUNT_NAME` | Azure Artifact Signing account name |
| `AZURE_ARTIFACT_SIGNING_CERTIFICATE_PROFILE_NAME` | Certificate profile name |
| `WINDOWS_SIGNING_TIMESTAMP_URL` | Optional, defaults to `http://timestamp.digicert.com` for PFX |

Azure Artifact Signing 需要这些 Secrets：

| Name | Purpose |
| --- | --- |
| `AZURE_CLIENT_ID` | Microsoft Entra app registration client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

Azure 侧需要给该 Entra application 配置 GitHub OIDC federated credential，并授予 Artifact Signing Certificate Profile Signer 角色。

SignPath 需要这些 Secrets：

| Name | Purpose |
| --- | --- |
| `SIGNPATH_API_TOKEN` | SignPath CI user API token |
| `SIGNPATH_ORGANIZATION_ID` | SignPath organization ID |
| `SIGNPATH_PROJECT_SLUG` | SignPath project slug |
| `SIGNPATH_SIGNING_POLICY_SLUG` | Signing policy slug |
| `SIGNPATH_ARTIFACT_CONFIGURATION_SLUG` | Artifact configuration slug |

PFX/signtool 需要这些 Secrets：

| Name | Purpose |
| --- | --- |
| `WINDOWS_CERTIFICATE_PFX_BASE64` | Base64-encoded `.pfx` file |
| `WINDOWS_CERTIFICATE_PFX_PASSWORD` | PFX password |

配置好任一签名后端后，先手动运行 GitHub Actions 中的 `Windows Signing Check` workflow。它不会构建安装包，会检查 Windows 包元数据、`WINDOWS_SIGNING_PROVIDER`、`WINDOWS_SIGNING_PUBLISHER_PATTERN` 与对应 Variables/Secrets 是否齐全。检查通过后再创建新的 `cap-v*` tag 或手动运行 `Windows Release`。正式发布不要把 `require_signing` 改成 `false`；未签名测试只能作为 draft。

旧的 `publish` workflow 已禁用。Windows 正式发布只使用 `Windows Release` workflow，避免绕过签名检查。

## Windows 包身份元数据

Windows 安装包需要长期保持同一个应用身份，否则 SmartScreen、WinGet、Add/Remove Programs 和升级路径都会更难积累信任。本仓库现在固定了：

- `apps/desktop/src-tauri/tauri.conf.json` 中的 `bundle.publisher`、homepage、license、description 和 MSI `upgradeCode`
- `apps/desktop/src-tauri/Cargo.toml` 中的 authors、homepage 和 license
- `apps/desktop/src-tauri/tauri.github-release.conf.json` 和 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json` 中的离线 WebView2 安装模式
- `Windows Signing Check`、`Windows Release`、`Windows Store Package` 中的 `scripts/validate-windows-app-metadata.ps1`

默认 publisher 是 `Lkkisme`。如果真实代码签名证书显示的发布者不是 `Lkkisme`，应同时更新 `bundle.publisher`、`Cargo.toml` authors、`WINDOWS_PACKAGE_PUBLISHER`、`WINDOWS_SIGNING_PUBLISHER_PATTERN`、WinGet workflow 输入和 WDSI 模板中的 Publisher，保持它们一致。

## 现实预期

- 未签名或自签名：基本一定出现强警告，企业策略下可能无法继续运行。
- OV/EV/Artifact Signing：仍可能短期显示“未被识别”，但会显示发布者并积累声誉。
- EV 证书：微软当前文档明确说明不再保证直接绕过 SmartScreen。
- Microsoft Store：最接近“普通用户无警告安装”的路线。

## 发布建议

- 不要频繁改安装包文件名、发布者身份、下载域名。
- 每个 Windows Release 都使用同一个已验证发布者签名，并带可信时间戳。
- 每个正式构建都让 `WINDOWS_SIGNING_PUBLISHER_PATTERN` 匹配同一个 Authenticode subject，避免签名证书身份漂移导致声誉重新积累。
- GitHub Release 和 Microsoft Store 包都使用离线 WebView2 安装模式，避免用户机器缺少 WebView2 时安装器还要联网下载依赖。
- 优先推广 GitHub Release 的同一个安装包链接，让同一文件 hash 积累下载声誉。
- 已公开的 `cap-v*` Release 不要替换 EXE/MSI；如果需要重新发布安装包，创建新的 tag，让用户和微软都能看到清晰版本边界。
- 保留源码、release notes、hash、签名信息，方便微软人工复核。
- 发布后下载 Windows EXE/MSI，用 `Get-AuthenticodeSignature` 确认状态是 `Valid`，确认存在 `TimeStamperCertificate`，并用 Windows SDK `signtool verify /pa /tw` 复核。
- 发布后等待自动触发的 `Windows Release Audit` workflow 通过，确认 Release 中的 Windows EXE/MSI 签名发布者匹配、带可信时间戳、通过 SignTool 复核、匹配 `SHA256SUMS.txt`，并且通过 GitHub artifact attestation 验证。
- 发布后等待自动触发的 `Windows Installer Smoke Test` workflow 通过，确认 Release 中的 EXE/MSI 能在干净 Windows runner 上静默安装并卸载。
- 需要 WinGet 分发时，下载自动生成的 `winget-manifest-<tag>` artifact，运行 `winget validate` 后提交到 `microsoft/winget-pkgs`。
- 如果 Windows 包开始被拦截，下载自动生成的 `windows-wdsi-package-<tag>` artifact，再提交签名后的 EXE/MSI 到 https://www.microsoft.com/en-us/wdsi/filesubmission。

## Microsoft Defender 发布前扫描

`Windows Release` 和 `Windows Store Package` 会在上传产物前运行 `scripts/scan-windows-assets.ps1`。该脚本使用 GitHub Windows runner 上的 Microsoft Defender `MpCmdRun.exe` 对 EXE/MSI 做自定义扫描，扫描失败或检测不可用都会让 workflow 失败。

Defender 扫描不能代替代码签名、Store、WDSI 或 SmartScreen 声誉，但它能在公开发布前提前发现会被 Microsoft 安全栈直接拦截的安装包。这个检查通过后，再继续进行 checksum、attestation、Release 审计和 WDSI 流程。

## 发布后验证

运行仓库脚本验证指定 Release 的 Windows 安装包：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn
```

要求签名必须有效且带可信时间戳时：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn -RequireValidSignatures -RequireTimestampedSignatures -RequireSignToolVerification
```

要求签名、可信时间戳和 Release checksum 都必须有效时：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn -RequireValidSignatures -RequireTimestampedSignatures -RequireSignToolVerification -VerifyChecksums
```

要求签名、可信时间戳、Release checksum 和 GitHub artifact attestation 都必须有效时：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn -RequireValidSignatures -RequireTimestampedSignatures -RequireSignToolVerification -VerifyChecksums -VerifyAttestations
```

本地使用 `-VerifyAttestations` 时需要安装 GitHub CLI `gh`，并确保它可以访问该仓库的 attestations。GitHub Actions runner 已内置 `gh`，workflow 会使用 `GITHUB_TOKEN`。

如果要同时确认发布者名称，可以加上 `-ExpectedPublisherPattern`：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn -RequireValidSignatures -RequireTimestampedSignatures -RequireSignToolVerification -VerifyChecksums -VerifyAttestations -ExpectedPublisherPattern "CN=Your Publisher Name"
```

脚本会下载 Release 中的 Windows EXE/MSI，生成：

- `.release-verification/<tag>/SHA256SUMS.txt`
- `.release-verification/<tag>/windows-smartscreen-report.md`

`cap-v*` Release published 后会自动触发 `Windows Release Audit`、`Windows Installer Smoke Test`、`Windows WinGet Manifest` 和 `Windows WDSI Package`。由 `Windows Release` workflow 创建公开签名 Release 时，它还会用 `workflow_dispatch` 主动触发这些后续 workflow，避免 GitHub Actions 自己创建 Release 后没有继续触发证据链。也可以在 GitHub Actions 里手动运行它们并输入 Release tag。Release 审计会用同一个脚本检查公开 Release，要求 Windows 安装包签名有效、带可信时间戳、通过 `signtool verify /pa /tw`、匹配 Release 中的 `SHA256SUMS.txt`，并且通过 GitHub artifact attestation 验证。安装器 smoke test 会在干净 Windows runner 上静默安装和卸载 EXE/MSI。只有这些检查通过后，才建议把 GitHub Release 链接发给普通用户、提交 WinGet 或用于 WDSI 申诉。

当前 `cap-v0.4.3-cn` 的 Windows EXE/MSI 验证结果是 `NotSigned`。启用任一签名后端并重新发布后，应重新运行该脚本并确认状态为 `Valid`。

## 安装器静默安装测试

`cap-v*` Release 发布后会自动运行 GitHub Actions 中的 `Windows Installer Smoke Test` workflow；也可以手动输入已签名 Release tag 重跑。它会先复用发布后验证脚本确认签名、可信时间戳、SignTool、`SHA256SUMS.txt` 和 GitHub artifact attestation 都通过，然后在 Windows runner 上测试：

1. NSIS EXE 使用 `/S` 静默安装
2. MSI 使用 `/quiet /norestart` 静默安装
3. 安装后能在 Windows uninstall registry 中找到产品项
4. 安装器能静默卸载并清理产品项

这个测试不能代替真实用户机器覆盖，但能提前发现 Store 提交和企业部署最容易卡住的静默安装问题。

## WDSI 复核材料包

如果签名后的安装包仍被 SmartScreen 或 Microsoft Defender 误拦截，可以下载 Release 发布后自动生成的 `windows-wdsi-package-<tag>` artifact，也可以手动运行 GitHub Actions 中的 `Windows WDSI Package` workflow 重跑。输入已通过 `Windows Release Audit` 的 Release tag 后，它会：

1. 重新验证 Authenticode 签名
2. 重新验证可信时间戳
3. 用 `signtool verify /pa /tw` 复核安装包
4. 重新核对 `SHA256SUMS.txt`
5. 重新验证 GitHub artifact attestation
6. 为每个 EXE/MSI 生成一份 WDSI 提交说明文本
7. 打包安装包、报告、hash、证据 JSON 和 checklist

下载 artifact `windows-wdsi-package-<tag>` 后，在 https://www.microsoft.com/en-us/wdsi/filesubmission 选择 `Software developer`，上传 `installers` 目录中的对应安装包，并粘贴 `submission-text` 目录中同名文本。

## WinGet 提交流程

1. 完成 Windows 签名配置。
2. 运行 `Windows Release` 生成签名后的公开 Release。
3. 等待自动触发的 `Windows Release Audit` 通过，确认签名、可信时间戳、SignTool 复核、`SHA256SUMS.txt` 和 GitHub artifact attestation 都通过。
4. 等待 `Windows Installer Smoke Test` 自动通过，确认静默安装和卸载通过。
5. 下载自动生成的 workflow artifact `winget-manifest-<tag>`；如需重跑，可以手动运行 `Windows WinGet Manifest` 并输入刚发布的 tag。
6. 解压 artifact。
7. 在本地或 `microsoft/winget-pkgs` fork 中运行 `winget validate <manifest-folder>`。
8. 按 Windows Package Manager 文档把 manifest 提交到 `microsoft/winget-pkgs`。

生成器默认使用 Windows x64 MSI，因为 MSI 更适合包管理器安装和升级。生成器会先下载安装包，按 Release 的 `SHA256SUMS.txt` 复核 hash，再为 MSI 读取 `ProductCode` 并写入固定 `UpgradeCode`；如果选择 EXE，则写入 NSIS 静默安装参数。默认包名是 `Lkkisme.CapCN`，如果最终签名发布者名称不是 `Lkkisme`，运行 workflow 时应把 `package_identifier` 和 `publisher` 改成与签名发布者和 Add/Remove Programs 中显示的名称一致。

Release 和 Store workflow 还会生成 GitHub artifact attestation。下载文件后可以验证构建来源：

```powershell
gh attestation verify .\Cap._0.4.3-cn_x64-setup-windows-x64.exe --repo Lkkisme/Cap
```

attestation 不能代替代码签名，但能证明产物来自该仓库的 GitHub Actions 构建，对用户信任和 WDSI 复核都有帮助。

## Microsoft Store 提交流程

1. 在 Microsoft Partner Center 注册开发者账号。
2. 新建 `EXE or MSI app` 产品，并保留应用名称。
3. 在 GitHub Actions 手动运行 `Windows Store Package`。
4. 下载 workflow artifact `windows-store-package-<version>`。
5. 在 Partner Center 上传或链接离线安装包。
6. 如果使用 NSIS EXE，静默安装参数填写 `/S`。
7. 如果使用 MSI，静默安装参数填写 `/quiet`。
8. 确认同版本 Release 自动触发的 `Windows Installer Smoke Test` 已通过，必要时手动重跑。
9. 提交审核。

Store workflow 使用 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`，其中设置了离线 WebView2 安装模式。Store 提交仍要求安装包签名，所以推荐先配置 `azure-artifact-signing` 或 `signpath`。

## WDSI 提交模板

提交身份选择 `Software developer`。推荐优先使用 `Windows WDSI Package` 自动生成的 `submission-text` 文件。手动说明文本可以使用：

```text
Product: Cap 中文版
Publisher: <代码签名显示的发布者名称>
Repository: https://github.com/Lkkisme/Cap
Release: <GitHub Release URL>
File: <EXE/MSI 文件名>
SHA256: <SHA256SUMS.txt 中对应 hash>
Signature status: Valid Authenticode signature
Signature timestamp: Present trusted timestamp
SignTool verification: Valid signtool verify /pa /tw result

This is an open-source screen recording application distributed from the official GitHub repository. The submitted installer was built by GitHub Actions from the tagged release, is signed by the publisher with a trusted timestamp, and should be classified as safe. Please review it as a false positive / SmartScreen reputation issue.
```

## 官方参考

- Microsoft SmartScreen reputation: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
- Azure Artifact Signing: https://azure.microsoft.com/en-us/products/artifact-signing
- Artifact Signing GitHub Action: https://github.com/Azure/artifact-signing-action
- Artifact Signing integrations: https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations
- SignPath GitHub integration: https://docs.signpath.io/trusted-build-systems/github
- SignPath artifact configuration: https://docs.signpath.io/artifact-configuration/examples
- Microsoft file submission: https://www.microsoft.com/en-us/wdsi/filesubmission
- GitHub CLI attestation verify: https://cli.github.com/manual/gh_attestation_verify
- Windows Package Manager manifest: https://learn.microsoft.com/en-us/windows/package-manager/package/manifest
- Windows Package Manager submission: https://learn.microsoft.com/en-us/windows/package-manager/package/repository
- Tauri Windows signing: https://v2.tauri.app/distribute/sign/windows/
- Tauri Microsoft Store distribution: https://v2.tauri.app/distribute/microsoft-store/
