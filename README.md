# JAV-Sort-Scrape-javlibrary Documentation
[![GitHub release](https://img.shields.io/github/release/jvlflame/JAV-Sort-Scrape-javlibrary?style=flat-square)](https://github.com/jvlflame/JAV-Sort-Scrape-javlibrary/releases)
[![Commits since lastest release](https://img.shields.io/github/commits-since/jvlflame/JAV-Sort-Scrape-javlibrary/latest/master?style=flat-square)](#)
[![Last commit](https://img.shields.io/github/last-commit/jvlflame/JAV-Sort-Scrape-javlibrary?style=flat-square)](https://github.com/jvlflame/JAV-Sort-Scrape-javlibrary/commits/master)
[![Discord](https://img.shields.io/discord/608449512352120834?style=flat-square)](https://discord.gg/K2Yjevk)

The sort_jav Python script originally written by [/u/Ohura](https://reddit.com/user/Ohura) sorts and renames a folder of unsorted JAV videos, downloads covers, and writes the raw JavLibrary page to html. The Set-JAVNfo PowerShell script will work in conjunction with sort_jav to create a functional .nfo metadata file from the html file for easy import into Emby, Jellyfin, Kodi, and/or Plex. Functionality has also been added to scrape actor thumbnails from R18.com and push to Emby/Jellyfin.

There are settings you can configure, such as how the file is renamed, putting them in folders, or downloading covers. Take a look in the [settings_sort_jav.ini](/settings_sort_jav.ini) file for the full set of options.

My goal in updating the sort_jav repository is for it to function as a simple alternative [JAVMovieScraper](https://github.com/DoctorD1501/JAVMovieScraper). If you have any questions, criticisms, or feature requests, feel free to hop into my [throwaway discord channel](https://discord.gg/K2Yjevk) and send me a message.

## Demo
![GitHub Logo](extras/demo.gif)

[Old demo](https://gfycat.com/vibrantambitiouscoyote)

## Table of Contents:
* [Changelog](#Change-Notes)
* [Prerequisites](#Prerequisites)
* [How To Run](#How-To-Run)
* [Settings](#Settings)
* [Alternative Projects](#Alternative-Projects)
* [Additional Notes](#Additional-Notes)
* [Disclaimer](#Disclaimer)

## Changelog
**Older changes have been moved to the [wiki.](https://github.com/jvlflame/JAV-Sort-Scrape-javlibrary/wiki)**
### v1.5.0 (Current version)
- To be updated

## Prerequisites
### tldr;
- Python 3.5+
  - Modules
    - Pillow
    - cfscrape
- NodeJS
- PowerShell 5.0 or higher (6.0+ recommended)
- I believe these scripts can be run on both Windows or Linux, but they are untested on Linux


You must have Python 3.5 or higher installed in order for this to work. If you do not have it or are
unsure, you can download it here: https://www.python.org/downloads/ . This will likely not work
on Python 2.x, and has not been tested on it.

Due to javlibrary adding Cloudflare, you are now required to have cfscrape installed. You can
view how to install it here: https://github.com/Anorov/cloudflare-scrape#installation . You will
need node.js installed to run it. Please refer to their respective documentation on installation.

```
# Required to crop cover images
$ pip install Pillow
# Required to scrape JavLibrary
$ pip install cfscrape
```

You will need PowerShell v5.0 or higher installed to run any of the .ps1 (PowerShell) files (installed on Windows 10 by default). If you get a Remote-ExecutionPolicy error when running, open an **administrator** PowerShell prompt, and run the following to unrestrict the script:
```
> Set-ExecutionPolicy Unrestricted
```

**I highly recommend using PowerShell Core (6.0 or higher) to run these scripts.** 

## How To Run
Please first edit the settings to match your desired preferences. It will not work if you do not do this, particularly with the folder you need to specify.

### sort_jav.py
To run sort_jav.py, you need to set it up so all the videos you want to sort are all in a single folder, and that folder is
the path you specify in the settings. Any files in folders within that folder will be ignored, so you
can move them out of folders they may already be in.

Videos no longer need to be renamed, the sorter can now handle this. Videos with multiple files
that are not tagged correctly may fail to sort. The sorter will not remove any of these files, just
fail to sort them correctly. There are two formats that the sorter will understand for multiple
videos:

1. A letter appears directly after the end of the video ID, for example MIRD150A and
MIRD150B. It will detect them as two files for the same video and rename them
accordingly.
2. The old system method, where the video title has the multiple video suffix attached. For
example, if multiple videos are denoted by a ! symbol and the video is MIRD-150!A and
MIRD-150!B, the sorter will understand.

Once the settings are good, you can double click sort_jav.py to run it. A box should pop up and
stay open while running the script, giving you details about what’s happening. It will give you
another message when it finishes, and hitting enter will close the program at that point.
Alternatively you can invoke it from the command line. A note that this requires .py files to be
associated with the Python executable file (Python.exe for most of us).

### Set-JAVNfo.ps1
Set-JAVNfo.ps1 will search for all .txt files created by sort_jav.py and write a .nfo metadata file. To run Set-JAVNfo.ps1, the files need to be in the path specified in the settings.  The script will search the folder recursively, finding all .txt files containing the html metadata. To run Set-JAVNfo.ps1, right click and select "Run with PowerShell" (double clicking will **NOT** work). By default, the script will run on the path in your settings file. If you want to run the Set-JAVNfo.ps1 script on a different directory, add the `FilePath` parameter to Set-JAVNfo.ps1 on the last line.

### edit_covers.py
edit_covers.py will search for all uncropped covers created by sort_jav.py and crop them if specified in your settings. To run edit_covers.py, the files need to be in the scraped-covers-path specified in the settings. The script will search the folder recurisvely, finding all .jpg files matching both critieria:
- between width 790 and 810
- between heights 530 and 600.

Make sure no irrelevant .jpg files matching these criteria are within this directory or child directory, as it will be permanently modified by the script.To run edit_covers.py, you can double click to run it. You will be prompted to confirm the path of your already scraped covers that you want to crop.

You can also invoke any of the scripts from a **non-administrator** PowerShell prompt as demonstrated in the demo.

## Settings
The `settings_sort_jav.ini` file provided lists the options the user has available to them as well as descriptions on those options. The default settings are my recommendations specifically if you are using Emby. Play around with the settings on a test directory to find your preference.

For settings that say true/false, please use the values true or false to indicate. For other values,
it will use whatever appears directly after the = sign on the same line.

Please note that where it gives you options to include delimiters, certain characters are
disallowed by the OS. If you include them, they will be forcibly removed from your delimiter. For
windows, that would be: / \ : * ? < > |

## Additional Notes
Any video files that can’t be found on javlibrary will be ignored. The program will notify you of
any problems it has trying to sort them.

Occasionally the results will be incorrect, this is because javlibrary incorrectly states the id of the
video on their website. You should double check all the results appear to be correct.

When fixing movies that have been scraped improperly, you can manually download the proper JAVLibrary page as an html, and then add
```<ActressSorted>Actress1|Actress2|Actress3</ActressSorted>``` to the last line of the html, and then rename it to the .txt extension. You can then run Set-JAVNfo.ps1 to write the .nfo metadata file.

Videos with the id code r18 or t28 cannot be detected with the new special method, so the
program defaults to the old method. For videos with those names, please rename them before
running the program.

If a video is renamed to something that is too long, the program will ignore moving it. This may
result in a folder being created but files not being placed in there. For reference, maximum file
lengths are around 255, so for videos with several actresses in them, it’s best not to include the
actress name in both the file and folder.

## Alternative Projects
[JAVMovieScraper](https://github.com/DoctorD1501/JAVMovieScraper) - Scrape multiple JAV databases (or western) and rename/categorize and write metadata

[Rename-JAV-files-javlibrary](https://github.com/jvlflame/Rename-JAV-files-javlibrary) - Use regex checks to rename JAV files to their ID format. No web scraping involved.

## To do

- [x] Add option to input tags/genres in metadata file - v.1.4.0
- [x] Add functionality to crop cover to poster size - v1.4.4
- [x] Scrape actor images and push to Emby - v1.5.0
- [ ] Add more video title renaming options
- [ ] Scrape video plot/description
