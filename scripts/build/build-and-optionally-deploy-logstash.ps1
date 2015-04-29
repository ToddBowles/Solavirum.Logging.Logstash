[CmdletBinding()]
param
(
    [switch]$deploy,
    [string]$environment,
    [string]$octopusServerUrl,
    [string]$octopusServerApiKey,
    [string[]]$projects
)

try
{
    $error.Clear()

    $ErrorActionPreference = "Stop"

    $here = Split-Path $script:MyInvocation.MyCommand.Path
    write-host "Script Root Directory is [$here]."

    . "$here\_Find-RootDirectory.ps1"

    $rootDirectory = Find-RootDirectory $here
    $rootDirectoryPath = $rootDirectory.FullName

    . "$rootDirectoryPath\scripts\common\Functions-Strings.ps1"

    if ($deploy)
    {
        $octopusServerUrl | ShouldNotBeNullOrEmpty -Identifier "OctopusServerUrl"
        $octopusServerApiKey | ShouldNotBeNullOrEmpty -Identifier "OctopusServerApiKey"
        $environment | ShouldNotBeNullOrEmpty -Identifier "ConfigId"
    }

    . "$rootDirectoryPath\scripts\common\Functions-Versioning.ps1"
    . "$rootDirectoryPath\scripts\common\Functions-Enumerables.ps1"

    $srcDirectoryPath = "$rootDirectoryPath\src"

    $sharedAssemblyInfo = (Get-ChildItem -Path "$srcDirectoryPath\Common" -Filter SharedAssemblyInfo.cs -Recurse) | Single
    $versionChangeResult = Update-AutomaticallyIncrementAssemblyVersion -AssemblyInfoFile $sharedAssemblyInfo

    write-host "##teamcity[buildNumber '$($versionChangeResult.New)']"

    . "$rootDirectoryPath\scripts\common\Functions-FileSystem.ps1"
    $buildDirectory = Ensure-DirectoryExists ([System.IO.Path]::Combine($rootDirectory.FullName, "build-output\$($versionChangeResult.New)"))

    $nuspecFile = Get-ChildItem -Path $srcDirectoryPath -Filter *.nuspec | Single

    . "$rootDirectoryPath\scripts\common\Functions-NuGet.ps1"

    NuGet-Pack $nuspecFile $buildDirectory -Version $versionChangeResult.New

    write-host "##teamcity[publishArtifacts '$($buildDirectory.FullName)']"

    if ($deploy)
    {
        Get-ChildItem -Path ($buildDirectory.FullName) | NuGet-Publish -ApiKey $octopusServerApiKey -FeedUrl "$octopusServerUrl/nuget/packages"

        . "$rootDirectoryPath\scripts\common\Functions-OctopusDeploy.ps1"
        
        if ($projects -eq $null)
        {
            $octopusProjectPrefix = "LOGSTASH_"
            Write-Verbose "No projects to deploy to have been specified. Deploying to all projects starting with [$octopusProjectPrefix]."
            $octopusProjects = Get-AllOctopusProjects -octopusServerUrl $octopusServerUrl -octopusApiKey $octopusServerApiKey | Where { $_.Name -like "$octopusProjectPrefix*" }

            if (-not ($octopusProjects | Any -Predicate { $true }))
            {
                throw "No Octopus Projects found to deploy to."
            }

            $projects = ($octopusProjects | Select -ExpandProperty Name)
        }

        foreach ($project in $projects)
        {
            New-OctopusRelease -ProjectName $project -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusServerApiKey -Version $versionChangeResult.New -ReleaseNotes "[SCRIPT] Automatic Release created as part of Build."
            New-OctopusDeployment -ProjectName $project -Environment "$environment" -Version $versionChangeResult.New -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusServerApiKey -Wait
        }
    }
}
finally
{
    if ($versionChangeResult -ne $null)
    {
        Write-Verbose "Restoring version to old version to avoid making permanent changes to the SharedAssemblyInfo file."
        $version = Set-AssemblyVersion $sharedAssemblyInfo $versionChangeResult.Old
    }
}
