# Windows SmartScreen 处理方案

SmartScreen 是基于声誉的保护系统，不能通过项目配置强行关闭。正确方向是让用户拿到可验证、可积累声誉的官方安装包。

## 最有效路线

1. Microsoft Store

   微软文档说明，Store 安装的应用由 Microsoft 证书覆盖，用户不会看到 SmartScreen 警告。这个路线需要注册 Microsoft Partner Center，并提交 EXE/MSI 应用。本仓库已提供 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`，用于生成 Store 要求的离线 WebView2 安装包配置。

   运行 GitHub Actions 中的 `Windows Store Package` workflow 可以生成 Store 用离线安装包。默认情况下该 workflow 要求 Windows 签名已配置；如需测试构建，可以手动把 `require_signing` 设为 `false`。

2. Azure Artifact Signing

   微软推荐非 Store 分发使用 Azure Artifact Signing。它不需要本地硬件 token，能在 GitHub Actions 中签名，当前基础套餐约为每月 9.99 美元。签名后 Windows 会显示已验证发布者，并且后续版本可以积累发布者声誉。

3. SignPath

   SignPath 是另一个适合 CI 的签名服务，开源项目可以申请 SignPath Foundation。仓库已有 `.github/signpath/artifact-configuration.xml`，会对 GitHub Release 中的 Windows EXE/MSI 执行 Authenticode 签名。

4. PFX/signtool

   如果已经有可导出的 PFX 代码签名证书，可以临时使用 `signtool.exe` 在 GitHub Actions 中签名。这个方式不如云签名安全，现代 OV/EV 证书通常也不能导出为 PFX，但它适合作为已有证书的过渡方案。

5. Microsoft WDSI 提交

   如果签名后的安装包仍被错误拦截，可以通过 Microsoft Security Intelligence 的文件提交入口，以 Software developer 身份提交文件，让微软人工分析。这个方式不能代替签名，但可以帮助特定版本移除误报。

## GitHub Actions 签名配置

`Windows Release` workflow 默认要求 Windows Authenticode 签名。通过 `cap-v*` tag 触发的正式 Release 不能关闭签名要求；手动运行 workflow 时，只有把 `require_signing` 输入显式设置为 `false`，才会允许生成未签名草稿测试包。未签名构建会被强制为 draft，并且 publish 阶段还有额外防线阻止未签名公开 Release。把 `WINDOWS_SIGNING_PROVIDER` 设置为 `azure-artifact-signing` 或 `pfx` 后，Windows 构建会：

1. 先构建未打包的 Windows 主程序
2. 签名主程序和 DLL
3. 再生成 NSIS EXE 和 MSI 安装包
4. 再签名最终上传到 GitHub Release 的 EXE/MSI

把 `WINDOWS_SIGNING_PROVIDER` 设置为 `signpath` 后，workflow 会先正常构建安装包，再把 EXE/MSI 提交到 SignPath 签名，最后验证签名状态。

在 GitHub 仓库中添加这些 Variables：

| Name | Example |
| --- | --- |
| `WINDOWS_SIGNING_PROVIDER` | `azure-artifact-signing`, `signpath`, or `pfx` |
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

配置好任一签名后端后，先手动运行 GitHub Actions 中的 `Windows Signing Check` workflow。它不会构建安装包，只检查 `WINDOWS_SIGNING_PROVIDER` 与对应 Variables/Secrets 是否齐全。检查通过后再创建新的 `cap-v*` tag 或手动运行 `Windows Release`。正式发布不要把 `require_signing` 改成 `false`；未签名测试只能作为 draft。

旧的 `publish` workflow 已禁用。Windows 正式发布只使用 `Windows Release` workflow，避免绕过签名检查。

## 现实预期

- 未签名或自签名：基本一定出现强警告，企业策略下可能无法继续运行。
- OV/EV/Artifact Signing：仍可能短期显示“未被识别”，但会显示发布者并积累声誉。
- EV 证书：微软当前文档明确说明不再保证直接绕过 SmartScreen。
- Microsoft Store：最接近“普通用户无警告安装”的路线。

## 发布建议

- 不要频繁改安装包文件名、发布者身份、下载域名。
- 每个 Windows Release 都使用同一个已验证发布者签名。
- 优先推广 GitHub Release 的同一个安装包链接，让同一文件 hash 积累下载声誉。
- 保留源码、release notes、hash、签名信息，方便微软人工复核。
- 发布后下载 Windows EXE/MSI，用 `Get-AuthenticodeSignature` 确认状态是 `Valid`。
- 发布后运行 `Windows Release Audit` workflow，确认 Release 中的 Windows EXE/MSI 签名有效并且匹配 `SHA256SUMS.txt`。
- 如果 Windows 包开始被拦截，提交签名后的 EXE/MSI 到 https://www.microsoft.com/en-us/wdsi/filesubmission。

## 发布后验证

运行仓库脚本验证指定 Release 的 Windows 安装包：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn
```

要求签名必须有效时：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn -RequireValidSignatures
```

要求签名和 Release checksum 都必须有效时：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn -RequireValidSignatures -VerifyChecksums
```

如果要同时确认发布者名称，可以加上 `-ExpectedPublisherPattern`：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-windows-release.ps1 -Tag cap-v0.4.3-cn -RequireValidSignatures -VerifyChecksums -ExpectedPublisherPattern "CN=Your Publisher Name"
```

脚本会下载 Release 中的 Windows EXE/MSI，生成：

- `.release-verification/<tag>/SHA256SUMS.txt`
- `.release-verification/<tag>/windows-smartscreen-report.md`

也可以在 GitHub Actions 里手动运行 `Windows Release Audit`，输入 Release tag。该 workflow 会用同一个脚本审计公开 Release，要求 Windows 安装包签名有效并且匹配 Release 中的 `SHA256SUMS.txt`。只有这个审计通过后，才建议把 GitHub Release 链接发给普通用户或用于 WDSI 提交。

当前 `cap-v0.4.3-cn` 的 Windows EXE/MSI 验证结果是 `NotSigned`。启用任一签名后端并重新发布后，应重新运行该脚本并确认状态为 `Valid`。

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
8. 提交审核。

Store workflow 使用 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`，其中设置了离线 WebView2 安装模式。Store 提交仍要求安装包签名，所以推荐先配置 `azure-artifact-signing` 或 `signpath`。

## WDSI 提交模板

提交身份选择 `Software developer`。说明文本可以使用：

```text
Product: Cap 中文版
Publisher: <代码签名显示的发布者名称>
Repository: https://github.com/Lkkisme/Cap
Release: <GitHub Release URL>
File: <EXE/MSI 文件名>
SHA256: <SHA256SUMS.txt 中对应 hash>
Signature status: Valid Authenticode signature

This is an open-source screen recording application distributed from the official GitHub repository. The submitted installer was built by GitHub Actions from the tagged release, is signed by the publisher, and should be classified as safe. Please review it as a false positive / SmartScreen reputation issue.
```

## 官方参考

- Microsoft SmartScreen reputation: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
- Azure Artifact Signing: https://azure.microsoft.com/en-us/products/artifact-signing
- Artifact Signing GitHub Action: https://github.com/Azure/artifact-signing-action
- Artifact Signing integrations: https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations
- SignPath GitHub integration: https://docs.signpath.io/trusted-build-systems/github
- SignPath artifact configuration: https://docs.signpath.io/artifact-configuration/examples
- Microsoft file submission: https://www.microsoft.com/en-us/wdsi/filesubmission
- Tauri Windows signing: https://v2.tauri.app/distribute/sign/windows/
- Tauri Microsoft Store distribution: https://v2.tauri.app/distribute/microsoft-store/
