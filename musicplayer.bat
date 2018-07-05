chcp 936
del *.zip
del *.ppu
del *.o
del *.or
del *.a
del *.exe
del musicplayer.exe
del musicplayer.zip
windres.exe -i musicplayer.rc -o musicplayer.res
fpc -WG musicplayer.pas -omusicplayer.exe -Os
start musicplayer.exe
if not exist musicplayer.exe pause
if not exist musicplayer.exe exit
mkdir musicplayer
copy musicplayer.exe musicplayer\musicplayer.exe
copy musicplayer.ico musicplayer\musicplayer.ico
copy musicplayer.txt musicplayer\musicplayer.txt
copy LICENSE musicplayer\LICENSE
copy README.md musicplayer\README.md
xcopy *.dll musicplayer\* /y /r
mkdir musicplayer\source
xcopy *.pas musicplayer\source\* /y /r
xcopy *.pp musicplayer\source\* /y /r
xcopy *.inc musicplayer\source\* /y /r
xcopy *.rc musicplayer\source\* /y /r
zip -q -r musicplayer.zip musicplayer
rmdir musicplayer /s /q
del *.obj
del *.ppu
del *.o
del *.or
del *.a

"G:\Program Files\Enigma Virtual Box\enigmavbconsole.exe" musicplayer.evb