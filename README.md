# Scripts turning mpv to a lightweight image viewer while supporting common interactions
## 1. Install the autoload script from [mpv repo](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua)
## 2. Place three scripts into the /scripts dir
## 3. Supported interactions:
- **ctrl + wheel**: zoom in or out
- **ctrl + r** and **ctrl + shift + r**: rotate
- **g**: activate navigation, type **number** then press **enter** key to jump to the image in current dir. press **esc** to quit.
- **wheel** and **shift + wheel**: pan the image
- **arrow keys** and **wasd** and **PAGEUP PAGEDOWN HOME END**: navigate
## 4. Recommended addition to mpv.conf
Especially the last two lines
```
[image]
profile-cond=(p['current-tracks/video/image']) and (not p['current-tracks/video/albumart'])
osd-level=1
prefetch-playlist=yes
screenshot-high-bit-depth=no
pause=yes
osc=no
```
## Note: it only activates on image files.
