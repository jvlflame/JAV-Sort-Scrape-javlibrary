function Get-R18ThumbLinks {
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

# Check settings file for config
$StartPage = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^r18-start-page').Split('=')[1]
$EndPage = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^r18-end-page').Split('=')[1]
$CsvExportPath = ((Get-Content $PSScriptRoot\settings_sort_jav.ini) -match '^r18-export-csv-path').Split('=')[1]

# Write thumb links csv file
Get-R18ThumbLinks -StartPage $StartPage -EndPage $EndPage -ExportPath $CsvExportPath