function Get-R18Actress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartPage,
        [Parameter(Mandatory=$true)]
        [int]$EndPage,
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$ExportPath
    )

    # Removes PowerShell progress bar which speeds up Invoke-WebRequest calls
    $ProgressPreference = 'SilentlyContinue'

    for ($Counter = $StartPage; $Counter -le $EndPage; $Counter++) {
        $PageNumber = $Counter.ToString()
        $Page = Invoke-WebRequest -Uri "https://www.r18.com/videos/vod/movies/actress/letter=a/sort=popular/page=$PageNumber/"
        $Results = $Page.Images | Select-Object src, alt | Where-Object {
                            $_.src -like '*/actjpgs/*' -and`
                            $_.alt -notlike $null
                        }

        $Results | Export-Csv -Path $ExportPath -Force -Append -NoTypeInformation
        Write-Verbose "Page $Counter added to $ExportPath"
    }
}

$api_key = ""
$Web = Invoke-RestMethod "192.168.14.10:8096/emby/Persons/?api_key=$api_key"

$FileObject = @()
for ($x = 0; $x -lt $Web.Items.Length; $x++) {
    $FileObject += New-Object -TypeName psobject -Property @{
        Name = $Web.Items.Name[$x]
        EmbyID = $Web.Items.Id[$x]
    }
}

$Img = Import-Csv Z:\private\script\actressSAVED.csv

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

Invoke-RestMethod -Method Post -Uri "192.168.14.10:8096/emby/Items/$id/RemoteImages/Download?Type=Thumb&ImageUrl=$link&api_key=$api_key"