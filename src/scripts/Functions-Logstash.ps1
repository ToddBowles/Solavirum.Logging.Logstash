function Ensure-JavaRuntimeEnvironmentIsAvailable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $jreId = "jre-1.8.0_40"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"
    $packagesDirectoryPath = "$toolsDirectoryPath\packages"
    $jreDirectoryPath = "$packagesDirectoryPath\$jreId"
    if (Test-Path $jreDirectoryPath)
    {
        Write-Verbose "JRE already available at [$jreDirectoryPath]."
    }
    else
    {
        $jreArchiveFile = Get-ChildItem -Path $toolsDirectoryPath -Filter "$jreId.7z" |
            Single

        Write-Verbose "Extracting JRE archive at [$($jreArchiveFile.FullName)]"
        $extractedDirectory = 7Zip-Unzip -Archive $jreArchiveFile -DestinationDirectory $packagesDirectoryPath
    }

    return "$jreDirectoryPath\bin"
}

function Ensure-LogstashIsAvailable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $appId = "logstash-1.5.0.rc2"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"
    $packagesDirectoryPath = "$toolsDirectoryPath\packages"
    $appDirectoryPath = "$packagesDirectoryPath\$appId"
    if (Test-Path $appDirectoryPath)
    {
        Write-Verbose "$appId already available at [$appDirectoryPath]."
    }
    else
    {
        $appArchiveFile = Get-ChildItem -Path $toolsDirectoryPath -Filter "$appId.7z" |
            Single

        Write-Verbose "Extracting $appId archive at [$($appArchiveFile.FullName)]"
        $extractedDirectory = 7Zip-Unzip -Archive $appArchiveFile -DestinationDirectory $packagesDirectoryPath
    }

    return "$appDirectoryPath\bin\logstash.bat"
}

function Execute-Logstash
{
    [CmdletBinding()]
    param
    (
        [array]$additionalArguments,
        [int]$allocatedMemory=512
    )

    $app = Ensure-LogstashIsAvailable
    $jreBinDirectoryPath = Ensure-JavaRuntimeEnvironmentIsAvailable

    $env:Path = "$jreBinDirectoryPath;$env:Path"
    $env:JAVA_HOME = (new-object System.IO.DirectoryInfo($jreBinDirectoryPath)).Parent.FullName

    $arguments = @()
    $arguments += $additionalArguments
    $arguments += "--verbose"

    $env:JVM_ARGS = "-Xms$($allocatedMemory.ToString())m -Xmx$($allocatedMemory.ToString())m"

    if ($env:HTTP_PROXY -ne $null)
    {
        $proxy = $env:HTTP_PROXY
        $regexMatch = (select-string -InputObject $proxy -Pattern "http://(.*):(.*)").Matches[0]
        $address = $regexMatch.Groups[1].Value
        $port = $regexMatch.Groups[2].Value

        $env:LS_JAVA_OPTS="-Dhttp.proxyHost=$address -Dhttp.proxyPort=$port"
    }

    Write-Verbose "$app $arguments"
    & $app $arguments
}

function Configure-Logstash
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$logServerAddress,
        [string]$configId,
        [hashtable]$substitutions
    )

    if ($substitutions -eq $null)
    {
        $substitutions = @{}
    }

    $substitutions.Add("@@LOG_SERVER_ADDRESS", $logServerAddress)

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $rootDirectoryPath = $rootDirectory.FullName
    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-FileSystem.ps1"

    $baseConfig = "$rootDirectoryPath\configuration\$configId.conf"
    if (-not (Test-Path $baseConfig))
    {
        throw "The configId specified [$configId] was not valid. No configuration file could be found."
    }

    $tempConfigFile = "$rootDirectoryPath\configuration\script-working\logstash-$([Guid]::NewGuid().ToString("N")).conf"
    $tempConfigFile = New-Item -Path $tempConfigFile -Force -Type "File"

    Write-Verbose "Mutating Configuration file at [$($tempConfigFile.FullName)]."
    $tempConfigFile = ReplaceTokensInFile $baseConfig $tempConfigFile $substitutions

    return $tempConfigFile
}

function ReplaceTokensInFile
{
    [CmdletBinding()]
    param
    (
        [System.IO.FileInfo]$source,
        [System.IO.FileInfo]$destination,
        [hashtable]$substitutions
    )
        
    $content = Get-Content $source
    foreach ($token in $substitutions.Keys)
    {
        $content = $content -replace $token, $substitutions.Get_Item($token)
    }  
    Set-Content $destination $content

    return $destination
}

function Get-ServiceName
{
    [CmdletBinding()]
    param
    (
        [string]$configId
    )

    $serviceName = "logstash-$configid"
    
    return $serviceName
}

function Remove-LogstashService
{
    [CmdletBinding()]
    param
    (
        [string]$configId
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $rootDirectoryPath = $rootDirectory.FullName
    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Nssm.ps1"

    $serviceName = Get-ServiceName $configId
    try
    {
        $service = Get-Service -Name $serviceName
        if ($service -ne $null)
        {
            if ($service.Status -eq "Running")
            {
                $service.Stop()
                $service.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
            }
            Nssm-Remove $serviceName
        }
    }
    catch
    {
        Write-Warning "Could not detect existing service. Check the following text to see if its some sort of access issue."
        Write-Warning $_
    }
}

function Install-LogstashService
{
    [CmdletBinding()]
    param
    (
        [string]$configId,
        [System.IO.FileInfo]$configFile
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $rootDirectoryPath = $rootDirectory.FullName
    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Nssm.ps1"

    $serviceName = Get-ServiceName $configId

    $programFilePath = "$rootDirectory\script-working\execute-logstash-$configId.bat"
    $file = New-Item -ItemType File -Path $programFilePath -Force
    Add-Content -Path $programFilePath -Value "powershell.exe -executionpolicy remotesigned -command ""$rootDirectoryPath\scripts\run-logstash.ps1"" -ConfigFile ""$($configFile.FullName)"""

    Nssm-Install $serviceName $programFilePath

    $service = Get-Service $serviceName
    $service.Start()
    $service.WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
}