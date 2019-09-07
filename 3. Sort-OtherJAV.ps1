
$VideoId = "sg032"
$GoogleSearch = Invoke-WebRequest -Uri "http://www.google.com/search?q=site:7mmtv.tv+$VideoId"
$7mmLink = (((((($GoogleSearch.Links.href -match '7mmtv.tv/../amateurjav_content')) -replace '7mmtv.tv/..', '7mmtv.tv/en') -replace '\/url\?q=', '') -split "&amp;")[0])
Write-Host $7mmLink
if ($7mmLink -notmatch $VideoId) {
    $7mmLink = (((((($GoogleSearch.Links.href -match '7mmtv.tv/../uncensored_content')) -replace '7mmtv.tv/..', '7mmtv.tv/jaat') -replace '\/url\?q=', '') -split "&amp;")[0])
    Write-Host $7mmLink
    if ($7mmLink -notmatch $VideoId -or $null -like $7mmLink -or $7mmLink -like '') {
        "$VideoId not found on 7mmtv. Skipping..."
        return
    }
}

$7mmScrape = Invoke-WebRequest -Uri $7mmLink

$ScrapedTitle = ((($7mmScrape.ParsedHtml.title -split '\]')[1]) -split ' - ')[0]
$Title = "$VideoId $ScrapedTItle"
$Tags = ($7mmScrape.Links | Where-Object { $_.outerHTML -match '_category\/' }).InnerHTML | Select-Object -Unique