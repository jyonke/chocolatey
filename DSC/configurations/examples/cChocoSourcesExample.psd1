# Copyright (c) 2017 Chocolatey Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

@{
    "contoso"    = @{
        Name     = "contoso.com"
        Priority = 0
        Source   = "https://contoso.com/repository/nuget-hosted/"
        Ensure   = "Present"
        User     = 'svc_nuget'
        Password = '76492d1116743f0423413b16050a5345MgB8ADkAdwBKAHkASgA5AFAAOAB1AEIAZAB5AEkAeAAwAEQAegBaAFgASQAxAFEAPQA9AHwAOQA0ADkANwBlADUAOABkADIAZQBlAGMANgA4AGMAZQBjAGEAMwA3AGIANgA3ADAAMgA0ADAAMgAzADcAMQA1AA=='
        KeyFile  = 'C:\ProgramData\chocolatey\config\sources.key'
    }
    "chocolatey" = @{
        Name     = "chocolatey"
        Priority = 10
        Source   = 'https://chocolatey.org/api/v2/'
        Ensure   = 'Present'
        VPN      = $false
    }
}