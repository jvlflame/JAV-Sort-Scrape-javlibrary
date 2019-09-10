$FilePath = ((Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'settings_sort_jav.ini')) -match '^path').Split('=')[1]
$Videos = Get-ChildItem -Path $FilePath -Recurse | Where-Object {$_.Extension -like ".mp4" `
                                                             -or $_.Extension -like ".mkv"`
                                                             -or $_.Extension -like ".wmv"`
                                                             -or $_.Extension -like '.avi'`
                                                             -or $_.Extension -like '.flv'}
foreach ($Video in $Videos) {
    $VideoId = $Video.BaseName
    $GoogleScrape = Invoke-WebRequest -Uri "https://www.google.com/search?q=site:7mmtv.tv+$VideoId"
    #$GoogleScrape = Invoke-WebRequest -Uri https://duckduckgo.com/?q=site%3A7mmtv.tv+$VideoID/
    $7mmLink = (((((($GoogleScrape.Links.href -match '7mmtv.tv/../amateurjav_content')) -replace '7mmtv.tv/..', '7mmtv.tv/ja') -replace '\/url\?q=', '') -split "&amp;")[0])
    Write-Host $7mmLink
    if ($7mmLink -notmatch $VideoId) {
        $7mmLink = (((((($GoogleScrape.Links.href -match '7mmtv.tv/../uncensored_content')) -replace '7mmtv.tv/..', '7mmtv.tv/ja') -replace '\/url\?q=', '') -split "&amp;")[0])
        if (($7mmLink -replace "%2520", " ") -notmatch $VideoId -or $null -like $7mmLink -or $7mmLink -like '') {
            "$VideoId not found on 7mmtv. Skipping..."
        }
    }
    else {
        $7mmScrape = Invoke-WebRequest -Uri $7mmLink

        $ScrapedTitle = ((($7mmScrape.Content -split "<title>")[1]) -split " -")[0]
        $Studio = ((((($7mmScrape.Content -split "<li class='posts-message'><a target=`"_top`"")[1]) -split ".html'>")[1]) -split "<\/a>")[0]
        if ($Studio -like "----") {
            $Studio = ((((($7mmScrape.Content -split "<li class='posts-message'><a target=`"_top`" href='https:\/\/7mmtv.tv\/ja\/amateurjav_makersr")[1]) -split ".html'>")[1]) -split "<\/a>")[0]
        }
        $ReleaseDate = ((((($7mmScrape.Content -split "配信開始日:<\/li>")[1]) -split ">")[1]) -split "<")[0]
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
    
        Write-Host $7mmLink
        Write-Host $ScrapedTitle
        Write-Host $Studio
        Write-Host $GenreObject
        Write-Host $ActorObject
        Write-Host $ReleaseDate
        Write-Host $ReleaseYear
    }
    Start-Sleep -Seconds 10
}

<# 
# Write metadata to file
Set-Content -LiteralPath $NfoPath -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' -Force
Add-Content -LiteralPath $NfoPath -Value '<movie>'
if ($AddTitle -like 'true') {
    Add-Content -LiteralPath $NfoPath -Value "    <title>$ScrapedTitle</title>"
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
 #>