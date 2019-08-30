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

    Invoke-RestMethod -Method Post -Uri "$ServerUri/emby/Items/$ActorId/RemoteImages/Download?Type=Thumb&ImageUrl=$ThumbURL&api_key=$ApiKey" -Verbose
}

function Get-EmbyActors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUri,
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )

    $script:Web = Invoke-RestMethod -Method Get -Uri "$ServerUri/emby/Persons/?api_key=$ApiKey" -Verbose
}

Write-Output "Starting Set-ActorThumbs..."
# Check settings file for config
$EmbyServerUri = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^emby-api-key').Split('=')[1]
$NameOrder = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^name-order').Split('=')[1]
$R18File = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^r18-scraped-thumbs').Split('=')[1]

Get-EmbyActors -ServerUri $EmbyServerUri -ApiKey $EmbyApiKey
Write-Output "Writing Emby actor IDs to new object..."
$FileObject = @()
for ($x = 0; $x -lt $Web.Items.Length; $x++) {
    $FileObject += New-Object -TypeName psobject -Property @{
        Name = $Web.Items.Name[$x]
        EmbyID = $Web.Items.Id[$x]
    }
}

# Import scraped r18 actor thumbs
$Img = Import-Csv -Path $R18File -ErrorAction Inquire
Write-Output "R18 actor thumb file loaded..."
Write-Output "Cleaning actor names..."
# Clean up names scraped from R18 to match settings
$Names = ($Img.alt).replace('...','')
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

Write-Output "Writing thumbnail URLs to new object..."
$ThumbObject = @()
for ($x = 0; $x -lt $Img.Length; $x++) {
    $ThumbObject += New-Object -TypeName psobject -Property @{
        Name = $NewName[$x]
        ThumbURL = $Img.src[$x]
    }
}

Write-Output "Cleaning thumbnail object..."
# Remove possible duplicates
$CleanThumbObject = $ThumbObject | Select-Object Name, ThumbURL -Unique

Write-Output "Writing actors and thumbnails to final object..."
# Write final Actor object for POST into Emby
$ActorObject = @()
foreach ($FileObj in $FileObject) {
    foreach ($ThumbObj in $CleanThumbObject) {
        if ($ThumbObj.Name -like $FileObj.Name) {
            $ActorObject += New-Object -TypeName psobject -Property @{
                Name = $ThumbObj.Name
                EmbyID = $FileObj.EmbyID
                ThumbURL = $ThumbObj.ThumbURL
            }
        }
    }
}

$ActorObject | Out-File -FilePath $PSScriptRoot\TempActorObject.txt -Force| Invoke-Item
Write-Warning 'Please check the invoked text file for thumbnails to be written'
Write-Warning 'Do you want to write emby thumbnails for these actors?'
Write-Output 'Confirm changes?'
$Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'
Remove-Item -Path $PSScriptRoot\TempActorObject.txt -Force

if ($Input -like 'y' -or $Input -like 'yes') {
    Write-Output "Writing actor thumbs to Emby..."
    foreach ($Match in $ActorObject) {
        Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $Match.EmbyID -ThumbUrl $Match.ThumbURL -ApiKey $EmbyApiKey
    }
}

else {
    Write-Warning 'Cancelled by user input. Exiting...'
    pause
}