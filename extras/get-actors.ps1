$Pages = Get-ChildItem -Path 'Z:\Git\Other\JAV-Sort-Scrape-javlibrary\extras\JAVLibraryActors' | Where-Object {$_.Name -like "*actor*" -and $_.Extension -like ".txt"}

$ActorObject = @()
$FileObject = @()
foreach ($Page in $Pages.FullName) {
    $Actors = Get-Content $Page
    $ActorRegex = (((($Actors -split "\/en\/star_list\.php\?prefix=Z")[1]) -split "vl_star.php\?s=") -split "<div class=`"page_selector`">") | Where-Object {$_ -match "class=`"searchitem`">"}
    #New-Item -ItemType File -Path "Z:\git\other\JAV-Sort-Scrape-javlibrary\actors.csv"
    foreach ($Actor in $ActorRegex) {
        $ActorName = ((($Actor -split ">")[1]) -split "<")[0]
        if ($ActorName -notlike "Z") {
            #$ActorObject += $ActorName
            $ActorObject += New-Object -TypeName psobject -Property @{
                Name  = $ActorName
            }
        }
    }
}

$ActorObject | Select-Object Name | Sort-Object Name | Export-Csv "Z:\Git\Other\JAV-Sort-Scrape-javlibrary\JAVLibraryActors.csv" -Append -NoClobber -NoTypeInformation

$R18ActorObject = Import-Csv "Z:\git\other\JAV-Sort-Scrape-javlibrary\emby_actor_thumbs\R18-Aug-30-2019-last-first.csv"
$JAVLibraryActorObject = Import-Csv "Z:\git\other\JAV-Sort-Scrape-javlibrary\JAVLibraryActors.csv"
$Missing = @()
$In = @()
foreach ($Actor in $R18ActorObject.Name) {
    if ($Actor -in $JAVLibraryActorObject.Name) {
        $In += $Actor
    }
    else {
        $Missing += $Actor
    }
}

$Missing | Out-File "missing.txt"