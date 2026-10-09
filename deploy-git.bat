@echo off
chcp 65001 >nul
cd /d "f:\项目\basketball-app"

echo ============================================
echo  篮球赛事 App - Git 提交 + 自动部署
echo ============================================
echo.

REM 设置环境变量
REM 主线路：香港中转就绪后改成 https://sb.你的域名 （当前 = Supabase 直连）
set VITE_SUPABASE_URL=https://zzuwpanihewhqtyywhny.supabase.co
REM 备用线路：Supabase 直连（主线路不通时启动自动切换）
set VITE_SUPABASE_URL_BACKUP=https://zzuwpanihewhqtyywhny.supabase.co
set VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6dXdwYW5paGV3aHF0eXl3aG55Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0ODg3MDgsImV4cCI6MjA5MzA2NDcwOH0.RPaUDBUiwAum3nmgaqmQwWzbNhovcqnUI1CFoyGhBM8

echo [Step 1/4] 构建项目...
echo.
call "C:\Program Files\nodejs\node.exe" "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build

IF %ERRORLEVEL% NEQ 0 (
    echo [错误] 构建失败，请检查错误信息。
    pause
    exit /b 1
)

echo.
echo [Step 2/4] Git 暂存所有变更...
echo.
call git add .

IF %ERRORLEVEL% NEQ 0 (
    echo [错误] git add 失败
    pause
    exit /b 1
)

echo.
echo [Step 3/4] Git 提交...
echo.
call git commit -m "fix: 统计表头样式修复+教练时间显示修复+球员评分系统"

IF %ERRORLEVEL% NEQ 0 (
    echo [注意] 提交可能没有变更内容，尝试强制提交...
    call git commit --allow-empty -m "fix: 统计表头样式修复+教练时间显示修复+球员评分系统"
)

echo.
echo [Step 4/4] 推送到 GitHub（将触发 Cloudflare 自动部署）...
echo.
echo 推送地址: https://github.com/LuoLucian/basketball-tournament-app.git
echo.
call git push origin main

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [错误] 推送失败，可能原因：
    echo  1. 需要输入 GitHub 账号密码/Token
    echo  2. 网络连接问题
    echo.
    echo 解决方法：打开终端手动执行 git push
    pause
    exit /b 1
)

echo.
echo ============================================
echo  ✅ 全部完成！
echo  ✅ 代码已推送到 GitHub
echo  ✅ Cloudflare Pages 将自动部署
echo  ✅ 约1-2分钟后访问:
echo     https://basketball-app-4x2.pages.dev
echo ============================================
pause