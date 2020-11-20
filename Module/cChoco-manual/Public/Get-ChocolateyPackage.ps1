#Requires -Modules Invoke-CommandAs

function Get-ChocolateyPackage {
    [CmdletBinding()]
    param (
        # ComputerName
        [Parameter(Mandatory = $false)]
        [string]
        $ComputerName,
        # Credential
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credentials,
        [parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        [parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,
        [parameter()]
        [string]
        $Source,
        [switch]
        $Online,
        [switch]
        $AllVersions,
        [switch]
        $AllPackages,
        [switch]
        $Local
    )
    
    begin {
        #Establish Session and ScriptBlock
        try {
            $ScriptBlock = {
                [array]$array = @()
                $array += choco source list -r | ConvertFrom-Csv -Header 'Name', 'Source', 'Disabled', 'User', 'Cert', 'Priority', 'BypassProxy', 'SelfService', 'AdminOnly' -Delimiter "|"
                $array += [PSCustomObject]@{
                    Name        = $env:COMPUTERNAME
                    Source      = (Join-Path $env:ChocolateyInstall "lib")
                    Disabled    = $false
                    User        = ""
                    Cert        = ""
                    Priority    = -1
                    BypassProxy = $false
                    SelfService = $false
                    AdminOnly   = $false
                }
                return $array
            }            
        }
        catch {
            throw $_.Exception.Message
            break            
        }
    }
    
    process {
        try {
            if (-not($ComputerName)) {
                $ComputerName = $env:COMPUTERNAME
            }
            $Session = New-PSSession $ComputerName -EnableNetworkAccess

            if (-not($Source)) {
                $InvokeParams = @{
                    Session     = $Session
                    ScriptBlock = $ScriptBlock
                }            
                $Sources = Invoke-Command @InvokeParams | Select-Object * -ExcludeProperty RunspaceId, PSComputerName
                if ($Local) {
                    $Sources = $Sources | Where-Object { $_.Priority -eq -1 }
                }
                if ($Online) {
                    $Sources = $Sources | Where-Object { $_.Priority -ne -1 }
                }
            }           
            
            function Get-ChocoVersion {
                [CmdletBinding()]
                param (
                    [switch]$Purge,
                    [switch]$NoCache
                )
                
                $chocoInstallCache = Join-Path -Path $env:ChocolateyInstall -ChildPath 'cache'
                if ( -not (Test-Path $chocoInstallCache)) {
                    New-Item -Name 'cache' -Path $env:ChocolateyInstall -ItemType Directory | Out-Null
                }
                $chocoVersion = Join-Path -Path $chocoInstallCache -ChildPath 'ChocoVersion.xml'
                
                if ($Purge.IsPresent) {
                    Remove-Item $chocoVersion -Force
                    $res = $true
                }
                else {
                    $cacheSec = (Get-Date).AddSeconds('-60')
                    if ( $cacheSec -lt (Get-Item $chocoVersion -ErrorAction SilentlyContinue).LastWriteTime ) {
                        $res = Import-Clixml $chocoVersion
                    }
                    else {
                        $cmd = choco -v
                        $res = [System.Version]($cmd.Split('-')[0])
                        $res | Export-Clixml -Path $chocoVersion
                    }
                }
                Return $res
            }
            [array]$return = @()
            $Sources | ForEach-Object {
                $Source = $_.Source
                [array]$chocoParams = @()
                if ($AllPackages) {
                    $chocoParams += 'all'
                }
                else {
                    $chocoParams += '--by-id-only'
                    $chocoParams += $Name                    
                }
                
                if ($AllVersions) {
                    $chocoParams += '--all-versions'
                }
                elseif ($Version) {
                    $chocoParams += "--version=`'$Version`'"
                }
                # Check if Chocolatey version is Greater than 0.10.4, and add --no-progress 
                #if ((Get-ChocoVersion -ErrorAction SilentlyContinue) -ge [System.Version]('0.10.4')) {
                #    $chocoParams += "--no-progress"
                #}
                $chocoParams += "--source=`'$Source'"
                $chocoParams += '--limit-output'
                $chocoParams += "--no-progress"
                
                $object = choco list $chocoParams | ConvertFrom-Csv -Header 'Name', 'Version' -Delimiter "|"
                $object | Add-Member -Name SourceName -MemberType NoteProperty -Value $_.Name
                $object | Add-Member -Name Source -MemberType NoteProperty -Value $Source
                $object | Add-Member -Name ComputerName -MemberType NoteProperty -Value $ComputerName

                $return += $object    
            }   
            $return
        }
        catch {
            throw $_
        }       

    }
    
    end {
        $Session | Remove-PSSession -ErrorAction SilentlyContinue
    }
}