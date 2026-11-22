<#
.SYNOPSIS
  Detects the D365 F&O development environment. Dot-sourced by d365-build.ps1 and d365-dbsync.ps1.

.DESCRIPTION
  Supported environments, checked in this order:
    1. Explicit paths passed by the caller (-MetadataPath / -FrameworkPath).
    2. UDE (Unified Developer Experience): %LOCALAPPDATA%\Microsoft\Dynamics365\XPPConfig\*.json
       written by the Power Platform Tools VS extension. Custom metadata = ModelStoreFolder,
       standard packages = FrameworkDirectory. With several configs the newest is used,
       or the one whose file name contains -XppConfigName.
    3. Classic dev VM / cloud-hosted environment: registry
       HKLM\SOFTWARE\Microsoft\Dynamics\AX\7.0\SDK (MetadataPath), otherwise the first existing
       <drive>:\AosService\PackagesLocalDirectory. Custom and standard packages share one folder.
#>

function Get-D365Environment {
    param(
        [string]$MetadataPath,
        [string]$FrameworkPath,
        [string]$XppConfigName
    )

    $envInfo = [ordered]@{
        Mode = $null; MetadataPath = $null; FrameworkPath = $null; ReferencePaths = @(); BinPath = $null
        DbServer = $null; Database = $null; CloudUrl = $null; Source = $null
    }

    if ($MetadataPath) {
        $envInfo.Mode = 'Explicit'
        $envInfo.MetadataPath  = $MetadataPath
        $envInfo.FrameworkPath = if ($FrameworkPath) { $FrameworkPath } else { $MetadataPath }
        $envInfo.Source = 'parameters'
    }
    else {
        $cfgDir  = Join-Path $env:LOCALAPPDATA 'Microsoft\Dynamics365\XPPConfig'
        $configs = @(Get-ChildItem $cfgDir -Filter *.json -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($XppConfigName) { $configs = @($configs | Where-Object { $_.Name -like "*$XppConfigName*" }) }

        if ($configs.Count -gt 0) {
            $cfg = Get-Content $configs[0].FullName -Raw | ConvertFrom-Json
            $envInfo.Mode          = 'UDE'
            $envInfo.MetadataPath  = $cfg.ModelStoreFolder
            $envInfo.FrameworkPath = $cfg.FrameworkDirectory
            $envInfo.ReferencePaths = @($cfg.ReferencePackagesPaths)
            $envInfo.DbServer = $cfg.DatabaseServer
            $envInfo.Database = $cfg.BusinessDatabaseName
            $envInfo.CloudUrl = $cfg.CloudInstanceURL
            $envInfo.Source   = $configs[0].FullName
        }
        else {
            $sdk = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Dynamics\AX\7.0\SDK' -ErrorAction SilentlyContinue
            $pld = if ($sdk -and $sdk.MetadataPath -and (Test-Path $sdk.MetadataPath)) { $sdk.MetadataPath } else {
                Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path $_.Root 'AosService\PackagesLocalDirectory' } |
                    Where-Object { Test-Path $_ } | Select-Object -First 1
            }
            if ($pld) {
                $envInfo.Mode = 'Classic'
                $envInfo.MetadataPath  = $pld
                $envInfo.FrameworkPath = $pld
                $envInfo.Source = if ($sdk) { 'registry SDK key' } else { 'AosService folder' }
                $webConfig = Join-Path (Split-Path $pld -Parent) 'webroot\web.config'
                if (Test-Path $webConfig) {
                    [xml]$wc = Get-Content $webConfig -Raw
                    $settings = $wc.configuration.appSettings.add
                    $envInfo.DbServer = ($settings | Where-Object key -eq 'DataAccess.DbServer').value
                    $envInfo.Database = ($settings | Where-Object key -eq 'DataAccess.Database').value
                }
                if (-not $envInfo.DbServer) { $envInfo.DbServer = 'localhost' }
                if (-not $envInfo.Database) { $envInfo.Database = 'AxDB' }
            }
        }
    }

    if (-not $envInfo.MetadataPath -or -not (Test-Path $envInfo.MetadataPath)) {
        throw "No D365 F&O environment found. Pass -MetadataPath (custom metadata) and -FrameworkPath (standard PackagesLocalDirectory)."
    }
    $envInfo.BinPath = Join-Path $envInfo.FrameworkPath 'bin'
    $envInfo.ReferencePaths = @(@($envInfo.FrameworkPath) + $envInfo.ReferencePaths + @($envInfo.MetadataPath) |
        Where-Object { $_ -and (Test-Path $_) } | ForEach-Object { (Resolve-Path $_).Path.TrimEnd('\') } | Select-Object -Unique)
    [pscustomobject]$envInfo
}

# Package folder names referenced by a package's descriptors.
function Get-D365PackageReferences([string]$MetadataPath, [string]$Package) {
    Get-ChildItem (Join-Path $MetadataPath "$Package\Descriptor") -Filter *.xml -ErrorAction SilentlyContinue | ForEach-Object {
        [xml]$d = Get-Content $_.FullName -Raw
        @($d.AxModelInfo.ModuleReferences.string)
    } | Where-Object { $_ -and $_ -ne $Package } | Select-Object -Unique
}

# True when the package lives in the metadata folder and is not published by Microsoft.
function Test-D365CustomPackage([string]$MetadataPath, [string]$Package) {
    $descriptors = @(Get-ChildItem (Join-Path $MetadataPath "$Package\Descriptor") -Filter *.xml -ErrorAction SilentlyContinue)
    if ($descriptors.Count -eq 0) { return $false }
    foreach ($f in $descriptors) {
        [xml]$d = Get-Content $f.FullName -Raw
        if ($d.AxModelInfo.Publisher -ne 'Microsoft Corporation') { return $true }
    }
    $false
}
