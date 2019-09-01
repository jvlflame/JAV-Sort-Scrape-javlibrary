function Get-R18ThumbUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartPage,
        [Parameter(Mandatory=$true)]
        [int]$EndPage,
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$ExportPath
    )

    for ($Counter = $StartPage; $Counter -le $EndPage; $Counter++) {
        $PageNumber = $Counter.ToString()
        $Page = Invoke-WebRequest -Uri "https://www.r18.com/videos/vod/movies/actress/letter=a/sort=popular/page=$PageNumber/"
        $Results = $Page.Images | Select-Object src, alt | Where-Object {
                            $_.src -like '*/actjpgs/*' -and`
                            $_.alt -notlike $null
                        }

        $Results | Export-Csv -Path $ExportPath -Force -Append -NoTypeInformation
        Write-Host "Page $Counter added to $ExportPath"
    }
}

function Set-NameOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$Path
    )

    # Create backup directory in scriptroot
    $BackupPath = Join-Path -Path $PSScriptRoot -ChildPath "db"
    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -ErrorAction SilentlyContinue
    }

    # Copy original scraped thumbs to backup directory
    Write-Host "Backing up original scraped csv file to $BackupPath"
    Copy-Item -Path $Path -Destination (Join-Path $BackupPath -ChildPath "r18thumb_original.csv")
    Write-Host "Writing to cleaned names to csv... please wait"
    $R18Thumbs = Import-Csv -Path $Path
    # Remove periods from R18 scrape
    $Names = ($R18Thumbs.alt).replace('...','')
    $NewName = @()
    if ($NameOrder -eq 'true') {
        foreach ($Name in $Names) {
            $Temp = $Name.split(' ')
            if ($Temp[1].length -ne 0) {
                $First,$Last = $Name.split(' ')
                $NewName += "$Last $First"
            }
            else {
                $NewName += $Name.TrimEnd()
            }
            Write-Host -NoNewline '.'
        }
    }

    if ($NameOrder -eq 'false') {
        foreach ($Name in $Names) {
            $NewName += $Name.TrimEnd()
        }
    }
    
    $R18Actors = @()
    $Temp = @()
    for ($x = 0; $x -lt $NewName.Length; $x++) {
        if ($NewName[$x] -in $Temp.Name) {
            # Do not add to R18Actors object
        }
        else {
            $R18Actors += New-Object -TypeName psobject -Property @{
                Name = $NewName[$x]
                ThumbUrl = $R18Thumbs.src[$x]
            }
        }
        $Temp += New-Object -TypeName psobject -Property @{
            Name = $NewName[$x]
        }
        Write-Host -NoNewline '.'
    }

    Write-Output $R18Actors
}

# Removes PowerShell progress bar which speeds up Invoke-WebRequest calls
$ProgressPreference = 'SilentlyContinue'

# Check settings file for config options
$SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath (Join-Path -Path '..' -ChildPath 'settings_sort_jav.ini'))
$NameOrder = ((Get-Content $SettingsPath) -match '^swap-name-order').Split('=')[1]
$StartPage = ((Get-Content $SettingsPath) -match '^r18-start-page').Split('=')[1]
$EndPage = ((Get-Content $SettingsPath) -match '^r18-end-page').Split('=')[1]
$CsvExportPath = ((Get-Content $SettingsPath) -match '^r18-export-csv-path').Split('=')[1]

# Write thumb links csv file
if (!(Test-Path -Path $CsvExportPath)) {
    Get-R18ThumbUrl -StartPage $StartPage -EndPage $EndPage -ExportPath $CsvExportPath
}

else {
    Write-Host "File specified in r18-export-csv-path already exists. Replace?"
    $Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'
    if ($Input -like 'y') {
        # Create backup directory in scriptroot
        $BackupPath = Join-Path -Path $PSScriptRoot -ChildPath "db"
        if (!(Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -ErrorAction SilentlyContinue
        }

        # Copy original scraped thumbs to backup directory
        Copy-Item -Path $CsvExportPath -Destination (Join-Path $BackupPath -ChildPath "r18thumb_original.csv")
        Get-R18ThumbUrl -StartPage $StartPage -EndPage $EndPage -ExportPath $CsvExportPath
    }

    else {
        Write-Host "Are you trying to rewrite the original scraped csv?"
        $Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'
        if ($Input -notlike 'y') {
            Write-Warning "Cancelled by user input. Exiting..."
            return
        }
        else {
            # Do nothing
        }
    }
}

# Write fixed names to original csv file while backing up original to 'db' directory
$ActorCsv = Set-NameOrder -Path $CsvExportPath

# First csv rewrite - names only
$ActorCsv | Select-Object Name, ThumbUrl | Export-Csv $CsvExportPath -Force -NoTypeInformation
Write-Host "R18 actor thumb urls written to $CsvExportPath"
pause