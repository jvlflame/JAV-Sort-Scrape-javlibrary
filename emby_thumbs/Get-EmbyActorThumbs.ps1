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

$SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath (Join-Path -Path '..' -ChildPath 'settings_sort_jav.ini'))
# Check settings file for config
$EmbyServerUri = ((Get-Content $SettingsPath) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $SettingsPath) -match '^emby-api-key').Split('=')[1]
$R18File = ((Get-Content $SettingsPath) -match '^r18-export-csv-path').Split('=')[1]



# Create db directory in script path
#New-Item -ItemType Directory -Path (Join-Path -Path $PSScriptRoot -ChildPath "db") -ErrorAction SilentlyContinue

# Write Emby actors and id to object
$EmbyActors = Get-EmbyActors -ServerUri $EmbyServerUri -ApiKey $EmbyApiKey
$EmbyObject = @()
for ($x = 0; $x -lt $EmbyActors.Items.Length; $x++) {
    $EmbyObject += New-Object -TypeName psobject -Property @{
        Name = $EmbyActors.Items.Name[$x]
        EmbyId = $EmbyActors.Items.Id[$x]
    }
}

# Write R18 actors and thumbs to object
$R18Csv = Import-Csv -Path $R18File
$R18Object = @()
$Temp = @()
foreach ($Object in $R18Csv) {
    # Write names to temp array
    $Temp += $Object.alt
    # If name already exists in array, don't write another. Testing to sort as usually the first entry is the most popular actress
    if ($Object.alt -notmatch $Temp) {
        $R18Object += New-Object -TypeName psobject -Property @{
            Name = $Object.alt
            ThumbUrl = $Object.src
    }
}



#$R18Object = Import-Csv -Path $R18File | Select-Object -ExpandProperty Name -Unique ThumbURL
<#
$R18ScrapeObject = @()
for ($x = 0; $x -lt $R18Object.Length; $x++) {
    if ($R18Object.Name[$x] -match $EmbyObject.Name[$x]) {
        $R18ScrapeObject += New-Object -TypeName psoboject -Property @{
            Name = $R18ScrapeObject[$x]
            EmbyId = $Emby
        }
    }
}


$ActorObject = @()


$ActorObject = @()
foreach ($FileObj in $FileObject) {
    foreach ($ThumbObj in $CleanThumbObject) {
        if ($ThumbObj.Name -like $FileObj.Name) {
            # Write matches
            $ActorObject += New-Object -TypeName psobject -Property @{
                Name = $ThumbObj.Name
                EmbyID = $FileObj.EmbyID
                ThumbURL = $ThumbObj.ThumbURL
                PrimaryURL = $ThumbObj.ThumbURL
            }
        }
    }
    # Write non-matches
    $ActorObject += New-Object -TypeName psobject -Property @{
        Name = $FileObj.Name
        EmbyID = $FileObj.EmbyID
    }
}


#$ActorObject = New-ActorObject -Name  #>