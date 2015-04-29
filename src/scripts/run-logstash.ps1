[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true)]
    [System.IO.FileInfo]$configFile
)

$ErrorActionPreference = "Stop"

$here = Split-Path $script:MyInvocation.MyCommand.Path

. "$here\_Find-RootDirectory.ps1"

$rootDirectory = Find-RootDirectory $here
$rootDirectoryPath = $rootDirectory.FullName

. "$rootDirectoryPath\scripts\Functions-Logstash.ps1"

Execute-Logstash -AdditionalArguments @("agent", "-f", $configFile.FullName) -Verbose