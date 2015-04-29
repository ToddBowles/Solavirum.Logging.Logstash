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

Describe "Get-7ZipExecutable" {
    Context "When function executed" {
        It "Returns valid 7zip executable" {
            $executable = Get-7ZipExecutable

            $executable.FullName | Should Match ".7za."
            $executable.FullName | Should Exist
        }
    }
}

Describe "7Zip-ZipFiles" {
    BeforeEach {
        $workingDirectoryPath = Get-UniqueTestWorkingDirectory
    }

    Context "When single file supplied directly in arguments and destination is zip file that doesnt exist" {
        It "Should return a valid zip archive" {
            $file = New-Item "$workingDirectoryPath\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $archive = "$workingDirectoryPath\archive.zip"

            $archive = 7Zip-ZipFiles $file $archive

            $archive | Should Exist

            $unzipped = "$workingDirectoryPath\unzipped"

            7Zip-Unzip $archive $unzipped

            $items = (Get-ChildItem $unzipped -Recurse)
            ($items | Measure-Object).Count | Should Be 1

            "$unzipped\$($file.Name)" | Should Exist
        }
    }

    Context "When single file supplied directly in arguments and destination is zip file that DOES exist" {
        It "Should not throw an error" {
            $file = New-Item "$workingDirectoryPath\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $archive = New-Item "$workingDirectoryPath\archive.zip" -ItemType File -Force

            $archive = 7Zip-ZipFiles $file $archive

            $archive | Should Exist

            $unzipped = "$workingDirectoryPath\unzipped"

            7Zip-Unzip $archive $unzipped
        }
    }

    Context "When multiple files supplied directly in arguments" {
        It "Should return a valid zip archive" {
            $fileA = New-Item "$workingDirectoryPath\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $fileB = New-Item "$workingDirectoryPath\this-is-a-fake-code-file.cs" -ItemType File -Force

            $archive = "$workingDirectoryPath\archive.zip"

            $archive = 7Zip-ZipFiles @($fileA,$fileB) $archive

            $archive | Should Exist

            $unzipped = "$workingDirectoryPath\unzipped"

            7Zip-Unzip $archive $unzipped

            $actualCount = (Get-ChildItem $unzipped -Recurse | Measure-Object).Count
            $actualCount | Should Be 2
        }
    }

    Context "When additive switch specified" {
        It "Existing archive not deleted and file is added to it" {
            $fileA = New-Item "$workingDirectoryPath\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $fileB = New-Item "$workingDirectoryPath\this-is-a-fake-code-file.cs" -ItemType File -Force

            $archive = "$workingDirectoryPath\archive.zip"

            $archive = 7Zip-ZipFiles $fileA $archive

            $archive = 7Zip-ZipFiles $fileB $archive -Additive

            $unzipped = "$workingDirectoryPath\unzipped"

            7Zip-Unzip $archive $unzipped

            $actualCount = (Get-ChildItem $unzipped -Recurse | Measure-Object).Count
            $actualCount | Should Be 2
        }
    }

    AfterEach {
        if ([System.IO.Directory]::Exists($workingDirectoryPath))
        {
            [System.IO.Directory]::Delete($workingDirectoryPath, $true)
        }
    }
}

Describe "7Zip-ZipDirectories" {
    BeforeEach {
        $workingDirectoryPath = Get-UniqueTestWorkingDirectory
    }

    Context "When directory with multiple files (in subdirectories) supplied" {
        It "Should return a valid zip archive respecting directory structure of initial directory" {
            $fileA = New-Item "$workingDirectoryPath\scripts\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $fileB = New-Item "$workingDirectoryPath\scripts\common\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $fileC = New-Item "$workingDirectoryPath\tools\fake-tool.exe" -ItemType File -Force

            $archive = "$workingDirectoryPath\archive.zip"

            $archive = 7Zip-ZipDirectories @("$workingDirectoryPath\scripts", "$workingDirectoryPath\tools") $archive

            $unzipped = "$workingDirectoryPath\unzipped"

            $unzipped = 7Zip-Unzip $archive $unzipped

            $actualCount = (Get-ChildItem $unzipped -Recurse -File | Measure-Object).Count
            $actualCount | Should Be 3

            "$unzipped\scripts\this-is-a-fake-powershell-script.ps1" | Should Exist
            "$unzipped\scripts\common\this-is-a-fake-powershell-script.ps1" | Should Exist
            "$unzipped\tools\fake-tool.exe" | Should Exist
        }
    }

    Context "Using multiple directories with subdirectories and excluding some subdirectories" {
        It "Should return a valid zip archive that does not contain the excluded subdirectories" {
            $fileA = New-Item "$workingDirectoryPath\scripts\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $fileB = New-Item "$workingDirectoryPath\scripts\common\this-is-a-fake-powershell-script.ps1" -ItemType File -Force
            $fileC = New-Item "$workingDirectoryPath\tools\fake-tool.exe" -ItemType File -Force
            $fileD = New-Item "$workingDirectoryPath\tools\excluded\totally-not-included.exe" -ItemType File -Force
            $fileE = New-Item "$workingDirectoryPath\tools\excluded\also-excluded\totally-not-included-as-well.cs" -ItemType File -Force

            $archive = "$workingDirectoryPath\archive.zip"

            $archive = 7Zip-ZipDirectories @("$workingDirectoryPath\scripts", "$workingDirectoryPath\tools") $archive -SubdirectoriesToExclude @("excluded", "common")

            $unzipped = "$workingDirectoryPath\unzipped"

            $unzipped = 7Zip-Unzip $archive $unzipped

            $actualCount = (Get-ChildItem $unzipped -Recurse -File | Measure-Object).Count
            $actualCount | Should Be 2

            "$unzipped\scripts\this-is-a-fake-powershell-script.ps1" | Should Exist
            "$unzipped\scripts\common\this-is-a-fake-powershell-script.ps1" | Should Not Exist
            "$unzipped\tools\fake-tool.exe" | Should Exist
            "$unzipped\tools\excluded\totally-not-included.exe" | Should Not Exist
            "$unzipped\tools\excluded\also-excluded\totally-not-included-as-well.cs" | Should Not Exist
        }
    }

    AfterEach {
        if ([System.IO.Directory]::Exists($workingDirectoryPath))
        {
            [System.IO.Directory]::Delete($workingDirectoryPath, $true)
        }
    }
}