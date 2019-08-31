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

# Remove progress bar to speed up REST requests
$ProgressPreference = 'SilentlyContinue'

Write-Output "Starting Set-ActorThumbs..."
# Check settings file for config
$EmbyServerUri = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^emby-server-uri').Split('=')[1]
$EmbyApiKey = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^emby-api-key').Split('=')[1]
$NameOrder = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^name-order').Split('=')[1]
$R18File = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^r18-scraped-thumbs').Split('=')[1]
$ActorDbPath = Join-Path -Path $PSScriptRoot -ChildPath "db"

trap {continue}
$ActorDbWriteObject = Import-Csv (Join-Path -Path $ActorDbPath "ActorDbwWitten.csv") -ErrorAction SilentlyContinue
$ActorDbObject = Import-Csv (Join-Path -Path $ActorDbPath "ActorDb.csv") -ErrorAction SilentlyContinue
$R18ThumbDbObject = Import-Csv (Join-Path  -Path $ActorDbPath -ChildPath "R18ThumbDb.csv") -ErrorAction SilentlyContinue

# Create db directory in script path
New-Item -ItemType Directory -Path (Join-Path -Path $PSScriptRoot -ChildPath "db") -ErrorAction SilentlyContinue

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
$R18Thumbs = Import-Csv -Path $R18File -ErrorAction Inquire
Write-Output "R18 actor thumb file loaded..."
Write-Output "Cleaning actor names..."
# Clean up names scraped from R18 to match settings
$Names = ($R18Thumbs.alt).replace('...','')
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

if ($R18ThumbDbObject) {
    Write-Warning "ThumbDb.csv found!"
    $CleanThumbObject = $R18ThumbDbObject
}
else {
    Write-Output "Writing thumbnail URLs to new object..."
    $ThumbObject = @()
    for ($x = 0; $x -lt $R18Thumbs.Length; $x++) {
        $ThumbObject += New-Object -TypeName psobject -Property @{
            Name = $NewName[$x]
            ThumbURL = $R18Thumbs.src[$x]
        }
    }

    Write-Output "Cleaning thumbnail object..."
    # Remove possible duplicates
    $CleanThumbObject = $ThumbObject | Select-Object Name, ThumbURL -Unique
    # Export object to Csv so you don't need to parse this again
    $CleanThumbObject | Export-Csv -Path (Join-Path -Path $ActorDbPath -ChildPath "R18ThumbDb.csv")
}

Write-Output "Writing actors and thumbnails to final object..."
# Write final Actor object for POST into Emby
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

Write-Output "Adding new actors to ActorDb.csv"
if ($ActorDbObject) {
    Write-Warning "ActorDb.csv found!"
    Write-Output "Comparing... please wait"
    foreach ($Object in $ActorObject) {
        if ($Object.EmbyID -match $ActorDbObject.EmbyID) {
            # Do not write
        }
        else {
            $Object | Select-Object Name, EmbyID, ThumbURL, PrimaryURL | Export-Csv -Path (Join-Path -Path $ActorDbPath -ChildPath "ActorDb.csv") -Append -NoTypeInformation -NoClobber
        }
    }
}
else {
    $ActorObject | Select-Object Name, EmbyID, ThumbURL, PrimaryURL | Export-Csv -Path (Join-Path -Path $ActorDbPath -ChildPath "ActorDb.csv") -NoTypeInformation -NoClobber
}

Write-Warning 'Do you want to write emby thumbnails for these actors?'
Write-Output 'Confirm changes?'
$Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'

if ($Input -like 'y' -or $Input -like 'yes') {
    $ActorDbObject = Import-Csv (Join-Path -Path $ActorDbPath "ActorDb.csv") -ErrorAction Ignore
    if ($ActorDbWriteObject) {
        foreach ($Object in $ActorDbObject) {
            if ($Object.EmbyID -match $ActorDbWriteObject.EmbyID) {
                # Do nothing
            }
            else {
                if ($null -ne $Object.ThumbURL) {
                    Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $Object.EmbyID -ThumbUrl $Object.ThumbURL -PrimaryUrl $Object.PrimaryURL -ApiKey $EmbyApiKey
                    $Object | Select-Object Name, EmbyID, ThumbURL, PrimaryURL | Export-Csv -Path (Join-Path -Path $ActorDbPath -ChildPath "ActorDbWritten.csv")
                }
            }
        }
    }
    else {
        foreach ($Object in $ActorDbObject) {
            if ($null -ne $Object.ThumbURL) {
                Set-ActorThumbs -ServerUri $EmbyServerUri -ActorId $Object.EmbyID -ThumbUrl $Object.ThumbURL -PrimaryUrl $Object.PrimaryURL -ApiKey $EmbyApiKey
                $Object | Select-Object Name, EmbyID, ThumbURL, PrimaryURL | Export-Csv -Path (Join-Path -Path $ActorDbPath -ChildPath "ActorDbWritten.csv")
            }
        }
    }
}

else {
    Write-Warning 'Cancelled by user input. Exiting...'
    pause
}