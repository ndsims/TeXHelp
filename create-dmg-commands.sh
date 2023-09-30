#!/bin/sh
rm TeXHelp.dmg
create-dmg \
   --app-drop-link 530 218 \
   --icon TeXHelp.app 130 218 \
   --eula TeXHelp/COPYING \
   --codesign "Developer ID Application: Neil Sims (22BF9TB59Q)" \
   --background Background.png \
   --window-size 660 400 \
   TeXHelp.dmg TeXHelp.app
 
# https://daveceddia.com/manually-symbolicate-crash-log-macos-app/
