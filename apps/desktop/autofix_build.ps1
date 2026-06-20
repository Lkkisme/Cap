Write-Host ">>> 正在自动修复构建环境（FFmpeg 依赖）..." -ForegroundColor Cyan

if ($env:CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD -ne "1") {
    Write-Host "[STOP] This local script can create unsigned Windows installers." -ForegroundColor Red
    Write-Host "Use GitHub Actions Windows Release, Windows Store Package, or Windows MSIX Store Package for distributable Windows builds."
    Write-Host "For local testing only, set CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD=1 and run this script again."
    exit 1
}

$installDir = "$env:USERPROFILE\.cap_build_tools"
$ffmpegDir = "$installDir\ffmpeg"
$zipFile = "$installDir\ffmpeg.zip"
$url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip"

# 创建目录
if (!(Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir | Out-Null }

# 检查是否已安装
if (!(Test-Path "$ffmpegDir\bin\avcodec-*.dll")) {
    Write-Host "未检测到可用 FFmpeg，开始下载..." -ForegroundColor Yellow
    Write-Host "下载地址: $url"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing
    }
    catch {
        Write-Error "下载失败: $_"
        Write-Host "提示: 您可以手动下载该 zip 文件，保存为: $zipFile，然后重新运行此脚本" -ForegroundColor Red
        exit 1
    }

    Write-Host "正在解压..." -ForegroundColor Yellow
    if (Test-Path $ffmpegDir) { Remove-Item $ffmpegDir -Recurse -Force }
    Expand-Archive $zipFile -DestinationPath $installDir -Force
    
    # 重命名
    $extracted = Get-ChildItem -Path $installDir -Directory -Filter "ffmpeg-*-shared" | Select-Object -First 1
    if ($extracted) {
        Rename-Item $extracted.FullName "ffmpeg"
    }
    
    Write-Host "FFmpeg 安装完成: $ffmpegDir" -ForegroundColor Green
}
else {
    Write-Host "使用现有 FFmpeg: $ffmpegDir" -ForegroundColor Green
}

# 设置环境变量 (仅当前进程有效)
$env:FFMPEG_DIR = $ffmpegDir
$env:Path = "$ffmpegDir\bin;C:\Users\DELL\.cargo\bin;$env:Path"

Write-Host ">>> 环境配置完毕，开始构建项目..." -ForegroundColor Cyan
Write-Host "执行: pnpm build:tauri"
& "$env:APPDATA\npm\pnpm.cmd" build:tauri
