function Add-ActorThumbs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUri,
        [Parameter(Mandatory=$true)]
        [int]$ActorId,
        [Parameter(Mandatory=$true)]
        [string]$ImageUrl,
        [Parameter(Mandatory=$true)]
        [string]$ImageType,
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )

    # Set actor thumbnail
    Invoke-RestMethod -Method Post -Uri "$ServerUri/emby/Items/$ActorId/RemoteImages/Download?Type=$ImageType&ImageUrl=$ImageUrl&api_key=$ApiKey" -Verbose
}

function Remove-ActorThumbs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUri,
        [Parameter(Mandatory=$true)]
        [int]$ActorId,
        [Parameter(Mandatory=$true)]
        [string]$ImageType,
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )

    Invoke-RestMethod -Method Delete -Uri "$ServerUri/emby/Items/$ActorId/Images/Download?Type=$ImageType&api_key=$ApiKey" -Verbose
}

# Remove progress bar to speed up REST requests
$ProgressPreference = 'SilentlyContinue'

# Check settings file for config
$SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath (Join-Path -Path '..' -ChildPath 'settings_sort_jav.ini'))
$EmbyServerUri = ((Get-Content $SettingsPath) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $SettingsPath) -match '^emby-api-key').Split('=')[1]
$ActorImportPath = ((Get-Content $SettingsPath) -match '^actor-csv-export-path').Split('=')[1]
$ActorDbPath = ((Get-Content $SettingsPath) -match '^actor-csv-database-path').Split('=')[1]

$ActorObject = Import-Csv -Path $ActorImportPath

# Check if db file specified in 'actor-csv-database-path' exists, create if not exists
if (!(Test-Path $ActorDbPath)) {
    Write-Host "Database file not found. Creating..."
    New-Item -ItemType File -Path $ActorDbPath
}

else {
    $ActorDbObject = Import-Csv -Path $ActorDbPath

    for ($x = 0; $x -lt $ActorObject.Length; $x++) {
        #$Index = [array]::indexof(($ActorDbObject.Name).ToLower(), $ActorNames[$x])
        if ($ActorObject[$x].Name -notin $ActorDbObject.Name -and $ActorObject[$x].EmbyId -notin $ActorDbObject.EmbyId) {
            Write-Host "Adding images to $ActorObject[$x]"
            # POST thumb to Emby
            Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject.EmbyID -ImageUrl $ActorObject.ThumbURL -ImageType Thumb -ApiKey $EmbyApiKey

            # POST primary to Emby
            Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject.EmbyID -ImageUrl $ActorObject.PrimaryUrl -ImageType Thumb -ApiKey $EmbyApiKey

            # Write to db file if posted
            $ActorObject[$x] | Export-Csv -Path $ActorDbPath -Append -NoClobber
        }
        
        else {
            $Index = [array]::indexof(($ActorDbObject.Name).ToLower(), $ActorNames[$x])
            Write-Host ""$EmbyActorObject[$x].Name" is index $Index"
            if ($ActorObject[$x].Name -eq $ActorDbObject[$Index].Name -and $ActorObject[$x].EmbyId -eq $ActorDbObject[$Index].EmbyId) {
                Write-Host "Match"
                if ($ActorObject[$x].ThumbUrl -notlike $ActorDbObject[$Index].ThumbUrl) {
                    if ($null -eq $ActorObject[$x].ThumbUrl) {
                        Write-Host "Removing thumb for $ActorObject[$x]"
                        Remove-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageType Thumb -ApiKey $EmbyApiKey
                        $ActorObject[$x] | Export-Csv -Path $ActorDbPath -Append -NoClobber
                    }

                    else {
                        Write-Host "Adding thumb for $ActorObject[$x]"
                        Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyID -ImageUrl $ActorObject[$x].ThumbURL -ImageType Thumb -ApiKey $EmbyApiKey
                        $ActorObject[$x] | Export-Csv -Path $ActorDbPath -Append -NoClobber
                    }
                }

                if ($ActorObject[$x].PrimaryUrl -notlike $ActorDbObject[$Index].PrimaryUrl) {
                    if ($null -eq $ActorObject[$x].PrimaryUrl) {
                        Write-Host "Removing primary for $ActorObject[$x]"
                        Remove-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageType Primary -ApiKey $EmbyApiKey
                        $ActorObject[$x] | Export-Csv -Path $ActorDbPath -Append -NoClobber
                    }

                    else {
                        Write-Host "Adding primary for $ActorObject[$x]"
                        Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ActorObject[$x].EmbyId -ImageUrl $ActorObject[$x].PrimaryUrl -ImageType Primary -ApiKey $EmbyApiKey
                        $ActorObject[$x] | Export-Csv -Path $ActorDbPath -Append -NoClobber
                    }
                }
            }
            else {
                $ActorObject[$x] | Export-Csv -Path $ActorDbPath -Append -NoClobber
            }
        }
    }
}
