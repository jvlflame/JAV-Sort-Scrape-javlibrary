function Add-ActorThumbs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerUri,
        [Parameter(Mandatory = $true)]
        [string]$ActorId,
        [Parameter(Mandatory = $true)]
        [string]$ImageUrl,
        [Parameter(Mandatory = $true)]
        [string]$ImageType,
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    Invoke-RestMethod -Method Post -Uri "$ServerUri/emby/Items/$ActorId/RemoteImages/Download?Type=$ImageType&ImageUrl=$ImageUrl&api_key=$ApiKey" -ErrorAction Continue
}

function Remove-ActorThumbs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerUri,
        [Parameter(Mandatory = $true)]
        [string]$ActorId,
        [Parameter(Mandatory = $true)]
        [string]$ImageType,
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    Invoke-RestMethod -Method Delete -Uri "$ServerUri/emby/Items/$ActorId/Images/Download?Type=$ImageType&api_key=$ApiKey" -ErrorAction Continue
}

function Set-CsvDb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$Path,
        [Parameter(Mandatory = $true)]
        [int]$Index,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$EmbyId,
        [Parameter(Mandatory = $false)]
        [string]$ThumbUrl = '',
        [Parameter(Mandatory = $false)]
        [string]$PrimaryUrl = ''
    )

    # Get contents of csv file in $Path
    $DbContent = Get-Content $Path

    # Rewrite new csv string to input
    $UpdatedDbString = "`"$Name`",`"$EmbyId`",`"$ThumbUrl`",`"$PrimaryUrl`""

    # Update the line with updated string and set the file
    $DbContent[$Index + 1] = $UpdatedDbString
    $DbContent | Set-Content $Path
}

# Remove progress bar to speed up REST requests
$ProgressPreference = 'SilentlyContinue'

# Check settings file for config
$SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath (Join-Path -Path '..' -ChildPath 'settings_sort_jav.ini'))
$EmbyServerUri = ((Get-Content $SettingsPath) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $SettingsPath) -match '^emby-api-key').Split('=')[1]
$ActorImportPath = ((Get-Content $SettingsPath) -match '^actor-csv-export-path').Split('=')[1]
$ActorDbPath = ((Get-Content $SettingsPath) -match '^actor-csv-database-path').Split('=')[1]

$ActorObject = Import-Csv -Path $ActorImportPath -ErrorAction Stop

# Check if db file specified in 'actor-csv-database-path' exists, create if not exists
if (!(Test-Path $ActorDbPath)) {
    Write-Host "Database file not found. Creating..."
    New-Item -ItemType File -Path $ActorDbPath
}

else {
    $ActorDbObject = Import-Csv -Path $ActorDbPath -ErrorAction Stop
}

Write-Host "Querying for changes in $ActorImportPath..."
$ActorNames = @()
for ($x = 0; $x -lt $ActorObject.Length; $x++) {
    # Write names to string object to query for index
    $ActorNames += ($ActorObject[$x].Name).ToLower()
    if ($ActorObject[$x].ThumbUrl -notlike '' -or $ActorObject[$x].PrimaryUrl -notlike '') {
        if ($ActorObject[$x].ThumbUrl -notlike '' -and $ActorObject[$x].PrimaryUrl -notlike '') {
            if ($ActorObject[$x].Name -notin $ActorDbObject.Name -and $ActorObject[$x].EmbyId -notin $ActorDbObject.EmbyId) {
                Write-Host "ADD thumb to "$ActorObject[$x].Name""
                # POST thumb to Emby
                Add-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageUrl $ActorObject[$x].ThumbURL -ImageType Thumb -ApiKey $EmbyApiKey

                Write-Host "ADD primary to "$ActorObject[$x].Name""
                # POST primary to Emby
                Add-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageUrl $ActorObject[$x].PrimaryUrl -ImageType Primary -ApiKey $EmbyApiKey

                try {
                    # Write to db file if posted
                    $ActorObject[$x] | Export-Csv -Path $ActorDbPath -Append -NoClobber -ErrorAction Stop
                }
                catch { Write-Error "Error writing to csv Database file. Make sure your database csv file is closed and restart the script." }
            }
            else {
                # Query for index of existing actor in db
                $Index = [array]::indexof(($ActorDbObject.Name).ToLower(), $ActorNames[$x])
                if ($ActorObject[$x].Name -eq $ActorDbObject[$Index].Name -and $ActorObject[$x].EmbyId -eq $ActorDbObject[$Index].EmbyId) {
                    if ($ActorObject[$x].ThumbUrl -notlike $ActorDbObject[$Index].ThumbUrl) {
                        Write-Host "ADD thumb image for "$ActorObject[$x].Name""
                        Add-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageUrl $ActorObject[$x].ThumbURL -ImageType Thumb -ApiKey $EmbyApiKey
                        Set-CsvDb -Path $ActorDbPath -Index $Index -Name $ActorObject[$x].Name -EmbyId $ActorObject[$x].EmbyId -ThumbUrl $ActorObject[$x].ThumbUrl -PrimaryUrl $ActorObject[$x].PrimaryUrl -ErrorAction Stop
                    }
                    if ($ActorObject[$x].PrimaryUrl -notlike $ActorDbObject[$Index].PrimaryUrl) {
                        Write-Host "ADD primary image for "$ActorObject[$x].Name""
                        Add-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageUrl $ActorObject[$x].PrimaryUrl -ImageType Primary -ApiKey $EmbyApiKey
                        Set-CsvDb -Path $ActorDbPath -Index $Index -Name $ActorObject[$x].Name -EmbyId $ActorObject[$x].EmbyId -ThumbUrl $ActorObject[$x].ThumbUrl -PrimaryUrl $ActorObject[$x].PrimaryUrl -ErrorAction Stop
                    }
                }
            }
        }
        else {
            if ('' -eq $ActorObject[$x].ThumbUrl) {
                Write-Host "REMOVE thumb image for "$ActorObject[$x].Name""
                Remove-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageType Thumb -ApiKey $EmbyApiKey
                Set-CsvDb -Path $ActorDbPath -Index $Index -Name $ActorObject[$x].Name -EmbyId $ActorObject[$x].EmbyId -ThumbUrl $ActorObject[$x].ThumbUrl -PrimaryUrl $ActorObject[$x].PrimaryUrl -ErrorAction Stop
            }

            if ('' -eq $ActorObject[$x].PrimaryUrl) {
                Write-Host "REMOVE primary image for "$ActorObject[$x].Name""
                Remove-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageType Primary -ApiKey $EmbyApiKey
                Set-CsvDb -Path $ActorDbPath -Index $Index -Name $ActorObject[$x].Name -EmbyId $ActorObject[$x].EmbyId -ThumbUrl $ActorObject[$x].ThumbUrl -PrimaryUrl $ActorObject[$x].PrimaryUrl -ErrorAction Stop
            }
        }
    }
    else {
        if (($x % 20) -eq 0) { Write-Host '.' -NoNewline }
    }
}
pause