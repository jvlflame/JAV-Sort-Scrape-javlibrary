function Set-ActorThumbs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUri,
        [Parameter(Mandatory=$true)]
        [int]$ActorId,
        [Parameter(Mandatory=$true)]
        [string]$ThumbUrl,
        [Parameter(Mandatory=$true)]
        [string]$PrimaryUrl,
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )
    # Set actor thumbnail
    Invoke-RestMethod -Method Post -Uri "$ServerUri/emby/Items/$ActorId/RemoteImages/Download?Type=Thumb&ImageUrl=$ThumbURL&api_key=$ApiKey" -Verbose
    # Set actor primary image
    Invoke-RestMethod -Method Post -Uri "$ServerUri/emby/Items/$ActorId/RemoteImages/Download?Type=Primary&ImageUrl=$PrimaryURL&api_key=$ApiKey" -Verbose
}

# Remove progress bar to speed up REST requests
$ProgressPreference = 'SilentlyContinue'

$SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath (Join-Path -Path '..' -ChildPath 'settings_sort_jav.ini'))
# Check settings file for config
$EmbyServerUri = ((Get-Content $SettingsPath) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $SettingsPath) -match '^emby-api-key').Split('=')[1]

Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $Object.EmbyID -ThumbUrl $Object.ThumbURL -PrimaryUrl $Object.PrimaryURL -ApiKey $EmbyApiKey
