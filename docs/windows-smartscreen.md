# Windows SmartScreen 处理方案

SmartScreen 是基于声誉的保护系统，不能通过项目配置强行关闭。正确方向是让用户拿到可验证、可积累声誉的官方安装包。

## 最有效路线

1. Microsoft Store

   微软文档说明，Store 安装的应用由 Microsoft 证书覆盖，用户不会看到 SmartScreen 警告。这个路线需要注册 Microsoft Partner Center，并提交 EXE/MSI 应用。本仓库已提供 `apps/desktop/src-tauri/tauri.microsoft-store.conf.json`，用于生成 Store 要求的离线 WebView2 安装包配置。

2. Azure Artifact Signing

   微软推荐非 Store 分发使用 Azure Artifact Signing。它不需要本地硬件 token，能在 GitHub Actions 中签名，当前基础套餐约为每月 9.99 美元。签名后 Windows 会显示已验证发布者，并且后续版本可以积累发布者声誉。

3. Microsoft WDSI 提交

   如果签名后的安装包仍被错误拦截，可以通过 Microsoft Security Intelligence 的文件提交入口，以 Software developer 身份提交文件，让微软人工分析。这个方式不能代替签名，但可以帮助特定版本移除误报。

## GitHub Actions 签名配置

`Desktop Release` workflow 默认仍会发布未签名包。启用签名后，Windows 构建会：

1. 先构建未打包的 Windows 主程序
2. 使用 Azure Artifact Signing 签名主程序和 DLL
3. 再生成 NSIS EXE 和 MSI 安装包
4. 再签名最终上传到 GitHub Release 的 EXE/MSI

在 GitHub 仓库中添加这些 Variables：

| Name | Example |
| --- | --- |
| `WINDOWS_SIGNING_PROVIDER` | `azure-artifact-signing` |
| `AZURE_ARTIFACT_SIGNING_ENDPOINT` | `https://eus.codesigning.azure.net/` |
| `AZURE_ARTIFACT_SIGNING_ACCOUNT_NAME` | Azure Artifact Signing account name |
| `AZURE_ARTIFACT_SIGNING_CERTIFICATE_PROFILE_NAME` | Certificate profile name |

添加这些 Secrets：

| Name | Purpose |
| --- | --- |
| `AZURE_CLIENT_ID` | Microsoft Entra app registration client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

Azure 侧需要给该 Entra application 配置 GitHub OIDC federated credential，并授予 Artifact Signing Certificate Profile Signer 角色。

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
- 如果 Windows 包开始被拦截，提交签名后的 EXE/MSI 到 https://www.microsoft.com/en-us/wdsi/filesubmission。

## 官方参考

- Microsoft SmartScreen reputation: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
- Azure Artifact Signing: https://azure.microsoft.com/en-us/products/artifact-signing
- Artifact Signing GitHub Action: https://github.com/Azure/artifact-signing-action
- Artifact Signing integrations: https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations
- Microsoft file submission: https://www.microsoft.com/en-us/wdsi/filesubmission
- Tauri Windows signing: https://v2.tauri.app/distribute/sign/windows/
- Tauri Microsoft Store distribution: https://v2.tauri.app/distribute/microsoft-store/
