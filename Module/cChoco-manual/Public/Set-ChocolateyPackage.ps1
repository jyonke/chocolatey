#Requires -Modules Invoke-CommandAs

function Set-ChocolateyPackage {
    [CmdletBinding()]
    param (
        # ComputerName
        [Parameter(Mandatory = $false,ValueFromPipelineByPropertyName=$true)]
        [string]
        $ComputerName,
        # Credential
        [Parameter(Mandatory = $false,ValueFromPipelineByPropertyName=$true)]
        [pscredential]
        $Credentials,
        [parameter(Mandatory,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present',
        [ValidateNotNullOrEmpty()]
        [string]
        $Params,
        [parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,
        [parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        $Source,
        [ValidateNotNullOrEmpty()]
        [String]
        $chocoParams,
        [bool]
        $AutoUpgrade = $false
    )
    
    begin {
        #Establish Session
        try {
            $ModuleBase = (Split-Path -parent $PSScriptRoot)
            $ModulePath = (Join-Path "$ModuleBase\Private\DSCResources" "cChocoPackageInstall")
            $ModuleContent = Get-Content (Get-ChildItem -Path $ModulePath -Filter *.psm1).FullName
            $ScriptBlockImport = {
                $using:ModuleContent | Set-Content "$env:SystemRoot\Temp\cChocoPackageInstall.psm1" -Force
            }
            $ScriptBlockSet = {
                $null = Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
                $null = Import-Module "$env:SystemRoot\Temp\cChocoPackageInstall.psm1"
                $Configuration = @{}
                $object = [PSCustomObject]@{}                
                if ($args[0]) { $Configuration.Name = $args[0];$object | Add-Member -MemberType NoteProperty -Name "Name" -Value $args[0] }
                if ($args[1]) { $Configuration.Ensure = $args[1];$object | Add-Member -MemberType NoteProperty -Name "Ensure" -Value $args[1] }
                if ($args[2]) { $Configuration.Params = $args[2];$object | Add-Member -MemberType NoteProperty -Name "Params" -Value $args[2] }
                if ($args[3]) { $Configuration.Version = $args[3];$object | Add-Member -MemberType NoteProperty -Name "Version" -Value $args[3] }
                if ($args[4]) { $Configuration.Source = $args[4];$object | Add-Member -MemberType NoteProperty -Name "Source" -Value $args[4] }
                if ($args[5]) { $Configuration.chocoParams = $args[5];$object | Add-Member -MemberType NoteProperty -Name "chocoParams" -Value $args[5] }
                if ($args[6]) { $Configuration.AutoUpgrade = $args[6];$object | Add-Member -MemberType NoteProperty -Name "AutoUpgrade" -Value $args[6] }    
                $Configuration.ErrorAction = "SilentlyContinue"           
                
                if (-not(Test-TargetResource @Configuration )) {
                    $SetResult = Set-TargetResource @Configuration
                }
                $object | Add-Member -MemberType NoteProperty -Name "DesiredState" -Value $SetResult
                return $object
            }
        }
        catch {
            throw $_.Exception.Message
            break            
        }
    }
    
    process {
        
        Write-Verbose $ComputerName
        Write-Verbose $Name
        Write-Verbose $Version
        try {
            if (-not($ComputerName)) {
                $ComputerName = $env:COMPUTERNAME
            }
            $Session = New-PSSession $ComputerName -EnableNetworkAccess

            $InvokeParams = @{
                Session      = $Session
                ScriptBlock  = $ScriptBlockImport
            }
            $null = Invoke-Command @InvokeParams
            $InvokeParams = @{
                Session      = $Session
                ScriptBlock  = $ScriptBlockSet
                ArgumentList = $Name, $Ensure, $Params, $Version, $Source, $chocoParams, $AutoUpgrade
            }
            if ($Session -and $ComputerName -ne $env:COMPUTERNAME) {                
                if ($Credentials) {
                    $InvokeParams.AsUser = $Credentials
                }            
                else {
                    $InvokeParams.AsSystem = $true                
                }
                $return = Invoke-CommandAs @InvokeParams
            }
            else {
                $return = Invoke-Command @InvokeParams
            }
            $return = $return | Select-Object * -ExcludeProperty RunspaceId
            $return  | Add-Member -MemberType NoteProperty -Name ComputerName -Value $ComputerName
            return $return
        }
        catch {
            throw $_
        }       

    }
    
    end {
        $Session | Remove-PSSession -ErrorAction SilentlyContinue
    }
}