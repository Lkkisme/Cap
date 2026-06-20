@echo off
setlocal
chcp 65001 >nul

if /I not "%CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD%"=="1" (
    echo [STOP] This local script can create unsigned Windows installers.
    echo Use GitHub Actions Windows Release, Windows Store Package, or Windows MSIX Store Package for distributable Windows builds.
    echo For local testing only, set CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD=1 and run this script again.
    pause
    exit /b 1
)

echo ==========================================
echo       Cap 构建环境检查与打包脚本
echo ==========================================
echo.

:: --- 配置区 (如果不正确，请手动修改此处) ---
set "MY_FFMPEG_ROOT=%USERPROFILE%\.cap_build_tools\ffmpeg"
set "MY_LLVM_ROOT=C:\Program Files\LLVM"
:: --------------------------------------------

:: 1. 检查 Node/pnpm
echo [1/5] 检查 Node.js 环境...
call pnpm --version >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%APPDATA%\npm\pnpm.cmd" (
        set "PNPM_CMD=%APPDATA%\npm\pnpm.cmd"
        echo [信息] 找到 pnpm: %APPDATA%\npm\pnpm.cmd
    ) else (
        echo [错误] 未找到 pnpm！此脚本不会自动下载，请先安装 pnpm。
        pause
        exit /b 1
    )
) else (
    set "PNPM_CMD=pnpm"
    echo [信息] pnpm 已在 PATH 中。
)

:: 2. 检查 Rust/Cargo
echo.
echo [2/5] 检查 Rust 环境...
if exist "%USERPROFILE%\.cargo\bin\cargo.exe" (
    set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
    echo [信息] 找到 Cargo: %USERPROFILE%\.cargo\bin
    goto :cargo_found
)
call cargo --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到 Cargo (Rust)，请先安装 Rust。
    pause
    exit /b 1
)
:cargo_found
echo [信息] Cargo 环境就绪。

:: 3. 检查 FFmpeg
echo.
echo [3/5] 检查 FFmpeg...
if exist "%MY_FFMPEG_ROOT%\bin\avcodec-*.dll" (
    echo [信息] 找到本地 FFmpeg: %MY_FFMPEG_ROOT%
    set "FFMPEG_DIR=%MY_FFMPEG_ROOT%"
    set "PATH=%MY_FFMPEG_ROOT%\bin;%PATH%"
    REM 设置 FFmpeg 头文件和库文件路径
    set "FFMPEG_INCLUDE_DIR=%MY_FFMPEG_ROOT%\include"
    set "FFMPEG_LIB_DIR=%MY_FFMPEG_ROOT%\lib"
) else (
    :: 检查现有环境变量
    if defined FFMPEG_DIR (
        echo [信息] 使用系统环境变量 FFMPEG_DIR: %FFMPEG_DIR%
        set "PATH=%FFMPEG_DIR%\bin;%PATH%"
        set "FFMPEG_INCLUDE_DIR=%FFMPEG_DIR%\include"
        set "FFMPEG_LIB_DIR=%FFMPEG_DIR%\lib"
    ) else (
        echo [错误] 未找到 FFmpeg！
        echo 脚本默认查找: %MY_FFMPEG_ROOT%
        echo 如果您已安装，请编辑此脚本修改 MY_FFMPEG_ROOT，或者设置 FFMPEG_DIR 环境变量。
        pause
        exit /b 1
    )
)

:: 4. 检查 LLVM (libclang)
echo.
echo [4/5] 检查 LLVM (libclang)...
if exist "%MY_LLVM_ROOT%\bin\libclang.dll" (
    echo [信息] 找到 LLVM: %MY_LLVM_ROOT%
    set "LIBCLANG_PATH=%MY_LLVM_ROOT%\bin"
    goto :llvm_found
)
if defined LIBCLANG_PATH (
    echo [信息] 使用系统环境变量 LIBCLANG_PATH: %LIBCLANG_PATH%
    goto :llvm_found
)
echo [错误] 未找到 LLVM (libclang.dll)
echo 脚本默认查找: %MY_LLVM_ROOT%
echo 此组件用于 Rust 生成绑定。如果您已安装，请设置 LIBCLANG_PATH 指向 bin 目录。
pause
exit /b 1
:llvm_found
echo [信息] LLVM 环境就绪。

:: 5. 清理旧的构建缓存
echo.
echo [5/8] 清理旧的构建缓存...
cd ..\..
if exist "target" (
    echo [信息] 删除旧的 target 目录...
    rmdir /s /q target
)
if exist "apps\desktop\src-tauri\target" (
    echo [信息] 删除旧的 src-tauri/target 目录...
    rmdir /s /q apps\desktop\src-tauri\target
)

:: 6. 检查依赖
echo.
echo [6/8] 检查项目依赖...
if not exist "node_modules" (
    echo [提示] 正在安装依赖...
    call %PNPM_CMD% install
) else (
    echo [信息] 依赖已安装
)

:: 7. 执行打包
echo.
echo [7/8] 开始打包...
echo ------------------------------------------
cd apps\desktop

echo 执行命令: %PNPM_CMD% build:tauri
call %PNPM_CMD% build:tauri

if %errorlevel% equ 0 (
    echo.
    echo [8/8] 打包成功！
    echo [成功] 打包完成！
    echo 安装包位置: src-tauri\target\release\bundle
    explorer src-tauri\target\release\bundle
) else (
    echo.
    echo [8/8] 构建失败
    echo [失败] 构建遇到错误。
)

pause
