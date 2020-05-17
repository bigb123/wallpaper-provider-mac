#!/usr/bin/env bash
#
# Downoad latest Bing picture and manage former pictures.
# This script is designed to run with Cron (but can be executed manually, too)
#
# Dependencies:
# - jq
# - exiftool (used to write details about the picture to picture's comment metadata)


# CONSTS
#
# Cron has no $USER env var so I need to use 'whoami' command
WALLPAPER_PATH="/Users/$(whoami)/Pictures/Wallpapers"
# Add snap binaries to PATH (jq can be installed there) as normally cron has only PATH=/usr/bin
PATH="$PATH:/usr/local/bin"
export LC_ALL=en_US.UTF-8

# Check if bing webpage is reachable
if [ $(wget -q -O- https://www.bing.com &>/dev/null; echo $?) != 0 ]; then 
  # echo "No internet connection"
  exit 1
fi

# Check if required binaries exists
if [ -z $(jq --version) ]; then
  echo "Please install jq"
  exit 1
fi

if [ -z "$(exiftool -ver)" ]; then
  echo "Please install exiftool"
  exit 1
fi

# Download picture (skip if exist -> no-clobber option)
download_wallpaper() {
  picture_json="$1"

  # Extract file url
  picture_suburl="$(echo $picture_json | jq -r .url)"

  # Extract file name from the link
  file_name=$(echo "$picture_suburl" | sed -E 's,\/th\?id=OHR\.([A-Za-z0-9_.-]*)&rf=LaDigue_1920x1080\.jpg&pid=hp,\1,')

  # Download picture
  wget --quiet -O "$file_name" --no-clobber "https://www.bing.com$picture_suburl"

  # There is a problem with setting a comment - sometimes it's there, sometimes not. Let's wait a moment and write a comment to
  # a file after some time. Maybe it will fully appear after download and all will be good. 
  
  sleep 600 # Wait 10 minutes before writing a comment

  # Write title and copyright metadata to picture exif comment
  comment="$(echo $picture_json | jq -r .title) - $(echo $picture_json | jq -r .copyright)"
  exiftool -overwrite_original_in_place -comment="$comment" "$WALLPAPER_PATH/$file_name" &>/dev/null

  # Write comment to Finder comments section
  osascript -e 'on run {f, c}' -e 'tell app "Finder" to set comment of (POSIX file f as alias) to c' -e end "$WALLPAPER_PATH/$file_name" "$comment" &>/dev/null
}

# Check if dir to store wallpapers exists
if [ ! -d "$WALLPAPER_PATH" ]; then
    mkdir -p "$WALLPAPER_PATH" || echo "Cannot create path to store wallpapers"

    # Download some latest wallpapers from Bing to provide some randomize.
    cd "$WALLPAPER_PATH" || exit 1
    # Bing link parameters explanation:
    # idx - index number of item to display as first. Available values: 0-7.
    # n - number of things to display. Available values: 0-8 (zero displays nothing).
    # mkt - localization (market). Looks like Bing sets wallpapers depends on what
    #       language do you use. Tested values that works: en-US, en-AU, pl-PL.
    for number in $(seq 0 100); do
      picture_json="$(wget --quiet -O- 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-AU' | jq -r .images[$number])"

      # if there's no more pictures to process just break the loop
      if [ "$picture_json" == "null" ]; then
        break
      fi

      download_wallpaper "$picture_json"

    done

    # for picture_json in "$(wget --quiet -O-  'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-AU' | jq -r .images[])"; do
    #
    #   echo download_wallpaper "$picture_json"
    # done
fi

cd "$WALLPAPER_PATH" || exit 1
# Move oldest pictures to Archive and keep just a bunch of them as active.
number_of_wallpapers_to_keep=30
number_of_current_wallpaper=0
mkdir -p "Archive"
for wallpaper in $(ls -t *.jpg 2>/dev/null); do
  if [ $number_of_current_wallpaper -lt $number_of_wallpapers_to_keep ]; then
    # Keep the wallpaper
    number_of_current_wallpaper=$(($number_of_current_wallpaper+1))
  else
    # Remove wallpaper
    mv "$wallpaper" Archive/ &>/dev/null
  fi
done

# Download latest picture (skip if exist -> no-clobber option)
#
# Bing api https link arguments useful info:
# idx - index number of item to display as first. Available values: 0-7.
# n - number of things to display. Available values: 0-8 (zero displays nothing).
# mkt - localization (market). Looks like Bing sets wallpapers depends on what
#       language do you use. Tested values that works: en-US, en-AU, pl-PL.
download_wallpaper "$(wget --quiet -O- 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-AU' | jq -r .images[0])"
