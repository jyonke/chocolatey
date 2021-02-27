@{
    "lvl12.com"  = @{
        Name     = "lvl12.com"
        Priority = 0
        Source   = "https://nuget.lvl12.com/repository/nuget-hosted/"
        Ensure   = "Present"
        User     = 'public'
        Password = '76492d1116743f0423413b16050a5345MgB8ADkAdwBKAHkASgA5AFAAOAB1AEIAZAB5AEkAeAAwAEQAegBaAFgASQAxAFEAPQA9AHwAOQA0ADkANwBlADUAOABkADIAZQBlAGMANgA4AGMAZQBjAGEAMwA3AGIANgA3ADAAMgA0ADAAMgAzADcAMQA1AA=='
        KeyFile  = 'C:\ProgramData\chocolatey\config\lvl12.com.key'
    }
    "chocolatey" = @{
        Name     = "chocolatey"
        Priority = 10
        Source   = 'https://chocolatey.org/api/v2/'
        Ensure   = 'Present'
    }
}