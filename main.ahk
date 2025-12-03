#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

#include "lib.ahk"

SetupStratagemKeybinds(IsDebugging := False)
SetupLoadoutKeybinds(IsDebugging := False)

#include "gui.ahk"

;======================================================================
;; Program Start
;======================================================================

Main() {
	MainGui.Show("AutoSize")
}

Main()