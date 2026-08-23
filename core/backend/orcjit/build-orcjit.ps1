# core/backend/orcjit/build-orcjit.ps1 - build the LLVM MCJIT driver orcjit.exe.
# Requires D:\LLVM (LLVM-C.dll/.lib + include/llvm-c) and clang.exe.
# Produces orcjit.exe and copies LLVM-C.dll beside it.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$llvm = "D:\LLVM"
if ($env:TIE_LLVM_HOME) { $llvm = $env:TIE_LLVM_HOME }

$clang = Join-Path $llvm "bin\clang.exe"
if (-not (Test-Path $clang)) { Write-Error "clang not found: $clang" }

$src = Join-Path $root "orcjit.c"
$out = Join-Path $root "orcjit.exe"
& $clang $src -o $out "-I$(Join-Path $llvm 'include')" (Join-Path $llvm 'lib\LLVM-C.lib') -Wno-override-module
if ($LASTEXITCODE -ne 0) { Write-Error "clang build failed: $LASTEXITCODE" }

$dllSrc = Join-Path $llvm "bin\LLVM-C.dll"
if (Test-Path $dllSrc) {
    Copy-Item $dllSrc (Join-Path $root "LLVM-C.dll") -Force
} else {
    Write-Warning "LLVM-C.dll not found at $dllSrc"
}
Write-Host "built: $out"