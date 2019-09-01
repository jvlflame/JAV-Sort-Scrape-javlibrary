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
        $Table = @{Expression = { $_.Index }; Label = "#"; Width = 2 },
        @{Expression = { $_.Name }; Label = "Name"; Width = 25 },
        @{Expression = { $_.Path }; Label = "Directory" }
        $FileObject | Sort-Object Index | Format-Table -Property $Table | Out-Host
    }

    # Options from settings_sort_jav.ini
    $SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'settings_sort_jav.ini')
    $KeepMetadataTxt = ((Get-Content $SettingsPath) -match '^keep-metadata-txt').Split('=')[1]
    $AddGenres = ((Get-Content $SettingsPath) -match '^include-genre-metadata').Split('=')[1]
    $AddTags = ((Get-Content $SettingsPath) -match '^include-tag-metadata').Split('=')[1]
    $AddTitle = ((Get-Content $SettingsPath) -match '^include-video-title').Split('=')[1]

    # Write txt metadata file paths to $HTMLMetadata
    $HTMLMetadata = Get-ChildItem -LiteralPath $FilePath -Recurse | Where-Object { $_.Name -match '[a-zA-Z]{1,8}-[0-9]{1,8}(.*.txt)' -or $_.Name -match 't28(.*).txt' } | Select-Object Name, BaseName, FullName, Directory
    if ($null -eq $HTMLMetadata) {
        Write-Warning 'No metadata files found! Exiting...'
        pause
    }

    else {
        # Create table to show files being written
        $Index = 1
        $FileObject = @()
        foreach ($File in $HTMLMetadata) {
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
            Write-Output "Metadata to be written:"
            Show-FileChanges
            Write-Output 'Do you want to write nfo metadata for these files?'
            Write-Output 'Confirm changes?'
            $Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'
        }

        if ($Input -like 'y' -or $Input -like 'yes') {
            Write-Output "Writing metadata .nfo files in path: $FilePath ..."
            # Write each nfo file
            $Count = 1
            $Total = $HTMLMetadata.Count
            foreach ($MetadataFile in $HTMLMetadata) {
                # Read html txt
                $FileLocation = $MetadataFile.FullName
                $HTMLContent = Get-Content -LiteralPath $FileLocation
                $FileName = $MetadataFile.BaseName
                $NfoName = $MetadataFile.BaseName + '.nfo'
                $NfoPath = Join-Path -Path $MetadataFile.Directory -ChildPath $NfoName

                # Get metadata information from txt file
                $Title = $HTMLContent -match '<title>(.*) - JAVLibrary<\/title>'
                $TitleFixed = (($Title -replace '<title>', '') -replace '- JAVLibrary</title>', '').Trim()
                $ReleaseDate = ($HTMLContent -match '<td class="text">\d{4}-\d{2}-\d{2}<\/td>').Split(('<td class="text">', '</td>'), 'None')[1]
                $ReleaseYear = ($ReleaseDate.Split('-'))[0]
                $Studio = (($HTMLContent -match '<a href="vl_maker\.php\?m=[\w\d]{1,10}" rel="tag">(.*)<\/a>')).Split(('rel="tag">', '</a> &nbsp'), 'None')[1]
                $Genres = (($HTMLContent -match 'rel="category tag">(.*)<\/a><\/span><\/td>') -Split 'rel="category tag">')
                
                # Write metadata to file
                Set-Content -LiteralPath $NfoPath -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' -Force
                Add-Content -LiteralPath $NfoPath -Value '<movie>'
                if ($AddTitle -like 'true') {
                    Add-Content -LiteralPath $NfoPath -Value "    <title>$TitleFixed</title>"
                }
                Add-Content -LiteralPath $NfoPath -Value "    <year>$ReleaseYear</year>"
                Add-Content -LiteralPath $NfoPath -Value "    <releasedate>$ReleaseDate</releasedate>"
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
                # Add actress metadata
                $Actors = ((($HTMLContent -match '<ActressSorted>(.*)<\/ActressSorted>') -replace '<ActressSorted>', '') -replace '</ActressSorted>', '').Split('|') | Sort-Object
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
