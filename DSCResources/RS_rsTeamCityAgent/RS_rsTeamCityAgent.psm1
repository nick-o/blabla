function Get-TargetResource
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AgentName,
        [string]$AgentPath = $($env:SystemDrive,"BuildAgent" -join '\'),
        [string]$AgentPort = 9090,
        [string]$AgentStatus = "Running",
        [string]$ServerURL = "http://localhost:8090/",
        [string]$workDir = "../work",
        [string]$tempDir = "../temp",
        [string]$systemDir = "../system",
        [Boolean]$Firewall = $true,
        [ValidateSet("Present", "Absent")]
        [string] $Ensure = "Present"
    )


    $PathCheck = (Test-path $AgentPath)
    $ServiceCheck = (Get-Service | where-object Name -Like "TCBuildAgent*").count -gt 0
    $ServiceStatus = (Get-Service | where-object Name -Like "TCBuildAgent*").Status -eq $AgentStatus
    $PortListen = [bool](Get-NetTCPConnection | Where-Object LocalPort -eq $AgentPort)
    if($Firewall -eq $true)
    {$FirewallCheck = [bool](Get-NetFirewallRule | Where-Object DisplayName -like "TeamCityPort: $AgentPort")}
    else{$FirewallCheck = "Disabled"}
    if ($PathCheck -and $ServiceCheck){$EnsureCheck = "Present"}
    else {$EnsureCheck = "Absent"}
    
    Return @{
            AgentName = $AgentName;
            AgentPath = $PathCheck;
            AgentStatus = $ServiceStatus;
            AgentPort = [bool]($PortListen -eq "200");
            Firewall = $FirewallCheck
            Ensure = $EnsureCheck
            }
}

function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AgentName,
        [string]$AgentPath = $($env:SystemDrive,"BuildAgent" -join '\'),
        [string]$AgentPort = 9090,
        [string]$AgentStatus = "Running",
        [String]$ServerURL = "http://localhost:8090/",
        [string]$workDir = "../work",
        [string]$tempDir = "../temp",
        [string]$systemDir = "../system",
        [Boolean]$Firewall = $true,
        [ValidateSet("Present", "Absent")]
        [string] $Ensure = "Present"
    )


    #Set Desired variable end characters
    if ($PSBoundParameters.AgentPath[-1] -eq "\") {$AgentPath = $PSBoundParameters.AgentPath.Substring(0,$AgentPath.length-1)}
    if ($PSBoundParameters.ServerURL[-1] -ne "/") {$ServerURL = $PSBoundParameters.ServerURL + "/"}

    $CurrentState = (Get-TargetResource @PSboundParameters)
    if ($Ensure -eq "Present")
    {
        if (-not ($CurrentState.AgentPath)){ New-Item -ItemType Directory -Path $AgentPath }
        if (-not (Test-path $($AgentPath + "\conf\buildAgent.properties")))
        {
            Invoke-WebRequest -URI $($ServerURL + "update/buildAgent.zip") -Method GET -OutFile $env:TEMP\buildAgent.zip -ErrorAction SilentlyContinue
            Extract-ZipFile -Zipfile $env:TEMP\BuildAgent.zip -DestinationPath C:\BuildAgent
            Remove-Item -Path $env:TEMP\buildAgent.zip -Force
            $buildagentconfig = (Get-content -Path $($AgentPath + "\conf\buildAgent.dist.properties")) | Foreach-Object {
                $_ -replace 'serverUrl=http://localhost:8111/',"serverUrl=$ServerUrl" `
                -replace 'name=',"name=$AgentName" `
                -replace 'ownPort=9090',"ownPort=$AgentPort" `
                -replace 'workDir=../work',"workDir=$workDir" `
                -replace 'tempDir=../temp',"tempDir=$tempDir" `
                -replace 'systemDir=../system',"systemDir=$systemDir"
                } | Set-Content $($AgentPath + "\conf\buildAgent.properties")

            Try{
                cd ($AgentPath + "\bin")
                & $($AgentPath + "\bin\service.install.bat")
                & $($AgentPath + "\bin\service.start.bat")
            }
            Catch{write-verbose "Agent Installation Failed:\n $_"}

            if($Firewall)
            {
                $HostValue = $ServerURL.Split("//")[2].Split(":")[0]
                if([System.Net.IPAddress]::Parse($HostValue)){$HostIP = $HostValue}
                else {$HostIP = [System.Net.DNS]::GetHostAddresses($HostValue)[0]}
                Write-Verbose $HostIP
                if (Get-NetFirewallRule | Where-Object DisplayName -like "TeamCityPort: $AgentPort")
                {Set-NetFirewallRule -DisplayName "TeamCityPort: $AgentPort" -Direction Inbound -Protocol TCP -LocalPort $AgentPort -RemoteAddress $HostIP -Action Allow}
                else
                {New-NetFirewallRule -DisplayName "TeamCityPort: $AgentPort" -Direction Inbound -Protocol TCP -LocalPort $AgentPort -RemoteAddress $HostIP -Action Allow}
            }
        }
    }
    else
    {
        While (Get-Service | where-object Name -Like "TCBuildAgent*")
        {
            Write-Verbose "Setting TeamCity Agent $AgentName Absent"
            if ($CurrentState.AgentStatus)
            {
                Write-Verbose "Removing Agent Service."
                cd ($AgentPath + "\bin")
                & $($AgentPath + "\bin\service.stop.bat")
                & $($AgentPath + "\bin\service.uninstall.bat")
                if($Firewall){Get-NetFirewallRule | where-object DisplayName -like "TeamCityPort: $AgentPort" | Remove-NetFirewallRule}
                $CurrentState = Get-TargetResource @PSBoundParameters
            }
        }
        if ($CurrentState.AgentPath -and (-not (Get-Service | where-object Name -Like "TCBuildAgent*")))
        {
            Write-Verbose "Removing Path Contents: $AgentPath"
            cd $env:TEMP
            Remove-Item -Path $AgentPath -Recurse -Force
        }
        
    }
}


function Test-TargetResource
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AgentName,
        [string]$AgentPath = $($env:SystemDrive,"BuildAgent" -join '\'),
        [string]$AgentPort = 9090,
        [string]$AgentStatus = "Running",
        [String]$ServerURL = "http://localhost:8090/",
        [string]$workDir = "../work",
        [string]$tempDir = "../temp",
        [string]$systemDir = "../system",
        [Boolean]$Firewall = $true,
        [ValidateSet("Present", "Absent")]
        [string] $Ensure = "Present"
    )


    Write-Verbose "Getting Current State Info"
    $CurrentState = (Get-TargetResource @PSboundParameters)
        if (($Ensure -eq "Present") `
    -and ($CurrentState.Ensure -eq $Ensure) `
    -and ($CurrentState.AgentPath -eq $true) `
    -and ($CurrentState.AgentPort -eq $true) `
    -and ($CurrentState.AgentStatus -eq $true) `
    -and ($CurrentState.Firewall -ne $false) `
    )
    {Return $true}
    elseif (($Ensure -eq "Absent") -and ($CurrentState.Ensure -eq $Ensure) -and ($CurrentState.AgentPath -eq $false))
    {Return $true}
    else {Return $false}
}



Function Extract-ZipFile([string]$ZipFile,[string]$DestinationPath)
{
    Add-Type -AssemblyName "system.io.compression.filesystem"
    [io.compression.zipfile]::ExtractToDirectory
    $shell = New-Object -ComObject shell.application
    if(!(Test-Path $ZipFile)){Return "$zipfile not found."}
    else{
        $ZipPath = $((Get-Item $ZipFile).FullName)
        $ZipObject = $shell.NameSpace("$ZipPath")
    }
    if(!$PSBoundParameters.DestinationPath)
    {$DestinationPath = $($ZipObject.Self.Path.Split(".")[0])}
    if(Test-Path $DestinationPath){Remove-Item -Path $DestinationPath -Recurse -Force}
    [io.compression.zipfile]::ExtractToDirectory((Get-Item $ZipFile).FullName,$DestinationPath)
}

Export-ModuleMember -Function *-TargetResource