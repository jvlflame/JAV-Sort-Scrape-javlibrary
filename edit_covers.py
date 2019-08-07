# Use this script if you previously scraped your JAV without having the feature to crop to poster-size

import os
import urllib.request
from PIL import Image
from shutil import move

def edit_covers(s):
    path = os.path.join(s['scraped-covers-path'])
    input("Confirm before editing covers in path: " + path)
    files = []
    # r=root, d=directories, f = files
    for r, d, f in os.walk(path):
        for file in f:
            if ('.jpg' in file and '-thumb' not in file):
                files.append(os.path.join(r, file))

    for f in files:
        cover_path = f
        original_cover = Image.open(cover_path)
        cover_thumb_path = (os.path.splitext(cover_path))[0] + "-thumb.jpg"
        width, height = original_cover.size
        # match JavLibrary cover size
        if (width > 790 and width < 810):
            if (height > 530 and height < 600):
                left = 422
                top = 0
                right = width
                bottom = height
                # crop cover
                cropped_cover = original_cover.crop((left, top, right, bottom))
                if s['keep-original-cover']:
                    # save original cover to cover_thumb_path
                    original_cover.save(cover_thumb_path)
                    print("Saving " + cover_thumb_path)
                    # save cropped cover to original cover_path
                    cropped_cover.save(cover_path)
                    print("Saving " + cover_path)
                else:
                    cropped_cover.save(cover_path)
                    print("Saving " + cover_path)
            
def read_file(path):
    """Return a dictionary containing a map of name of setting -> value"""
    d = {}
    # so we can strip invalid characters for filenames
    translator = str.maketrans({key: None for key in '<>/\\|*:?'})
    with open(path, 'r') as content_file:
        for line in content_file.readlines():
            line = line.strip('\n')
            if not line.startswith('path' and 'scraped-covers-path'):
                line = line.translate(translator)
            if line and not line.startswith('#'):
                split = line.split('=')
                d[split[0]] = split[1]
                if split[1].lower() == 'true':
                    d[split[0]] = True
                elif split[1].lower() == 'false':
                    d[split[0]] = False
    return d

if __name__ == '__main__':
    try:
        settings = read_file('settings_sort_jav.ini')
        edit_covers(settings)
        input("Press Enter to finish.")
    except Exception as e:
        print(e)
        print("Panic! Go find help.")
