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
}

Get-EmbyActors -ServerUri $ServerUri -ApiKey $ApiKey

$FileObject = @()
for ($x = 0; $x -lt $Web.Items.Length; $x++) {
    $FileObject += New-Object -TypeName psobject -Property @{
        Name = $Web.Items.Name[$x]
        EmbyID = $Web.Items.Id[$x]
    }
}

# Import scraped r18 actress thumbs
$Img = Import-Csv -Path $R18Scraped

$Names = ($img.alt).replace('...','')
$NewName = @()
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

$ThumbObject = @()
for ($x = 0; $x -lt $Img.Items.Length; $x++) {
    $ThumbObject += New-Object -TypeName psobject -Property @{
        Name = $NewName[$x]
        ThumbURL = $Img.src[$x]
    }
}

$CleanThumbObject = $ThumbObject | Select-Object Name, ThumbURL -Unique

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

foreach ($Thumb in $ActressObject) {
    Set-ActorThumbs -ServerUri 192.168.14.10:8096 -ActorId $ThumbObject.EmbyID -ThumbUrl $ThumbObject.ThumbURL -ApiKey 27d3c17ba69540828f141df8d2c743fb
}