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
    "webRequestTimeoutSeconds" = @{
        ConfigName = "webRequestTimeoutSeconds"
        Ensure     = 'Present'
        Value      = 30
    }

    "proxy"                    = @{
        ConfigName = "proxy"
        Ensure     = 'Absent'
    }

    "MaintenanceWindow" = @{
        Name              = 'MaintenanceWindow'
        EffectiveDateTime = "04-05-2021 21:00"
        Start             = '23:00'
        End               = '05:30'
        UTC               = $false
    }
}