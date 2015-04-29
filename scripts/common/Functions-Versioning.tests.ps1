$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -ireplace "tests.", ""
. "$here\$sut"

. "$currentDirectoryPath\_Find-RootDirectory.ps1"
$rootDirectory = Find-RootDirectory $here
$rootDirectoryPath = $rootDirectory.FullName

function Get-UniqueTestWorkingDirectory
{
    $tempDirectoryName = [System.Guid]::NewGuid().ToString()
    return "$here\test-working\$tempDirectoryName"
}

Describe "Update-AutomaticallyIncrementAssemblyVersion" {
    BeforeEach {
        $workingDirectoryPath = Get-UniqueTestWorkingDirectory
    }

    Context "When valid AssemblyInfo file supplied" {
        It "Return value contains valid new version" {
            $assemblyInfo = New-Item "$workingDirectoryPath\AssemblyInfo.cs" -ItemType File -Force
            Set-Content $assemblyInfo '[assembly: AssemblyVersion("1.2.0.0")]'

            $result = Update-AutomaticallyIncrementAssemblyVersion $assemblyInfo

            $result.Old | Should Be '1.2.0.0'
            $result.New | Should Not Be '1.2.0.0'
            $result.New | Should Not BeNullOrEmpty
        }
    }

    AfterEach {
        if ([System.IO.Directory]::Exists($workingDirectoryPath))
        {
            [System.IO.Directory]::Delete($workingDirectoryPath, $true)
        }
    }
}

Describe "Get-IncrementedVersion" {
    Context "When supplied existing Major and Minor" {
        It "Returns version with same Major & Minor but with Build/Revision set to time specific values" {
            $expectedSystemDate = new-object DateTime(2012, 1, 1, 1, 12, 33)
            $result = Get-IncrementedVersion 1 2 -DI_GetSystemUtcDateTime { return $expectedSystemDate }.GetNewClosure()

            $result.Major | Should Be 1
            $result.Minor | Should Be 2
            $result.Build | Should Be 12001
            $result.Revision | Should Be 2176
        }
    }
}
