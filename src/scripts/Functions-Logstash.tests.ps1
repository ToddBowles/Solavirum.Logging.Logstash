$here = Split-Path $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -ireplace "tests.", ""
. "$here\$sut"

. "$here\_Find-RootDirectory.ps1"
$rootDirectory = Find-RootDirectory $here

function Get-UniqueTestWorkingDirectory
{
    $tempDirectoryName = [System.Guid]::NewGuid().ToString("N")
    return "$here\test-working\$tempDirectoryName"
}

Describe "ReplaceTokensInFile" {
    BeforeEach {
        $workingDirectoryPath = Get-UniqueTestWorkingDirectory
    }

    Context "When supplied with a valid source and destination file and some valid substitutions" {
        It "Destination file contains substituted values" {
            $substitutions = @{
                [Guid]::NewGuid().ToString("N")=[Guid]::NewGuid().ToString("N");
                [Guid]::NewGuid().ToString("N")=[Guid]::NewGuid().ToString("N");
            }

            $sourceFile = New-Item -Path "$workingDirectoryPath\source.txt" -Force -Type "File"
            $substitutions.Keys | Set-Content $sourceFile

            $destinationFile = New-Item -Path "$workingDirectoryPath\destination.txt" -Force -Type "File"

            $destinationFile = ReplaceTokensInFile -Source $sourceFile -Destination $destinationFile -Substitutions $substitutions

            $substitutions.Keys | % { $sourceFile | Should Contain $_ }
            $substitutions.Values | % { $sourceFile | Should Not Contain $_ }

            $substitutions.Keys | % { $destinationFile | Should Not Contain $_ }
            $substitutions.Values | % { $destinationFile | Should Contain $_ }
        }
    }

    AfterEach {
        Remove-Item -Path $workingDirectoryPath -Force -Recurse
    }
}