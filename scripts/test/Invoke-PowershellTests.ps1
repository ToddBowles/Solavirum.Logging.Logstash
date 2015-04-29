[CmdletBinding()]
param
(
    [string]$specificTestNames="*",
    [hashtable]$globalCredentialsLookup
)

$error.Clear()

$ErrorActionPreference = "Stop"

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RootDirectory.ps1"

$rootDirectoryPath = (Find-RootDirectory $currentDirectoryPath).FullName
$scriptsDirectoryPath = "$rootDirectoryPath\scripts"
$commonScriptsDirectoryPath = "$scriptsDirectoryPath\common"

. "$commonScriptsDirectoryPath\functions-enumerables.ps1"

$toolsDirectoryPath = "$rootDirectoryPath\tools"
$nuget = "$toolsDirectoryPath\nuget.exe"

$nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"
$pesterVersion = "3.3.6"
& $nuget install Pester -Version $pesterVersion -OutputDirectory $nugetPackagesDirectoryPath | Write-Verbose

$pesterDirectoryPath = ((Get-ChildItem -Path $nugetPackagesDirectoryPath -Directory -Filter Pester.$pesterVersion) | Single).FullName

Import-Module "$pesterDirectoryPath\tools\Pester.psm1"
$scriptsResult = Invoke-Pester -Strict -Path $scriptsDirectoryPath -TestName $specificTestNames -PassThru
$sourceResult = Invoke-Pester -Strict -Path "$rootDirectoryPath\src\scripts" -TestName $specificTestNames -PassThru

Write-Output "Total Failed: $($scriptsResult.FailedCount + $sourceResult.FailedCount)"
Write-Output "Total Passed: $($scriptsResult.PassedCount + $sourceResult.PassedCount)"
Write-Output "Total Failed: $($scriptsResult.SkippedCount + $sourceResult.SkippedCount)"
Write-Output "Total Time Taken: $($scriptsResult.Time + $sourceResult.Time)"
