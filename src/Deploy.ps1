[CmdletBinding()]
param
(

)

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$rootDirectory = new-object System.IO.DirectoryInfo $here
$rootDirectoryPath = $rootDirectory.FullName

. "$rootDirectoryPath\scripts\Functions-Configuration.ps1"

$configId = "default"
$logServerAddress = "not-a-real-address"
$substitutions = @{}
if ($OctopusParameters -ne $null)
{
    $configId = ($OctopusParameters["Octopus.Project.Name"]).Replace("LOGSTASH_", "")
    $logServerAddress = $OctopusParameters["LogServerAddress"]
    $substitutionsFunction = "Get-SubstitutionsFor$($configId.Replace(""."", """"))"
    try
    {
        $substitutions = & $substitutionsFunction
    }
    catch 
    {
        Write-Warning "The function [$substitutionsFunction] could not be found. This might be an error, or there just might not be any substitutions specific to the configuration."
        Write-Warning $_ 
    }
}

. "$rootDirectoryPath\scripts\Functions-Logstash.ps1"

Remove-LogstashService $configId

$configurationFile = Configure-Logstash -LogServerAddress $logServerAddress -ConfigId $configId -substitutions $substitutions

Install-LogstashService $configId $configurationFile