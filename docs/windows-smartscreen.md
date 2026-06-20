# Windows SmartScreen 处理方案

SmartScreen 是基于声誉的保护系统，不能通过项目配置强行关闭。正确方向是让用户拿到可验证、可积累声誉的官方安装包。

## 最有效路线

1. Microsoft Store

   微软文档说明，Store 安装的应用由 Microsoft 证书覆盖，用户不会看到 SmartScreen 警告。这个路线需要注册 Microsoft Partner Center，并提交 EXE/MSI 应用。本仓库已提供 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`，用于生成 Store 要求的离线 WebView2 安装包配置。

2. Azure Artifact Signing

   微软推荐非 Store 分发使用 Azure Artifact Signing。它不需要本地硬件 token，能在 GitHub Actions 中签名，当前基础套餐约为每月 9.99 美元。签名后 Windows 会显示已验证发布者，并且后续版本可以积累发布者声誉。

3. SignPath

   SignPath 是另一个适合 CI 的签名服务，开源项目可以申请 SignPath Foundation。仓库已有 `.github/signpath/artifact-configuration.xml`，会对 GitHub Release 中的 Windows EXE/MSI 执行 Authenticode 签名。

4. PFX/signtool

   如果已经有可导出的 PFX 代码签名证书，可以临时使用 `signtool.exe` 在 GitHub Actions 中签名。这个方式不如云签名安全，现代 OV/EV 证书通常也不能导出为 PFX，但它适合作为已有证书的过渡方案。

5. Microsoft WDSI 提交

   如果签名后的安装包仍被错误拦截，可以通过 Microsoft Security Intelligence 的文件提交入口，以 Software developer 身份提交文件，让微软人工分析。这个方式不能代替签名，但可以帮助特定版本移除误报。

## GitHub Actions 签名配置

`Desktop Release` workflow 默认仍会发布未签名包。把 `WINDOWS_SIGNING_PROVIDER` 设置为 `azure-artifact-signing` 或 `pfx` 后，Windows 构建会：

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
- 如果 Windows 包开始被拦截，提交签名后的 EXE/MSI 到 https://www.microsoft.com/en-us/wdsi/filesubmission。

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
