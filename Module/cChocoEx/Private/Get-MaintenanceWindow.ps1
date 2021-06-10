function Get-MaintenanceWindow {
    param (
        # UTC
        [Parameter()]
        [bool]
        $UTC,
        # StartTime
        [Parameter(Mandatory = $True)]
        [datetime]
        $StartTime,
        # EndTime
        [Parameter(Mandatory = $True)]
        [datetime]
        $EndTime,
        # Effective Date Time
        [Parameter(Mandatory = $False)]
        [datetime]
        $EffectiveDateTime
    )
    $Date = Get-Date
    Write-Verbose "Current Date: $Date"
    if ($UTC -eq $True) {
        $Date = $Date.ToUniversalTime()
        Write-Verbose "Converted Time to UTC"
        Write-Verbose "Current Date: $Date"
    }
    #Offset Times if TimeSpan crosses 00:00
    if ($StartTime.TimeOfDay -gt $EndTime.TimeOfDay) {
        $OffSet = 24 - $StartTime.TimeOfDay.TotalHours
        $AltDate = $Date.TimeOfDay.TotalHours + $OffSet
        if ($AltDate -gt 24) {
            $AltDate = $AltDate - 24
        }
        $AltStartTime = [int]0.0
        $AltEndTime = $EndTime.TimeOfDay.TotalHours + $OffSet
        $MaintenanceWindowActive = $AltDate -ge $AltStartTime -and $AltDate -le $AltEndTime
        Write-Verbose "Start Time is Greater Than EndTime"
        Write-Verbose "Offset: $OffSet"
        Write-Verbose "AltDateHours: $AltDate"
        Write-Verbose "AltStartTimeHours: $AltStartTime"
        Write-Verbose "AltEndTimHours: $AltEndTime"
    }
    if (($StartTime.TimeOfDay -lt $EndTime.TimeOfDay)) {
        $MaintenanceWindowActive = $Date.TimeOfDay.TotalHours -ge $StartTime.TimeOfDay.TotalHours -and $Date.TimeOfDay.TotalHours -le $EndTime.TimeOfDay.TotalHours
        Write-Verbose "Start Time is Less Than EndTime"
    }
    #Determine if maintenance window is active yet, default to false if not active
    if ($Date -lt $EffectiveDateTime) {
        $MaintenanceWindowEnabled = $False
        $MaintenanceWindowActive = $False
        Write-Verbose "MaintenanceWindowEnabled False - Date is less than Effective Date Time"
    }
    else {
        $MaintenanceWindowEnabled = $True
        Write-Verbose "MaintenanceWindowEnabled True - Date is greater than Effective Date Time"

    }
    Write-Verbose "DateTimeofDay: $($Date.TimeOfDay)"
    Write-Verbose "StartTimeTimeOfDay: $($StartTime.TimeOfDay)"
    Write-Verbose "EndTimeTimeOfDay: $($EndTime.TimeOfDay)"
    Write-Verbose "EffectiveDateTime: $EffectiveDateTime"
    Write-Verbose "MaintenanceWindowEnabled: $MaintenanceWindowEnabled"
    Write-Verbose "MaintenanceWindowActive: $MaintenanceWindowActive"

    return [PSCustomObject]@{
        MaintenanceWindowEnabled = $MaintenanceWindowEnabled
        MaintenanceWindowActive  = $MaintenanceWindowActive
    }
}