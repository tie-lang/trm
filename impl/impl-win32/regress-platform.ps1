# impl/impl-win32/regress-platform.ps1 —— trm 平台桥（Win32）构建 + 回归
# 用法: pwsh impl/impl-win32/regress-platform.ps1 [tiec路径] [TIE_INTERP_LIB]
#
# 覆盖：
#   1. 平台模块编 .dll（tiec --shared → trm_platform.dll）
#   2. 导出面（trm_platform$is_tty / trm_platform$raw_mode）
#   3. C 冒烟（LoadLibrary + GetProcAddress 调用，ABI 不崩）
#   4. tie 侧回归驱动（tests/s10_platform/platform_demo.tie 编译+运行）
param(
    [string]$Tiec = "",
    [string]$TieInterp = ""
)
$ErrorActionPreference = "Continue"
$Dir = $PSScriptRoot
$TrmRoot = Split-Path -Parent (Split-Path -Parent $Dir)
$Demo = Join-Path $TrmRoot 'tests\s10_platform\platform_demo.tie'
$PipeDemo = Join-Path $TrmRoot 'tests\s10_platform\pipe_demo.tie'
$RunDemo = Join-Path $TrmRoot 'tests\s10_platform\run_demo.tie'
$InterDemo = Join-Path $TrmRoot 'tests\s10_platform\interactive_demo.tie'
if ($Tiec -eq "") { $Tiec = Join-Path (Split-Path -Parent (Split-Path -Parent $Dir)) '..\tie-main\compiler\tiec.exe' }
if ($TieInterp -eq "") { $TieInterp = 'F:\Projects\tie-repo\tie-main\target\release\tie_interp.lib' }
$env:TIE_INTERP_LIB = $TieInterp
$pass = 0; $fail = 0
function Report($ok, $msg) {
    if ($ok) { Write-Host "PASS $msg"; $script:pass++ }
    else { Write-Host "FAIL $msg"; $script:fail++ }
}

Write-Host "=== trm 平台桥（impl-win32）回归（tiec=$Tiec）==="

# 1. 平台模块 → trm_platform.dll
$Dll = Join-Path $Dir 'trm_platform.dll'
if (Test-Path $Dll) { Remove-Item $Dll }
& $Tiec (Join-Path $Dir 'platform_win32.tie') --shared -o $Dll *> $null
Report ($LASTEXITCODE -eq 0 -and (Test-Path $Dll)) "步骤1：平台模块编译为 trm_platform.dll"

# 2. 导出面
$ro = 'D:\LLVM\bin\llvm-readobj.exe'
if (-not (Test-Path $ro)) { $ro = 'llvm-readobj' }
if (Test-Path $Dll) {
    $syms = & $ro --coff-exports $Dll 2>&1 | Out-String
    Report ($syms.Contains('trm_platform$is_tty') -and $syms.Contains('trm_platform$raw_mode')) "步骤2：导出面 is_tty/raw_mode"
} else { Report $false "步骤2：无 .dll 可检查" }

# 3. C 冒烟
if (Test-Path $Dll) {
    $cexe = Join-Path $env:TEMP 'trm_platform_c.exe'
    if (Test-Path $cexe) { Remove-Item $cexe }
    & clang (Join-Path $Dir 'trm_platform_c.c') -o $cexe *> $null
    if (Test-Path $cexe) {
        $out = & $cexe $Dll 2>&1 | Out-String
        Report ($LASTEXITCODE -eq 0 -and $out.Contains('C 冒烟通过')) "步骤3：C LoadLibrary 冒烟（is_tty/raw_mode ABI）"
    } else { Report $false "步骤3：trm_platform_c.c 编译失败（clang 不可用？）" }
} else { Report $false "步骤3：无 .dll 可做 C 冒烟" }

# 4. tie 侧回归驱动（非交互：重定向下 is_tty=false、raw 优雅 false）
$DemoExe = Join-Path $TrmRoot 'tests\s10_platform\platform_demo.exe'
if (Test-Path $DemoExe) { Remove-Item $DemoExe }
& $Tiec $Demo -o $DemoExe *> $null
if ($LASTEXITCODE -eq 0 -and (Test-Path $DemoExe)) {
    $dout = & $DemoExe 2>&1 | Out-String
    Report ($LASTEXITCODE -eq 0 -and $dout.Contains('impl-win32 平台桥回归通过')) "步骤4：tie 侧平台桥回归（重定向降级）"
} else { Report $false "步骤4：platform_demo 编译失败" }

# 5. 进程管道捕获（结构化 CreateProcessW）：capture('cmd /c echo hello') 读到 hello
$PipeExe = Join-Path $TrmRoot 'tests\s10_platform\pipe_demo.exe'
if (Test-Path $PipeExe) { Remove-Item $PipeExe }
& $Tiec $PipeDemo -o $PipeExe *> $null
if ($LASTEXITCODE -eq 0 -and (Test-Path $PipeExe)) {
    $pout = & $PipeExe 2>&1 | Out-String
    Report ($LASTEXITCODE -eq 0 -and $pout.Contains('进程管道回归通过')) "步骤5：进程管道捕获（结构化 CreateProcessW）读到 hello"
} else { Report $false "步骤5：pipe_demo 编译失败" }

# 6. 双向管道（结构化 CreateProcessW）：run('cmd /c set /p ...', 'hello') 读到 got:hello 且退出码 0
$RunExe = Join-Path $TrmRoot 'tests\s10_platform\run_demo.exe'
if (Test-Path $RunExe) { Remove-Item $RunExe }
& $Tiec $RunDemo -o $RunExe *> $null
if ($LASTEXITCODE -eq 0 -and (Test-Path $RunExe)) {
    $rout = & $RunExe 2>&1 | Out-String
    Report ($LASTEXITCODE -eq 0 -and $rout.Contains('双向管道回归通过')) "步骤6：双向管道（stdin→stdout 闭环 + 退出码）"
} else { Report $false "步骤6：run_demo 编译失败" }

# 7. 交互式双向管道（S10d）：spawn 后 stdin 保持开启、两轮实时收发 + mnn 双会话泵
#    子进程 echo_child.exe（逐行实时回显，模拟 REPL；需先在 trm 根目录编译，demo 用相对路径 spawn）
$EchoC = Join-Path $TrmRoot 'tests\s10_platform\echo_child.c'
$EchoExe = Join-Path $TrmRoot 'tests\s10_platform\echo_child.exe'
$InterExe = Join-Path $TrmRoot 'tests\s10_platform\interactive_demo.exe'
if (Test-Path $EchoExe) { Remove-Item $EchoExe }
& clang $EchoC -o $EchoExe *> $null
if (Test-Path $EchoExe) {
    if (Test-Path $InterExe) { Remove-Item $InterExe }
    Push-Location $TrmRoot
    & $Tiec $InterDemo -o $InterExe *> $null
    Pop-Location
    if ($LASTEXITCODE -eq 0 -and (Test-Path $InterExe)) {
        Push-Location $TrmRoot
        $iout = & $InterExe 2>&1 | Out-String
        Pop-Location
        Report ($LASTEXITCODE -eq 0 -and $iout.Contains('交互式双向管道回归通过')) "步骤7：交互式双向管道（实时收发 + mnn 泵）"
    } else { Report $false "步骤7：interactive_demo 编译失败" }
} else { Report $false "步骤7：echo_child.c 编译失败（clang 不可用？）" }

# 8. 多会话交错 avail/read 回归（S10e，tiec alloc 补头扫描根因修复验证）：
#    同一循环体内交错 avail(a)/read(a)/avail(b)/read(b)，断言两会话输出无串线/无丢失——
#    tiec S10e 前该形态会字节串线/丢失（alloc 缓冲被垃圾 strlen 补头扫描）。
$InterleaveDemo = Join-Path $TrmRoot 'tests\s10_platform\interleave_demo.tie'
$InterleaveExe = Join-Path $TrmRoot 'tests\s10_platform\interleave_demo.exe'
if (Test-Path $EchoExe) {
    if (Test-Path $InterleaveExe) { Remove-Item $InterleaveExe }
    Push-Location $TrmRoot
    & $Tiec $InterleaveDemo -o $InterleaveExe *> $null
    Pop-Location
    if ($LASTEXITCODE -eq 0 -and (Test-Path $InterleaveExe)) {
        Push-Location $TrmRoot
        $ilout = & $InterleaveExe 2>&1 | Out-String
        Pop-Location
        Report ($LASTEXITCODE -eq 0 -and $ilout.Contains('多会话交错回归通过')) "步骤8：多会话交错 avail/read（无串线/丢失，tiec S10e 根因修复）"
    } else { Report $false "步骤8：interleave_demo 编译失败" }
} else { Report $false "步骤8：echo_child.exe 缺失（步骤7 未先编译）" }

Write-Host ""
Write-Host "=== 汇总: PASS=$pass FAIL=$fail ==="
exit ($fail -gt 0 ? 1 : 0)