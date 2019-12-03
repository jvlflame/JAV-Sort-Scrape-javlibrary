import os
import urllib.request
import re
#import cfscrape
import cloudscraper
from PIL import Image
from shutil import move

# if we make this global or at least pass it in to the function
# it will yield significantly faster results because it can cache the cookie
# which will make cloudflare think it's the same connection
scraper = cloudscraper.create_scraper()

class AppUrlopener(urllib.request.FancyURLopener):
    version = "Mozilla/5.0"

def read_file(path):
    """Return a dictionary containing a map of name of setting -> value"""
    d = {}
    # so we can strip invalid characters for filenames
    translator = str.maketrans({key: None for key in '<>/\\|*:?'})
    with open(path, 'r') as content_file:
        for line in content_file.readlines():
            line = line.strip('\n')
            if not line.startswith('path'):
                line = line.translate(translator)
            if line and not line.startswith('#'):
                split = line.split('=')
                d[split[0]] = split[1]
                if split[1].lower() == 'true':
                    d[split[0]] = True
                elif split[1].lower() == 'false':
                    d[split[0]] = False
    return d

def strip_id_from_video(path, s):
    """get the id of the video from a video's path"""

    partial_split = path.split(os.sep)[-1].rsplit(".")[0]
    delimiter = s['delimiter-between-multiple-videos']
    if delimiter in partial_split:
        partial_split = partial_split.split(delimiter)[0]

    partial_split = strip_definition_from_video(partial_split)
    return partial_split

def strip_definition_from_video(vid_id):
    """Strip any sort of HD tag from the video"""

    hd = ['[HD]', '[FHD]', '[SD]', '(SD)', '(HD)', '(FHD)']
    for item in hd:
        vid_id = vid_id.replace(item, '')
    return vid_id

def check_vid_id_has_dash(vid_id):
    """Check if the video id has a dash and return one with it if it doesn't"""
    if '-' not in vid_id:
        for i in range(len(vid_id)):
            if vid_id[i] in '0123456789':
                vid_id = vid_id[:i] + '-' + vid_id[i:]
                break
    return vid_id

def getNumExtension(vid_id):
    """Given a video return the number extension"""
    # assume the video id is already fixed to cheat checking and return the fixed set
    return str(vid_id.split('-')[1])

def strip_video_number_from_video(path, vid_id, s):
    """Return the portion that specifies the video number, or none if none exists"""
    delimiter = s['delimiter-between-multiple-videos']
    qualified = path.split(os.sep)[-1]
    split = qualified.split(delimiter)
    if len(split) == 1:
        # check for videos of the form XXX-123A.HD.mp4, XXX-123B.HD.mp4
        # they won't match the delimiter but still need to be caught
        nums = getNumExtension(vid_id)
        chars = 'ABCDEFGHIJ'
        index = qualified.find(nums)
        if index > -1:  # found a match
            c = qualified[index + len(nums)].upper()
            if c in chars:
                return str(chars.find(c) + 1)
        return None
    else:
        ret = split[1].rsplit('.')[0]
        if len(ret) > 2:  # this way we catch straggling names
            return None
        else:
            return ret

def get_javlibrary_url(vid_id):
    """get the URL of the video on javlibrary
    returns None if a URL could not be found"""
    vid_id = check_vid_id_has_dash(vid_id.upper())
    try:
        search_url = "http://www.javlibrary.com/en/vl_searchbyid.php?keyword=" + vid_id
        html = get_url_response(search_url, vid_id)

        # we didn't get a valid response
        if html == None:
            return None
        return html
    except:
        return None

def get_url_response(url, vid_id):
    """get the response from a given URL
    includes the video id to verify the URL is correct"""
    # opener = AppUrlopener()
    # response = opener.open(url)
    # contents = (response.read()).decode()
    global scraper
    contents = scraper.get(url).content.decode()
    if check_valid_response(contents, vid_id):
        return contents  # the URL was good
    else:
        # this may return None if the correct URL does not exist
        return get_url_response(get_correct_url(contents, vid_id), vid_id)

def check_valid_response(html, vid_id):
    """check if the html was the page we wanted"""
    s = "<title>" + vid_id
    if s in html:
        return True
    return False

def get_correct_url(html, vid_id):
    """get the url that's the exact video we want from a link with multiple results"""
    try:
        url_portion = html.split('" title="' + vid_id + ' ')[0].split('><a href=".')[1]
        return "http://www.javlibrary.com/en" + url_portion
    except:
        return None

def rename_file(path, html, s, vid_id):
    """Rename the file per our settings
    Returns the name of the file regardless of whether it has been renamed"""
    if s['do-not-rename-file']:
        return path
    else:
        if s['include-actress-in-video-name']:
            actress_string = get_actress_string(html, s)
            base = strip_partial_path_from_file(path)
            if s['video-number']:
                if s['actress-before-video-number']:
                    new_fname = vid_id + s['delimiter-between-video-name-actress'] \
                                + actress_string + s['delimiter-between-multiple-videos'] \
                                + s['video-number'] + '.' + path.rsplit('.')[-1]
                    new_path = os.path.join(base, new_fname)
                else:  # actress after
                    new_fname = vid_id + s['delimiter-between-multiple-videos'] \
                                + s['video-number'] + s['delimiter-between-video-name-actress'] \
                                + actress_string + '.' + path.rsplit('.')[-1]
                    new_path = os.path.join(base, new_fname)
            else:
                new_fname = vid_id + s['delimiter-between-video-name-actress'] \
                            + actress_string + '.' + path.rsplit('.')[-1]
                new_path = os.path.join(base, new_fname)
            try:
                os.rename(path, new_path)
                return new_path
            # this happens on dupe or some other failure
            # suce as invalid filname (shouldn't happen), drive full, or filename too long
            except:
                return path
        elif strip_file_name(path) != vid_id:
            base = strip_partial_path_from_file(path)
            if s['video-number']:
                new_fname = vid_id + s['delimiter-between-multiple-videos'] \
                            + s['video-number'] + '.' + path.rsplit('.')[-1]
                new_path = os.path.join(base, new_fname)
            else:
                new_fname = vid_id + '.' + path.rsplit('.')[-1]
                new_path = os.path.join(base, new_fname)
            try:
                os.rename(path, new_path)
                return new_path
            except:
                return path

        else:
            # easier to always return the file name so we can treat both cases the same
            # because when we move it (potentially) we don't care if it has been renamed
            return path

def get_actress_string(html, s):
    """Return the string of the actress names as per the naming convention specified
    Takes in the html contents to filter out the actress names"""
    a_list = get_actress_from_html(html, s)
    actress_string = ''
    # if javlibrary returns no actresses then we'll just say whatever we specified
    if len(a_list) == 0:
        return s['name-for-actress-if-blank']
    for actress in a_list:
        actress_string += actress + s['delimiter-between-multiple-actresses']
    # strip the last delimiter, we don't want it
    actress_string = actress_string[0:-1]
    return actress_string

def get_actress_string_txt(html, s):
    """Return the string of the actress names as per the naming convention specified
    Takes in the html contents to filter out the actress names"""
    a_list = get_actress_from_html_txt(html, s)
    actress_string = ''
    # if javlibrary returns no actresses then we'll just say whatever we specified
    if len(a_list) == 0:
        return s['name-for-actress-if-blank']
    for actress in a_list:
        actress_string += actress + '|'
    # strip the last delimiter, we don't want it
    actress_string = actress_string[0:-1]
    return actress_string

def fix_actress_name(name):
    """Returns the updated name for any actress based on our replacement scheme"""
    """ if you want to ad any additional ways to fix names, simply add another elif line below
    elif name == 'name returned from javlibrary'
        return 'different name'
    """
    if name == 'Kitagawa Eria':
        return 'Kitagawa Erika'
    elif name == 'Oshikawa Yuuri':
        return 'Oshikawa Yuri'
    return name

def get_actress_from_html(html, s):
    """Return a list of actresses from the html
    actresses are strings that are formatted the way we can put them straight in the name"""
    a_list = []
    split_str = '<span class="star">'
    # 1 to end because first will have nothing
    for section in html.split(split_str)[1:]:
        # fname is the full name
        fname = section.split('rel="tag">')[1].split('<')[0]
        fname = fix_actress_name(fname)
        a_list.append(fname)

    fixed_names = []
    for fname in a_list:
        # format this correctly
        if fname.count(' ') == 1:
            last = fname.split(' ')[0]
            first = fname.split(' ')[1]
            if s['name-order'].lower() == 'first':
                new_name = first + s['delimiter-between-actress-names'] + last
                fixed_names.append(new_name)
            elif s['name-order'].lower() == 'last':
                new_name = last + s['delimiter-between-actress-names'] + first
                fixed_names.append(new_name)
        else:
            fixed_names.append(fname)

    return fixed_names

def get_actress_from_html_txt(html, s):
    """Return a list of actresses from the html
    actresses are strings that are formatted the way we can put them straight in the name"""
    a_list = []
    split_str = '<span class="star">'
    # 1 to end because first will have nothing
    for section in html.split(split_str)[1:]:
        # fname is the full name
        fname = section.split('rel="tag">')[1].split('<')[0]
        fname = fix_actress_name(fname)
        a_list.append(fname)

    fixed_names = []
    for fname in a_list:
        # format this correctly
        if fname.count(' ') == 1:
            last = fname.split(' ')[0]
            first = fname.split(' ')[1]
            if s['name-order'].lower() == 'first':
                new_name = first + ' ' + last
                fixed_names.append(new_name)
            elif s['name-order'].lower() == 'last':
                new_name = last + ' ' + first
                fixed_names.append(new_name)
        else:
            fixed_names.append(fname)

    return fixed_names


def create_and_move_video_into_folder(path, s, vid_id, html):
    """Create a folder and then move the given video into it
    Path is the fullpath of the video
    Returns the new path of the video
    Returns the old path if there's an unknown error"""
    folder_name = strip_definition_from_video(vid_id)
    if s['include-actress-name-in-folder']:
        folder_name += s['delimiter-between-video-name-actress'] + get_actress_string(html, s)

    fullpath = os.path.join(strip_partial_path_from_file(path), folder_name)
    if os.path.isdir(fullpath):  # folder already exists so just try moving us there
        try:
            vid_path_portion = path.split(os.sep)[-1]
            new_path = os.path.join(fullpath, vid_path_portion)
            os.rename(path, new_path)
            return new_path
        except FileExistsError as e:
            print('File already exists, could not sort. This might be a multiple file issue')
            return path
    try:
        os.makedirs(fullpath)
    except:
        # this can occur if the folder already exists, name is too long, drive is full
        # since we still want to move files if the folder exists then we'll keep going if that's the case
        if os.path.isdir(fullpath):
            pass
        elif len(fullpath) > 255:
            try:
                print("Path was too long so did not move " + vid_id)
            except:
                print("Path was too long so did not move one file with unknown characters")
        return path
    vid_path_portion = path.split(os.sep)[-1]
    new_path = os.path.join(fullpath, vid_path_portion)
    if os.path.exists(new_path):
        print('Path exists')
    try:
        os.rename(path, new_path)
        return new_path
    except:  # this only happens if it exists or there's a catastrophic failure
        if len(new_path) > 255:
            try:
                print("Path was too long so did not move " + vid_id)
            except:
                print("Path was too long so did not move one file with unknown characters")
        return path
    return path


def strip_partial_path_from_file(path):
    """given a file, strip the path from the file name
    This is the essentially the path to the file's directory
    Returns the stripped path or none if it does not exist"""
    partial_path = _strip_partial_path_helper(path, os.sep)
    if (os.path.exists(partial_path)):
        return partial_path
    return None


def _strip_partial_path_helper(path, delimiter):
    stripped_path = path.split(delimiter)
    partial_path = stripped_path[0] + os.sep + stripped_path[1]
    for part in stripped_path[2:-1]:
        partial_path = os.path.join(partial_path, part)
    return partial_path


def get_cover_for_video(path, vid_id, s, html):
    """Get the cover for the video denoted by path from the specified html"""
    # path needs to be stripped but otherwise we can use it to store the video
    # html should have the cover there we can take
    img_link = get_image_url_from_html(html)
    # TODO:
    # create the path name based on the settings file
    base = strip_partial_path_from_file(path)
    fname = strip_definition_from_video(vid_id)
    if s['do-not-rename-file']:
        fullpath = (os.path.splitext(path)[0])
        save_image_from_url_to_path(fullpath, img_link)
    else:
        if (s['include-actress-name-in-cover']):
            if (s['include-cover-all']):
                if(s['include-actress-in-video-name']):
                    if s['video-number']:
                        fname += s['delimiter-between-multiple-videos'] + s['video-number'] + s['delimiter-between-video-name-actress'] 
                        actress_string = get_actress_string(html, s)
                        fname += actress_string
                    else:
                        fname += s['delimiter-between-video-name-actress'] 
                        actress_string = get_actress_string(html, s)
                        fname += actress_string
        else:
            if(s['include-cover-all']):
                if s['video-number']:
                    fname += s['delimiter-between-multiple-videos'] + s['video-number']

        fullpath = os.path.join(base, fname)
        save_image_from_url_to_path(fullpath, img_link)

    # Crop full cover to 378x539 to show only front cover
    if s['crop-cover-to-poster']:
        cover_path = fullpath + ".jpg"
        cover_thumb_path = fullpath + "-thumb.jpg"
        original_cover = Image.open(cover_path)
        width, height = original_cover.size
        left = width/1.895734597
        top = 0
        right = width
        bottom = height
        cropped_cover = original_cover.crop((left, top, right, bottom))
        # Recreate and rename original cover to cover-thumb.jpg if setting is true
        if s['keep-original-cover']:
            original_cover.save(cover_thumb_path)
            cropped_cover.save(cover_path)
        else:
            cropped_cover.save(cover_path)

def save_image_from_url_to_path(path, url):
    """save an image denoted by the url to the path denoted by path
    with the given name"""
    urllib.request.urlretrieve(url, path + ".jpg")
    # if we move the file it should fix itself
    try:
        drive = path.split(os.sep)[0]
        temp_location = drive + os.sep + path + '.jpg'
        os.rename(path + ".jpg", temp_location)
        os.rename(temp_location, path + ".jpg")
    except:
        pass


def get_image_url_from_html(html):
    """get the url of the image from the supplied html for the page"""
    return "http:" + html.split('<img id="video_jacket_img" src="')[1].split('" width')[0]

def rename_start_quotation(path):
    """Rename files that start with quotations right away just because it'll work easier this way"""
    fname = path.split(os.sep)[-1]
    fname.replace("'", '')  # replace ' with nothing
    new_path = os.sep.join(path.split(os.sep)[:-2])
    try:
        os.rename(path, new_path)
    except:
        pass

def find_id(s):
    """Given a string s, try to find an id within it and return it"""
    regex = "[a-zA-Z]{2,8}[-]?[0-9]{2,5}"
    match = re.search(regex, s)
    if match:
        return correct_vid_id(match.group())
    else:
        return None

def correct_vid_id(vid_id):
    """Check if the video id has a dash and return it with one if it doesn't have it
    also fixes anything that has a digit first"""
    if vid_id[0] in '0123456789':
        findex = None
        for i in range(len(vid_id)):
            if vid_id[i] not in '0123456789':
                findex = i
                break
        for i in range(findex, len(vid_id)):
            if vid_id[i] in '0123456789' and findex:
                if '-' not in vid_id:
                    return vid_id[findex:i] + '-' + vid_id[:findex] + vid_id[i:]
                else:
                    return vid_id[findex:i] + vid_id[:findex] + vid_id[i:]

    if '-' not in vid_id:
        if 'R18' in vid_id or 'T28' in vid_id:
            return vid_id[0:3] + '-' + vid_id[3:]
        else:
            for i in range(len(vid_id)):
                if vid_id[i] in '0123456789':
                    return vid_id[:i] + '-' + vid_id[i:]
    return vid_id


def strip_file_name(path):
    """Given a filepath, strip the name of the file from it"""
    return path.split(os.sep)[-1].rpartition('.')[0]


def strip_full_file_name(path):
    """Given a filepath, return the full name with the filetype"""
    return path.split(os.sep)[-1]


def strip_bad_data(path):
    """Remove any data from the path that might conflict"""
    bad = ['hjd2048.com', 'h264', 'play999']

    for str_to_remove in bad:
        if path.find(str_to_remove) != -1:
            path = path.replace(str_to_remove, '')

    return path


def sort_jav(s):
    """Sort all our unsorted jav as per the specified settings"""
    # store all the files to rename in a list so we don't mess with looping over the files
    temp = []

    for f in os.listdir(s['path']):
        fullpath = os.path.join(s['path'], f)

        # only consider video files
        if not os.path.isdir(fullpath):
            temp.append(fullpath)

    count = 0
    for path in temp:
        count += 1
        try:
            vid_id = correct_vid_id(find_id(strip_bad_data(strip_file_name(path))))
        except:
            # to prevent crashing on r18/t28 files
            vid_id = strip_file_name(path)
        print("Sorting {0}: {1} of {2}".format(vid_id, count, len(temp)))
        try:
            s['video-number'] = strip_video_number_from_video(path, vid_id, s)
            if s['make-video-id-all-uppercase']:
                vid_id = vid_id.upper()
        except Exception as e:
            print("Not sorting {} as it is does not look like a JAV ID".format(vid_id))
            continue
        html = get_javlibrary_url(vid_id)

        if not html:
            try:
                print("Could not find video on javlibrary so skipping " + vid_id)
            except:
                print("Skipping one file with unknown characters in the file name")
            continue

        # rename the file according to our convention
        new_fname = rename_file(path, html, s, vid_id)

        # write a txt file containing html metadata for parsing with Set-JAVNfo.ps1 script
        if s['include-html-txt']:
            # write html to txt file and move to folder
            split_fname = str(os.path.splitext(new_fname)[0])
            base_fname = os.path.basename(new_fname)
            split_base_fname = str(os.path.splitext(base_fname)[0])
            base = strip_partial_path_from_file(split_fname)
            text_file = open(split_fname + '.txt', "w", encoding="utf-8")
            text_file.write(html)

            # write actresses to html metadata file
            actress_string = get_actress_string_txt(html, s)
            text_file.write("\n<ActressSorted>")
            text_file.write(actress_string)
            text_file.write("</ActressSorted>")
            text_file.close()

        # move the file into a folder (if we say to)
        if s['move-video-to-new-folder']:
            path = create_and_move_video_into_folder(new_fname, s, vid_id, html)
            if s['include-html-txt']:
                move(split_fname + '.txt', (os.path.splitext(path))[0] + '.txt')

        # get the cover (if we say to)
        if s['include-cover']:
            get_cover_for_video(path, vid_id, s, html)

if __name__ == '__main__':
    try:
        print("Sorting your JAV, please wait...")
        settings = read_file('settings_sort_jav.ini')
        sort_jav(settings)
        input("Press Enter to finish.")
    except Exception as e:
        print(e)
        print("Panic! Go find help.")
