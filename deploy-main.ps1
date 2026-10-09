# 篮球应用部署脚本 (PowerShell)
# 用法: 在 PowerShell 中运行: .\deploy-main.ps1

$ErrorActionPreference = "Stop"

# 设置环境变量
# 主线路：香港中转就绪后改成 https://sb.你的域名 （当前 = Supabase 直连）
$env:VITE_SUPABASE_URL = "https://zzuwpanihewhqtyywhny.supabase.co"
# 备用线路：Supabase 直连（主线路不通时启动自动切换）
$env:VITE_SUPABASE_URL_BACKUP = "https://zzuwpanihewhqtyywhny.supabase.co"
$env:VITE_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6dXdwYW5paGV3aHF0eXl3aG55Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0ODg3MDgsImV4cCI6MjA5MzA2NDcwOH0.RPaUDBUiwAum3nmgaqmQwWzbNhovcqnUI1CFoyGhBM8"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  篮球应用部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 构建
Write-Host "步骤 1: 正在构建项目..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "构建失败!" -ForegroundColor Red
    exit 1
}

Write-Host "构建成功!" -ForegroundColor Green
Write-Host ""

# 步骤 2: 部署
Write-Host "步骤 2: 正在部署到 Cloudflare Pages..." -ForegroundColor Yellow
npx wrangler pages deploy dist --project-name=basketball-app --branch=main --commit-dirty=true

if ($LASTEXITCODE -ne 0) {
    Write-Host "部署失败!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  部署完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
