# This script is very basic in functionality and not well-tested
# If you encounter a bug, please open an issue or send me a message directly
# Use at your own risk

$FilePath = ((Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'settings_sort_jav.ini')) -match '^7mm-files-path').Split('=')[1]
$Videos = Get-ChildItem -Path $FilePath | Where-Object {$_.Extension -like ".mp4" `
                                                             -or $_.Extension -like ".mkv"`
                                                             -or $_.Extension -like ".wmv"`
                                                             -or $_.Extension -like '.avi'`
                                                             -or $_.Extension -like '.flv'}
$Count = 1
$Total = $Videos.Count
Write-Host "Starting scrape for directory $FilePath..."
foreach ($Video in $Videos) {
    $Result = $true
    $VideoId = ($Video.BaseName).ToUpper()
    $r = Invoke-WebRequest ' https://7mmtv.tv/en/amateurjav_random/all/index.html' -SessionVariable my_session
	  $form = $r.Forms[0]
  	$form.fields['search_keyword'] = $VideoId
  	$GoogleScrape = Invoke-WebRequest -Uri ('https://7mmtv.tv/en/searchform_search/all/index.html' + $form.Action) -WebSession $my_session -Method POST -Body $form.Fields
    $7mmLink = (((((($GoogleScrape.Links.href -match '7mmtv.tv/../amateurjav_content')) -replace '7mmtv.tv/..', '7mmtv.tv/ja') -replace '\/url\?q=', '') -split "&amp;")[0])
    if ($7mmLink -notmatch $VideoId) {
        $r = Invoke-WebRequest 'https://7mmtv.tv/en/uncensored_random/all/index.html' -SessionVariable my_session
		    $form = $r.Forms[0]
    		$form.fields['search_keyword'] = $VideoId
		    $GoogleScrape = Invoke-WebRequest -Uri ('https://7mmtv.tv/en/searchform_search/all/index.html' + $form.Action) -WebSession $my_session -Method POST -Body $form.Fields
		    $7mmLink = (((((($GoogleScrape.Links.href -match '7mmtv.tv/../uncensored_content')) -replace '7mmtv.tv/..', '7mmtv.tv/ja') -replace '\/url\?q=', '') -split "&amp;")[0])
        if (($7mmLink -replace "%2520", " ") -notmatch $VideoId -or $null -like $7mmLink -or $7mmLink -like '') {
            "$VideoId not found on 7mmtv. Skipping..."
            $Result = $false
        }
    }
    if ($Result -eq $true) {
        New-Item -ItemType Directory -Path (Join-Path -Path $Video.DirectoryName -ChildPath $VideoId)
        Move-Item -Path $Video.FullName -Destination (Join-Path -Path (Join-Path -Path $Video.DirectoryName -ChildPath $VideoId) -Childpath $Video.Name)
        $NfoPath = (Join-Path -Path (Join-Path -Path $Video.DirectoryName -ChildPath $VideoId) -Childpath "$VideoId.txt")
        $7mmScrape = Invoke-WebRequest -Uri $7mmLink
        $Cover = ($7mmScrape.images | Where-Object {$null -ne $_.title -and $_.title.length -gt 1} | Select-Object src)
        Invoke-WebRequest $Cover.src -OutFile (Join-Path -Path (Join-Path -Path $Video.DirectoryName -ChildPath $VideoId) -Childpath "$VideoId.jpg")
        $ScrapedTitle = ((($7mmScrape.Content -split "<title>")[1]) -split " -")[0]
        $Studio = ((((($7mmScrape.Content -split "<li class='posts-message'><a target=`"_top`"")[1]) -split ".html'>")[1]) -split "<\/a>")[0]
        if ($Studio -like "----") {
            $Studio = ((((($7mmScrape.Content -split "<li class='posts-message'><a target=`"_top`" href='https:\/\/7mmtv.tv\/ja\/amateurjav_makersr")[1]) -split ".html'>")[1]) -split "<\/a>")[0]
        }
        $ReleaseDate = ((($7mmScrape.Content -split "<li class='posts-message'>")[2]) -split "<\/li>")[0] 
        #$ReleaseDate = ((((($7mmScrape.Content -split "配信開始日:<\/li>")[1]) -split ">")[1]) -split "<")[0]
        $ReleaseYear = ($ReleaseDate.Split('-'))[0]
        $Genres = $7mmScrape.Links | Where-Object { $_.outerHTML -match '_category\/' }
        $GenreObject = @()
        foreach ($Genre in $Genres) {
            $GenreObject += (((($Genre -split "_category\/\d{1,6}\/")[1]) -split "\/")[0])
        }
        $Actors = $7mmScrape.Links.href | Where-Object {$_ -like "*avperformer*"}
        $ActorObject = @()
        foreach ($Actor in $Actors) {
            $ActorObject += ((($Actor -split "\d{1,6}\/")[1]) -split "\/")[0]
        }
        <# 
        Write-Host "Link is: $7mmLink"
        Write-Host "Title is: $ScrapedTitle"
        Write-Host "Studio is: $Studio"
        Write-Host "Genres is: $GenreObject"
        Write-Host "Actor is: $ActorObject"
        Write-Host "Release date: $ReleaseDate"
        Write-Host "Release year: $ReleaseYear"
        #>
        # Write metadata to file
        Set-Content -LiteralPath $NfoPath -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        Add-Content -LiteralPath $NfoPath -Value '<movie>'
        Add-Content -LiteralPath $NfoPath -Value "    <title>$ScrapedTitle</title>" 
        Add-Content -LiteralPath $NfoPath -Value "    <year>$ReleaseYear</year>"
        Add-Content -LiteralPath $NfoPath -Value "    <releasedate>$ReleaseDate</releasedate>"
        Add-Content -LiteralPath $NfoPath -Value "    <studio>$Studio</studio>"
        foreach ($Genre in $GenreObject) {
            Add-Content -LiteralPath $NfoPath -Value "    <genre>$Genre</genre>"
        }
        foreach ($Actor in $ActorObject) {
            $Content = @(
                "    <actor>"
                "        <name>$Actor</name>"
                "    </actor>"
            )
            Add-Content -LiteralPath $NfoPath -Value $Content
        }
        # End file
        Add-Content -LiteralPath $NfoPath -Value '</movie>'
        $Content = Get-Content $NfoPath
        $NfoFile = Join-Path -Path (Join-Path -Path $Video.DirectoryName -ChildPath $VideoId) -Childpath "$VideoId.nfo"
        $Content | Out-File -FilePath $NfoFile -Encoding utf8
        Remove-Item -Path $NfoPath
        Write-Output "($Count of $Total) $VideoId .nfo processed..."
        $Count++
    }
}
