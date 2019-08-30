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
        [string]$ApiKey
    )

    Invoke-RestMethod -Method Post -Uri "$ServerUri/emby/Items/$ActorId/RemoteImages/Download?Type=Thumb&ImageUrl=$ThumbURL&api_key=$ApiKey"
}

function Get-EmbyActors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUri,
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )

    $Web = Invoke-RestMethod -Method Get -Uri "$ServerUri/emby/Persons/?api_key=$ApiKey"
    $FileObject = @()
    for ($x = 0; $x -lt $Web.Items.Length; $x++) {
        $FileObject += New-Object -TypeName psobject -Property @{
            Name = $Web.Items.Name[$x]
            EmbyID = $Web.Items.Id[$x]
        }
    }
}

# Check settings file for config
$EmbyServerUri = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^emby-api-key').Split('=')[1]
$NameOrder = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^name-order').Split('=')[1]
$R18File = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^r18-scraped-thumbs').Split('=')[1]

Get-EmbyActors -ServerUri $EmbyServerUri -ApiKey $EmbyApiKey

# Import scraped r18 actress thumbs
$Img = Import-Csv -Path $R18File

# Clean up names scraped from R18 to match settings
$Names = ($img.alt).replace('...','')
$NewName = @()
if ($NameOrder -like 'last') {
    foreach ($Name in $Names) {
        $Temp = $Name.split(' ')
        if ($Temp[1].length -ne 0) {
            $First,$Last = $Name.split(' ')
            $NewName += "$Last $First"
        }
        else {
            $NewName += $Name
        }
    }
}

else {
    foreach ($Name in $Names) {
        $NewName += $Name
    }
}

$ThumbObject = @()
for ($x = 0; $x -lt $Img.Items.Length; $x++) {
    $ThumbObject += New-Object -TypeName psobject -Property @{
        Name = $NewName[$x]
        ThumbURL = $Img.src[$x]
    }
}

# Remove possible duplicates
$CleanThumbObject = $ThumbObject | Select-Object Name, ThumbURL -Unique

# Write final Actress object for POST into Emby
$ActressObject = @()
foreach ($FileObj in $FileObject) {
    foreach ($ThumbObj in $CleanThumbObject) {
        if ($ThumbObj.Name -like $FileObj.Name) {
            $ActressObject += New-Object -TypeName psobject -Property @{
                Name = $ThumbObj.Name
                EmbyID = $FileObj.EmbyID
                ThumbURL = $ThumbObj.ThumbURL
            }
        }
    }
}

<#
foreach ($Thumb in $ActressObject) {
    Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $ThumbObject.EmbyID -ThumbUrl $ThumbObject.ThumbURL -ApiKey $EmbyApiKey
}
#>