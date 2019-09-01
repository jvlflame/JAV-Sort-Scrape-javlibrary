function Get-EmbyActors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUri,
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )

    Invoke-RestMethod -Method Get -Uri "$ServerUri/emby/Persons/?api_key=$ApiKey"
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
Write-Host "Getting actors from Emby..."
$EmbyActors = Get-EmbyActors -ServerUri $EmbyServerUri -ApiKey $EmbyApiKey
$EmbyActorObject = @()
for ($x = 0; $x -lt $EmbyActors.Items.Length; $x++) {
    $EmbyActorObject += New-Object -TypeName psobject -Property @{
        Name = $EmbyActors.Items.Name[$x]
        EmbyId = $EmbyActors.Items.Id[$x]
    }
    Write-Host -NoNewline '.'
}

# Import R18 actors and thumburls to object
Write-Host "Importing R18 actors with thumb urls..."
$R18ActorObject = Import-Csv -Path $R18ImportPath

Write-Host "Comparing Emby actor list with R18, please wait..."
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
    Write-Host -NoNewline '.'
}

if (Test-Path $ActorExportPath) {
    Write-Warning "File specified in actor-csv-export-path already exists. Overwrite with a new copy? "
    Write-Host "If you select N, your existing file will be updated with any new Emby entries."
    $Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'
}
else {
    $Input = 'y'
}

if ($Input -like 'y') {
    $ActorObject | Select-Object Name, EmbyId, ThumbUrl, PrimaryUrl | Export-Csv -Path $ActorExportPath -Force -NoTypeInformation
}

else {
    $ExistingActors = Import-Csv -Path $ActorExportPath
    $Count = 1
    foreach ($Actor in $ActorObject) {
        # If EmbyId already exists in the csv
        if ($Actor.EmbyId -in $ExistingActors.EmbyId) {
            # Do nothing
        }
        # If new actor (EmbyId) found, append to existing csv
        else {
            $Actor | Select-Object Name, EmbyId, ThumbUrl, PrimaryUrl | Export-Csv -Path $ActorExportPath -Append -NoClobber -NoTypeInformation
            Write-Host "($Count) Appending $Actor"
        }
        $Count++
    }
}

Write-Host "Combined actor thumb file written to $ActorExportPath"