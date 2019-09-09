import cfscrape

def get_javlibactors(startpage, endpage, letter):
    scraper = cfscrape.create_scraper()  # returns a CloudflareScraper instance
    lastinitial = str(letter)
    for i in range(startpage, endpage+1):
        pagenum = str(i)
        f = open(letter + "_" + "actors" +  "_" +pagenum + ".txt", "a")
        actorpage = str(scraper.get("http://www.javlibrary.com/en/star_list.php?prefix=" + "_" + lastinitial + "&page=" + pagenum).content)  # => "<!DOCTYPE html><html><head>..."
        f.write(actorpage)
        f.close()

if __name__ == '__main__':
    get_javlibactors(1, 44, "a")
    get_javlibactors(1, 2, "b")
    get_javlibactors(1, 3, "c")
    get_javlibactors(1, 2, "d")
    get_javlibactors(1, 4, "e")
    get_javlibactors(1, 12, "f")
    get_javlibactors(1, 2, "g")
    get_javlibactors(1, 38, "h")
    get_javlibactors(1, 21, "i")
    get_javlibactors(1, 3, "j")
    get_javlibactors(1, 67, "k")
    get_javlibactors(1, 1, "l")
    get_javlibactors(1, 57, "m")
    get_javlibactors(1, 30, "n")
    get_javlibactors(1, 20, "o")
    get_javlibactors(1, 1, "p")
    get_javlibactors(1, 1, "q")
    get_javlibactors(1, 4, "r")
    get_javlibactors(1, 62, "s")
    get_javlibactors(1, 33, "t")
    get_javlibactors(1, 7, "u")
    get_javlibactors(1, 1, "v")
    get_javlibactors(1, 4, "w")
    #get_javlibactors(1, 1, "x")
    get_javlibactors(1, 25, "y")
    get_javlibactors(1, 1, "z")

""" 
    for i in range(1, 45):
        pagenum = str(i)
        f = open("actor" + pagenum + ".txt", "a")
        actorpage = str(scraper.get("http://www.javlibrary.com/en/star_list.php?prefix=A&page=" + pagenum).content)  # => "<!DOCTYPE html><html><head>..."
        f.write(actorpage)
        f.close()
 """
""" 
file = open("actors.txt","w+")
file.write(scraper.get("http://www.javlibrary.com/en/star_list.php?prefix=A").content)
file.close
 """
