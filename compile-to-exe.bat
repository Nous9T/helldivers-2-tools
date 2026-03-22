"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /in ".\main.ahk" /out ".\main.exe" /icon ".\resources\icon0.ico" /silent

mkdir ".\v0.0.0-changeme"
mkdir ".\v0.0.0-changeme\default-configs"
mkdir ".\v0.0.0-changeme\resources"

move ".\main.exe" ".\v0.0.0-changeme"
copy ".\default-configs\*" ".\v0.0.0-changeme\default-configs\"
copy ".\resources\icon0.ico" ".\v0.0.0-changeme\resources\"