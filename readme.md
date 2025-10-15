# WiiMart Patcher

WiiMart patcher helps you patch your wbfs games (disk games) to work with dlc. This also implements Wiimmfi due to issues if we were to remain on nintendo wifi urls.

## Usage
How to use:
 - On linux:
   1. Download the static build of the patcher as it contains all the librairies you need, no need to install dependencies.
   2. Run `./WiiMartPatcher --init` to create the required folders 
   3. Download the latest version of <a href="https://wit.wiim.de/download.html">Wit</a> and unzip it.
    3a. Drop the contents of the unzipped folder in the wit directory that WiiMartPatcher created for you (making sure that ./wit/bin/wit exists since thats where it looks for the executable)
    3b. Place the folders in a known place and use --wit-path /path/to/wit (making sure that /path/to/wit/bin/wit exists since it'll look for the executable there)
    3c. Place the folder in a known place and add /path/to/wit/bin and make sure that you can execute wit without being in that path
   4. Drop all wbfs files in the folder wbfs that the WiiMartPatcher created.
   5. Start patching! (aka just run `./WiiMartPatcher`)
 - On Windows:
   - Coming soon, gotta fix it
 - Mac will NOT be supported, sorry mac users.

