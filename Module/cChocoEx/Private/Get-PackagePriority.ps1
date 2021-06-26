function Get-PackagePriority {
    [CmdletBinding()]
    param (        
        [Parameter()]
        [array]
        $Configurations
    )

    #Evaluate Ring Status
    $Ring = Get-Ring
    [int]$SystemRingValue = Get-RingValue -Name $Ring
    
    #Filter Package Sets with the same name and select an apprpriate package based on SystemRingValue
    $Matches = $Configurations.Name | Group-Object | Where-Object {$_.Count -gt 1}
    $MultiPackageSets = $Matches | Where-Object { $Matches.Name -contains $_.Name }
    $MultiPackageSets | ForEach-Object {
        $PackageSet = $_
        $ConfigurationsFiltered = $Configurations | Where-Object {$_.Name -eq $PackageSet.Name} 
        $ConfigurationsFiltered | ForEach-Object { [int]$_.RingValue = (Get-RingValue -Name $_.Ring) }
        $EligibleRingValue = $ConfigurationsFiltered.RingValue | Sort-Object | Where-Object {$SystemRingValue -ge $_} | Select-Object -Last 1
        $RingPackage = $ConfigurationsFiltered | Where-Object {$EligibleRingValue -eq $_.RingValue}
        $Configurations = $Configurations | Where-Object {$_.Name -ne $RingPackage.Name}
        $Configurations += $RingPackage
    }
    #Remove Temp RingValue Property
    $Configurations | ForEach-Object {$_.Remove("RingValue")} 

    return $Configurations
}