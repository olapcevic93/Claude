<#
.SYNOPSIS
  Command-line build of D365 F&O models (the same compiler VS "Build" uses).

.DESCRIPTION
  Works on UDE and on classic dev VMs / cloud-hosted environments; paths are detected by d365-env.ps1.
  For each model: optional LabelC, then xppc. Binaries go to <Metadata>\<Model>\bin, logs to
  <Metadata>\<Model>\BuildModelResult.log / .xml (the files VS writes).
  Referenced custom models with no compiled DLL are built first, in dependency order.

  Every error is printed as one line:
      ERROR <Model> | <object xml file> | <dynamics:// path> | (line,col) | <message>
  Line/column are relative to the method source when the path ends in /Method/<name>.

  Exit code: 0 = no errors, 1 = build errors, 2 = tool or usage failure.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\d365-build.ps1 -Model MyModel
.EXAMPLE
  .\d365-build.ps1 -Model MyModel,MyOtherModel -Labels -WithReferences
.EXAMPLE
  .\d365-build.ps1 -Model MyModel -MetadataPath C:\repos\App\Metadata -FrameworkPath C:\AosService\PackagesLocalDirectory
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Model,   # package (folder) names under the metadata path
    [switch]$Labels,                                  # also compile labels (needed after label changes)
    [switch]$WithReferences,                          # rebuild every referenced custom package, not only those without a DLL
    [switch]$ShowWarnings,
    [string]$MetadataPath,                            # override: custom metadata root
    [string]$FrameworkPath,                           # override: standard PackagesLocalDirectory
    [string]$XppConfigName                            # UDE: pick a specific XPPConfig json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'd365-env.ps1')
try { $d365 = Get-D365Environment -MetadataPath $MetadataPath -FrameworkPath $FrameworkPath -XppConfigName $XppConfigName }
catch { Write-Host $_.Exception.Message; exit 2 }

$md     = $d365.MetadataPath
$xppc   = Join-Path $d365.BinPath 'xppc.exe'
$labelc = Join-Path $d365.BinPath 'LabelC.exe'
if (-not (Test-Path $xppc)) { Write-Host "MISSING: $xppc"; exit 2 }
Write-Host "Environment: $($d365.Mode) ($($d365.Source))"
Write-Host "Metadata:    $md"
Write-Host "Framework:   $($d365.FrameworkPath)"

# Build order: referenced custom packages first (depth-first, each once).
$order = New-Object System.Collections.Generic.List[string]
$visiting = @{}
function Add-WithRefs([string]$pkg) {
    if ($order.Contains($pkg) -or $visiting[$pkg]) { return }
    $visiting[$pkg] = $true
    foreach ($r in Get-D365PackageReferences $md $pkg) {
        if (-not (Test-Path (Join-Path $md "$r\Descriptor"))) { continue }       # lives in the framework folder only
        if (-not (Test-D365CustomPackage $md $r)) { continue }                   # standard Microsoft package
        $dll = Join-Path $md "$r\bin\Dynamics.AX.$r.dll"
        if ($WithReferences -or -not (Test-Path $dll)) { Add-WithRefs $r }
    }
    $order.Add($pkg)
}
foreach ($m in $Model) {
    if (-not (Test-Path (Join-Path $md "$m\Descriptor"))) { Write-Host "UNKNOWN MODEL: no $md\$m\Descriptor"; exit 2 }
    Add-WithRefs $m
}
Write-Host "Build order: $($order -join ' -> ')"

$typeFolder = @{ Macro = 'AxMacroDictionary' }
$refArgs = $d365.ReferencePaths | ForEach-Object { "-referenceFolder=$_" }
$totalErrors = 0

foreach ($m in $order) {
    $pkgDir = Join-Path $md $m
    $out    = Join-Path $pkgDir 'bin'
    $log    = Join-Path $pkgDir 'BuildModelResult.log'
    $xml    = Join-Path $pkgDir 'BuildModelResult.xml'
    New-Item -ItemType Directory -Force $out | Out-Null
    $sw = [Diagnostics.Stopwatch]::StartNew()

    if ($Labels) {
        Write-Host "[$m] LabelC ..."
        $errLog = Join-Path $pkgDir 'LabelC.err.log'
        Remove-Item $errLog -ErrorAction SilentlyContinue
        & $labelc -metadata="$md" -output="$out" -modelmodule="$m" -outlog="$pkgDir\LabelC.log" -errlog="$errLog" | Out-Null
        if ($LASTEXITCODE -ne 0 -or ((Test-Path $errLog) -and (Get-Item $errLog).Length -gt 0)) {
            Write-Host "[$m] LABEL ERRORS (exit $LASTEXITCODE):"; if (Test-Path $errLog) { Get-Content $errLog | Write-Host }
            $totalErrors++
        }
    }

    $xargs = @("-metadata=$md", "-compilermetadata=$($d365.FrameworkPath)", "-modelmodule=$m", "-output=$out",
               "-log=$log", "-xmllog=$xml") + $refArgs
    Remove-Item $log, $xml -ErrorAction SilentlyContinue
    Write-Host "[$m] xppc ..."
    $console = & $xppc @xargs 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    if (-not (Test-Path $xml)) { Write-Host "[$m] xppc exited $code and wrote no xml log:"; $console | Write-Host; exit 2 }

    [xml]$diag = Get-Content $xml -Raw
    $items  = @($diag.Diagnostics.Items.Diagnostic | Where-Object { $_ })
    $errors = @($items | Where-Object { $_.Severity -in 'Error', 'Fatal' })
    $warns  = @($items | Where-Object { $_.Severity -eq 'Warning' })
    if ($code -ne 0 -and $errors.Count -eq 0) {
        Write-Host "[$m] xppc exited $code with no errors in the xml log:"; $console | Select-Object -Last 20 | Write-Host; $totalErrors++
    }
    $totalErrors += $errors.Count
    Write-Host ("[{0}] exit {1}, {2} error(s), {3} warning(s), {4:mm\:ss}  log: {5}" -f $m, $code, $errors.Count, $warns.Count, $sw.Elapsed, $log)

    $show = $errors; if ($ShowWarnings) { $show += $warns }
    foreach ($e in $show) {
        $file = ''
        if ($e.Path -match '^dynamics://([^/]+)/([^/]+)') {
            $folder = if ($typeFolder.ContainsKey($matches[1])) { $typeFolder[$matches[1]] } else { 'Ax' + $matches[1] }
            $hit = Get-ChildItem $pkgDir -Directory | ForEach-Object { Join-Path $_.FullName "$folder\$($matches[2]).xml" } |
                   Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($hit) { $file = $hit }
        }
        $sev = if ($e.Severity -eq 'Warning') { 'WARN ' } else { 'ERROR' }
        Write-Host ("{0} {1} | {2} | {3} | ({4},{5}) | {6}" -f $sev, $m, $file, $e.Path, $e.Line, $e.Column, ($e.Message -replace '\s+', ' '))
    }
}

if ($totalErrors -gt 0) { Write-Host "BUILD FAILED: $totalErrors error(s)"; exit 1 }
Write-Host 'BUILD SUCCEEDED'
exit 0
