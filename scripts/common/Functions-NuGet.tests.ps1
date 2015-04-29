$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -ireplace "tests.", ""
. "$here\$sut"

. "$currentDirectoryPath\_Find-RootDirectory.ps1"
$rootDirectory = Find-RootDirectory $here

function Get-UniqueTestWorkingDirectory
{
    $tempDirectoryName = [System.Guid]::NewGuid().ToString()
    return "$here\test-working\$tempDirectoryName"
}

Describe "Get-NuGetExecutable" {
    Context "When function executed" {
        It "Returns valid NuGet executable" {
            $executable = Get-NuGetExecutable

            $executable.FullName | Should Match "nuget\.exe"
            $executable.FullName | Should Exist
        }
    }
}

Describe "NuGet-Publish" {
    BeforeEach {
        $workingDirectoryPath = Get-UniqueTestWorkingDirectory
    }

    Context "When multiple packages supplied via pipeline input" {
        It "Executes publish over all packages supplied" {
            $fileA = New-Item "$workingDirectoryPath\woepk.nupkg" -ItemType File -Force
            $fileB = New-Item "$workingDirectoryPath\giyud.nupkg" -ItemType File -Force

            $DI_WriteNuGetPathAndArgumentsToOutput = { 
                param
                (
                    [System.IO.FileInfo]$nugetExecutable, 
                    [array]$arguments
                ) 
            
                write-output "(& `"$($nugetExecutable.FullName)`" $arguments)"
            }

            $output = get-childitem -Path $workingDirectoryPath -Filter *.nupkg | NuGet-Publish -ApiKey "NO" -FeedUrl "This is not a URL" -DI_ExecutePublishUsingNuGetExeAndArguments $DI_WriteNuGetPathAndArgumentsToOutput

            $output | Any -Predicate { $_ -match "(.*)$($fileA.Name)(.*)" } | Should Be $true
            $output | Any -Predicate { $_ -match "(.*)$($fileB.Name)(.*)" } | Should Be $true
        }
    }

    AfterEach {
        if ([System.IO.Directory]::Exists($workingDirectoryPath))
        {
            [System.IO.Directory]::Delete($workingDirectoryPath, $true)
        }
    }
}