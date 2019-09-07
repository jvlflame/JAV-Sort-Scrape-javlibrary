
$VideoId = "336DTT-036"
$GoogleSearch = Invoke-WebRequest -Uri "http://www.google.com/search?q=site:7mmtv.tv+$VideoId"
$7mmLink = ((((($GoogleSearch.Links.href -match "https://7mmtv.tv/zh/amateurjav_content")) -replace 'tv/zh', 'tv/en') -replace '\/url\?q=', '') -split "&amp;")[0]
if ($7mmLink -match $VideoId) {
    $7mmLink = ((((($GoogleSearch.Links.href -match "https://7mmtv.tv/zh/uncensored_content")) -replace 'tv/zh', 'tv/en') -replace '\/url\?q=', '') -split "&amp;")[0]
}

else {
    $7mmLink = ((((($GoogleSearch.Links.href -match "https://7mmtv.tv/zh/uncensored_content")) -replace 'tv/zh', 'tv/en') -replace '\/url\?q=', '') -split "&amp;")[0]
}

else ($null -like $7mmLink -or $7mmLink -like '') {
    "$VideoId not found on 7mmtv. Skipping..."
}


$7mmScrape = Invoke-WebRequest -Uri $7mmLink

$Title = ($7mmScrape.ParsedHtml.title -replace '\[','') -replace '\]', '' 