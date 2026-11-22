<#
.SYNOPSIS
  D365 F&O database synchronization from the command line (SyncEngine.exe).

.DESCRIPTION
  Environment detected by d365-env.ps1.
    Classic dev VM / cloud-hosted: runs SyncEngine against the local business DB
      (server/database from AosService\webroot\web.config, default localhost / AxDB, Windows auth).
      Run from an elevated prompt; build the models first.
    UDE: the business DB is in the online environment and SyncEngine cannot reach it.
      The script prints the Visual Studio deploy steps and exits 3.

  Exit code: 0 = sync OK, 1 = sync failed, 2 = tool or usage failure, 3 = UDE (sync via VS deploy).

.EXAMPLE
  .\d365-dbsync.ps1 -Tables MyTable,MyEntity                 # partial sync
.EXAMPLE
  .\d365-dbsync.ps1 -TableExtensions CustTable.MyExtension   # table extensions
.EXAMPLE
  .\d365-dbsync.ps1 -Full                                    # full sync (slow)
#>
[CmdletBinding()]
param(
    [string[]]$Tables,             # tables, views, data entities
    [string[]]$TableExtensions,
    [switch]$Full,
    [string]$DbServer,             # override detected server
    [string]$Database,             # override detected database
    [string]$ConnectionString,     # override the whole connection string
    [string]$MetadataPath,
    [string]$FrameworkPath,
    [string]$XppConfigName
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'd365-env.ps1')
try { $d365 = Get-D365Environment -MetadataPath $MetadataPath -FrameworkPath $FrameworkPath -XppConfigName $XppConfigName }
catch { Write-Host $_.Exception.Message; exit 2 }

if (-not $Full -and -not $Tables -and -not $TableExtensions) { Write-Host 'Specify -Full, -Tables or -TableExtensions.'; exit 2 }

if ($d365.Mode -eq 'UDE') {
    Write-Host @"
UDE environment ($($d365.CloudUrl)): the database is synchronized by deploying to the online environment.
  1. Build first: d365-build.ps1 -Model <Model> must report BUILD SUCCEEDED.
  2. Visual Studio > Extensions > Dynamics 365 > Deploy > Deploy models to online environment.
  3. Select the changed models, tick 'Synchronize database', Deploy.
  4. Watch the VS Output window for deploy and sync errors.
  Per project alternative: project Properties > 'Deploy changes to online environment' = True
  and 'Synchronize database' = True, then build the project in VS.
"@
    exit 3
}

if (-not $DbServer) { $DbServer = $d365.DbServer }
if (-not $Database) { $Database = $d365.Database }
if (-not $ConnectionString) {
    $ConnectionString = "Data Source=$DbServer;Initial Catalog=$Database;Integrated Security=True;Enlist=True;Application Name=SyncEngine"
}

try { $c = New-Object System.Data.SqlClient.SqlConnection "$ConnectionString;Connect Timeout=10"; $c.Open(); $c.Close() }
catch { Write-Host "Cannot open business DB '$Database' on '$DbServer': $($_.Exception.Message)"; exit 2 }

$syncExe = Join-Path $d365.BinPath 'SyncEngine.exe'
if (-not (Test-Path $syncExe)) { Write-Host "MISSING: $syncExe"; exit 2 }

$xargs = @("-metadatabinaries=$($d365.FrameworkPath)", "-connect=$ConnectionString", '-fallbacktonative=False', '-continueOnError=false')
if ($Full) { $xargs += '-syncmode=fullall' }
else {
    $xargs += '-syncmode=partiallist'
    if ($Tables)          { $xargs += "-synclist=$($Tables -join ',')" }
    if ($TableExtensions) { $xargs += "-tableextensionlist=$($TableExtensions -join ',')" }
}

$log = Join-Path $env:TEMP "SyncEngine_$(Get-Date -Format yyyyMMdd_HHmmss).log"
Write-Host "SyncEngine -> $Database on $DbServer  (log: $log)"
& $syncExe @xargs 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log |
    Select-String -Pattern 'error|fail|exception' | Select-Object -First 50 | ForEach-Object { Write-Host $_.Line }
$code = $LASTEXITCODE
if ($code -ne 0) { Write-Host "SYNC FAILED (exit $code). Full log: $log"; exit 1 }
Write-Host 'SYNC SUCCEEDED'
exit 0
