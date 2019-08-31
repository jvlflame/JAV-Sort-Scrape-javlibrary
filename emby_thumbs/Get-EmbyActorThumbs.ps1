function Get-EmbyActors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUri,
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )

    Invoke-RestMethod -Method Get -Uri "$ServerUri/emby/Persons/?api_key=$ApiKey" -Verbose
}

function New-ActorObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath
    )

    $Csv = Import-Csv -Path $CsvPath

    $ActorObject = @()
    foreach ($Object in $Csv) {
        $ActorObject += New-Object -TypeName psobject -Property @{
            Name = $Object.$alt
            EmbyId = $Object.EmbyId
            ThumbUrl = $Object.src
            PrimaryUrl = $Object.PrimaryUrl
        }
    }
    Write-Output $ActorObject
}

# Remove progress bar to speed up REST requests
$ProgressPreference = 'SilentlyContinue'

# Check settings file for config
$SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath (Join-Path -Path '..' -ChildPath 'settings_sort_jav.ini'))
$EmbyServerUri = ((Get-Content $SettingsPath) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $SettingsPath) -match '^emby-api-key').Split('=')[1]
$R18ImportPath = ((Get-Content $SettingsPath) -match '^r18-export-csv-path').Split('=')[1]
$ActorExportPath = ((Get-Content $SettingsPath) -match '^actor-csv-export-path').Split('=')[1]

# Write Emby actors and id to object
$EmbyActors = Get-EmbyActors -ServerUri $EmbyServerUri -ApiKey $EmbyApiKey
$EmbyActorObject = @()
for ($x = 0; $x -lt $EmbyActors.Items.Length; $x++) {
    $EmbyActorObject += New-Object -TypeName psobject -Property @{
        Name = $EmbyActors.Items.Name[$x]
        EmbyId = $EmbyActors.Items.Id[$x]
    }
}

# Import R18 actors and thumburls to object
$R18ActorObject = Import-Csv -Path $R18ImportPath

# Compare both Emby and R18 actors for matching actors, and combine to a single object
$ActorNames = @()
$ActorObject = @()
for ($x = 0; $x -lt $EmbyActorObject.Length; $x++) {
    $ActorNames += ($EmbyActorObject[$x].Name).ToLower()
    if ($ActorNames[$x] -notin $R18ActorObject.Name) {
        #Write-Host "Missing"
        $ActorObject += New-Object -TypeName psobject -Property @{
            Name = $EmbyActorObject[$x].Name
            EmbyId = $EmbyActorObject[$x].EmbyId
            ThumbUrl = ''
            PrimaryUrl = ''
        }
    }
    else {
        $Index = [array]::indexof(($R18ActorObject.Name).ToLower(), $ActorNames[$x])
        #Write-Host ""$EmbyActorObject[$x].Name" is index $Index"
        $ActorObject += New-Object -TypeName psobject -Property @{
            Name = $EmbyActorObject[$x].Name
            EmbyId = $EmbyActorObject[$x].EmbyId
            ThumbUrl = $R18ActorObject[$Index].ThumbUrl
            PrimaryUrl = $R18ActorObject[$Index].ThumbUrl
        }
    }
}

$ActorObject | Export-Csv -Path $ActorExportPath