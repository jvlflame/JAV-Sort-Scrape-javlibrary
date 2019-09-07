# Write nfo metadata file if html .txt from sort_jav.py exists
function Set-JAVNfo {
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.IO.FileInfo]$FilePath = ((Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'settings_sort_jav.ini')) -match '^path').Split('=')[1],
        [Parameter()]
        [Switch]$Prompt
    )

    function Show-FileChanges {
        # Display file changes to host
        $Table = @{Expression = { $_.Index }; Label = "#"; Width = 4 },
        @{Expression = { $_.Name }; Label = "Name"; Width = 25 },
        @{Expression = { $_.Path }; Label = "Directory" }
        $FileObject | Sort-Object Index | Format-Table -Property $Table | Out-Host
    }

    # Remove progress bar to speed up REST requests
    $ProgressPreference = 'SilentlyContinue'

    # Options from settings_sort_jav.ini
    $SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'settings_sort_jav.ini')
    $KeepMetadataTxt = ((Get-Content $SettingsPath) -match '^keep-metadata-txt').Split('=')[1]
    $AddGenres = ((Get-Content $SettingsPath) -match '^include-genre-metadata').Split('=')[1]
    $AddTags = ((Get-Content $SettingsPath) -match '^include-tag-metadata').Split('=')[1]
    $AddTitle = ((Get-Content $SettingsPath) -match '^include-video-title').Split('=')[1]
    $PartDelimiter = ((Get-Content $SettingsPath) -match '^delimiter-between-multiple-videos').Split('=')[1]
    $NameSetting = ((Get-Content $SettingsPath) -match '^actress-before-video-number').Split('=')[1]
    $R18TitleCheck = ((Get-Content $SettingsPath) -match '^prefer-r18-title').Split('=')[1]
    $R18MetadataCheck = ((Get-Content $SettingsPath) -match '^scrape-r18-other-metadata').Split('=')[1]
    $RenameCheck = ((Get-Content $SettingsPath) -match '^do-not-rename-file').Split('=')[1]

    Write-Host "Metadata to be written:"
    # Write txt metadata file paths to $HtmlMetadata
    if ($RenameCheck -like 'true') {
        # Match all .txt files if you are not renaming files
        $HtmlMetadata = Get-ChildItem -LiteralPath $FilePath -Recurse | Where-Object { $_.Name -match '(.*).txt' }
    }
    else {
        $HtmlMetadata = Get-ChildItem -LiteralPath $FilePath -Recurse | Where-Object { $_.Name -match '[a-zA-Z]{1,8}-[0-9]{1,8}(.*.txt)' -or $_.Name -match 't28(.*).txt' -or $_.Name -match 'r18(.*).txt' } | Select-Object Name, BaseName, FullName, Directory
    }
    if ($null -eq $HtmlMetadata) {
        Write-Warning 'No metadata files found! Exiting...'
        pause
    }

    else {
        # Create table to show files being written
        $Index = 1
        $FileObject = @()
        foreach ($File in $HtmlMetadata) {
            $FileObject += New-Object -TypeName psobject -Property @{
                Index = $Index
                Name  = $File.BaseName
                Path  = $File.Directory
            }
            $Index++
        }
        # Default prompt yes
        $Input = 'y'
        if ($Prompt) {
            Show-FileChanges
            Write-Host 'Do you want to write nfo metadata for these files?'
            Write-Host 'Confirm changes?'
            $Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'
        }
        if ($Input -like 'y' -or $Input -like 'yes') {
            Write-Host "Writing metadata .nfo files in path: $FilePath ..."
            # Write each nfo file
            $Count = 1
            $Total = $HtmlMetadata.Count
            foreach ($MetadataFile in $HtmlMetadata) {
                # Read html txt
                $FileLocation = $MetadataFile.FullName
                # Read and encode html in UTF8 for better reading of asian characters and symbols
                $HtmlContent = Get-Content -LiteralPath $FileLocation -Encoding UTF8
                $FileName = $MetadataFile.BaseName
                $NfoName = $MetadataFile.BaseName + '.nfo'
                $VideoId = ($FileName -split "$PartDelimiter")[0]
                $NfoPath = Join-Path -Path $MetadataFile.Directory -ChildPath $NfoName
                # Check if the video has multiple parts
                # If it does, write the part number to a variable
                if ($NameSetting -like 'true') {
                    $PartNumber = $FileName[-1]
                }
                else {
                    if ($PartDelimiter -like '-') {
                        $PartNumber = ($FileName -split ($PartDelimiter))[2]
                    }
                    else {
                        $PartNumber = ($FileName -split ($PartDelimiter))[1]
                    }
                }
                # Get video title name from html with regex
                $Title = $HtmlContent -match '<title>(.*) - JAVLibrary<\/title>'
                # Remove broken HTML causing title not to write correctly
                $TitleFixHTML = ($Title -replace '&quot;', '') -replace '#39;s', ''
                $TitleFixed = ((($TitleFixHTML -replace '<title>', '') -replace '- JAVLibrary</title>', '').Trim())
                if ($R18TitleCheck -like 'true' -or $R18MetadataCheck -like 'true') {
                    # Perform a search on R18.com for the video ID
                    $R18Search = Invoke-WebRequest "https://www.r18.com/common/search/searchword=$VideoId/"
                    $R18Url = (($R18Search.Links | Where-Object {$_.href -like "*/videos/vod/movies/detail/-/id=*"}).href)
                }
                if ($R18TitleCheck -like 'true') {
                    if ($R18Search.Content -match "data-product-page-url=`"https://www.r18.com/videos/vod/movies/detail") {
                        $R18Title = (((($R18Search.Content -split "data-title=`"")[1] -split "data-title=`"")[0] -split "data-description")[0].Trim()) -replace ".$"
                    }
                    else {
                        $R18Title = $null
                    }
                    if ($null -like $R18Title -or '' -like $R18Title) {
                        $TitleFixed = ((($TitleFixHTML -replace '<title>', '') -replace '- JAVLibrary</title>', '').Trim())
                    }
                    else {
                        $TitleFixed = "$VideoId $R18Title"
                    }
                }
                # Since the above does a split to find if it's a part
                # Match if the part number found is a one digit number
                if ($PartNumber -match '^\d$') {
                    $Temp = $TitleFixed.Split(' ')[0] + ' ' + "($PartNumber) "
                    $Temp2 = $TitleFixed.Split(' ')[1..$TitleFixed.Length] -join ' '
                    # If html file is detected as multi-part, create a new title as "VidID (Part#) Title"
                    $TitleFixed = ($Temp + $Temp2)
                }
                # Scrape series title from R18
                $R18SeriesTitle = $null
                $R18DirectorName = $null
                if ($R18MetadataCheck -like 'true') {
                    if ($R18Url) {
                        if ($R18Url.Count -gt 1) {
                            $R18Search = Invoke-WebRequest -Uri $R18Url[0] -Method Get
                        }
                        else {
                            $R18Search = Invoke-WebRequest -Uri $R18Url -Method Get
                        }
                        # Scrape series title from R18
                        $R18SeriesUrl = $R18Search.Links.href | Where-Object { $_ -match "Type=series\/" }
                        if ($null -ne $R18SeriesUrl) {
                            $R18SeriesSearch = Invoke-WebRequest -Uri $R18SeriesUrl -Method Get
                            $R18SeriesTitle = (((((($R18SeriesSearch.Content -split "<div class=`"breadcrumbs`">")[1]) -split "<dl><dt>")[1]) -split "<span class=")[0]).Trim()
                        }
                        $R18DirectorString = (((($R18Search -split "<dd itemprop=`"director`">")[1]) -split "<br>")[0])
                        if ($R18DirectorString -notmatch '----') {
                            $R18DirectorName = $R18DirectorString.Trim()
                        }
                    }
                }
                $VideoTitle = $TitleFixed
                $ReleaseDate = ((($HtmlContent -match '<td class="text">\d{4}-\d{2}-\d{2}<\/td>') -split '<td class="text">') -split '</td')[1]
                $ReleaseYear = ($ReleaseDate.Split('-'))[0]
                $Studio = (((($HtmlContent -match '<a href="vl_maker\.php\?m=[\w\d]{1,10}" rel="tag">(.*)<\/a>')) -split 'rel="tag">') -split '</a> &nbsp')[1]
                $Genres = (($HtmlContent -match 'rel="category tag">(.*)<\/a><\/span><\/td>') -Split 'rel="category tag">')
                # Write metadata to file
                Set-Content -LiteralPath $NfoPath -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' -Force
                Add-Content -LiteralPath $NfoPath -Value '<movie>'
                if ($AddTitle -like 'true') { Add-Content -LiteralPath $NfoPath -Value "    <title>$VideoTitle</title>" }
                Add-Content -LiteralPath $NfoPath -Value "    <year>$ReleaseYear</year>"
                Add-Content -LiteralPath $NfoPath -Value "    <releasedate>$ReleaseDate</releasedate>"
                if ($R18DirectorName) { Add-Content -LiteralPath $NfoPath -Value "    <director>$R18DirectorName</director>" }
                Add-Content -LiteralPath $NfoPath -Value "    <studio>$Studio</studio>"
                if ($AddGenres -like 'true') {
                    foreach ($Genre in $Genres[1..($Genres.Length - 1)]) {
                        $GenreString = (($Genre.Split('<'))[0]).Trim()
                        Add-Content -LiteralPath $NfoPath -Value "    <genre>$GenreString</genre>"
                    }
                }
                if ($AddTags -like 'true') {
                    foreach ($Genre in $Genres[1..($Genres.Length - 1)]) {
                        $GenreString = (($Genre.Split('<'))[0]).Trim()
                        Add-Content -LiteralPath $NfoPath -Value "    <tag>$GenreString</tag>"
                    }
                }
                if ($R18SeriesTitle) { Add-Content -LiteralPath $NfoPath -Value "    <tag>Series: $R18SeriesTitle</tag>"}
                # Add actress metadata
                $ActorSplitString = '<span class="star">'
                $ActorSplitHtml = $HtmlContent -split $ActorSplitString
                $Actors = @()
                foreach ($Section in $ActorSplitHtml) {
                    $FullName = (($Section -split "rel=`"tag`">")[1] -split "<\/a><\/span>")[0]
                    if ($FullName -ne '') {
                        if ($FullName.Length -lt 25) {
                            $Actors += $FullName
                        }
                    }
                }
                foreach ($Actor in $Actors) {
                    $Content = @(
                        "    <actor>"
                        "        <name>$Actor</name>"
                        "    </actor>"
                    )
                    Add-Content -LiteralPath $NfoPath -Value $Content
                }
                # End file
                Add-Content -LiteralPath $NfoPath -Value '</movie>'
                Write-Output "($Count of $Total) $FileName .nfo processed..."
                # Remove html txt file
                if ($KeepMetadataTxt -eq 'false') {
                    Remove-Item -LiteralPath $MetadataFile.FullName
                }
                $Count++
            }
            pause
        }
        else {
            Write-Warning 'Cancelled by user input. Exiting...'
            pause
        }
    }
}


Set-JAVNfo -Prompt