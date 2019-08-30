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