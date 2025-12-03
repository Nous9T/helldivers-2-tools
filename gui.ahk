#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

;======================================================================
;; Gui Globals (super globals explicitly declared)
;======================================================================

Global GuiListviewFields := Map()
GuiListviewFields["LvGlobals"] := ["Name", "Value"]
GuiListviewFields["LvLoadouts"] := ["Name", "ChosenHotkey", "Route", "Stratagems"]
GuiListviewFields["LvKeybinds"] := ["ChosenHotkey", "Stratagem"]
GuiListviewFields["LvStratagems"] := ["Name", "Keychords"]

;======================================================================
;; MainGui
;======================================================================

TraySetIcon(".\resources\icon0.ico")
MainGui := Gui(,"Helldivers 2 Tools",)

FileMenu := Menu()
FileMenu.Add("&Save All Settings`tCtrl+S", (*) => SaveAllSettingsToIni())
FileMenu.Add("E&xit", (*) => ExitApp())
HelpMenu := Menu()
HelpMenu.Add("&About", (*) => MsgBox("See your Democracy Officer.`n`n`tBy Nous9T", "Help Request"))
Menus := MenuBar()
Menus.Add("&File", FileMenu)
Menus.Add("&Help", HelpMenu)

MainGui.MenuBar := Menus

MainTabs := MainGui.Add("Tab3","w600",["Stratagem Keybinds","Loadouts","Strategem Keychords","Globals"])
;MainTabs.UseTab()

; Strategem Keybinds
MainTabs.UseTab(1)
LvKeybinds := MainGui.Add("ListView", "xp y+m r20 w600 Grid Sort", GuiListviewFields["LvKeybinds"])
LvKeybinds.OnEvent("DoubleClick", Lv_DoubleClickEvent.Bind("LvKeybinds", GuiListviewFields["LvKeybinds"]))
LvKeybinds.OnEvent("ContextMenu", ShowContextMenu.Bind("LvKeybinds", GuiListviewFields["LvKeybinds"]))
For Key, Value in Stratagem_Keybinds {
	LvKeybinds.Add(, Key, Value)
}
Loop GuiListviewFields["LvKeybinds"].Length
	LvKeybinds.ModifyCol(A_Index, "AutoHdr")  ; auto-size columns

; Loadouts / routes
MainTabs.UseTab(2)
LvLoadouts := MainGui.Add("ListView", "xp y+m r20 w600 Grid Sort", GuiListviewFields["LvLoadouts"])
LvLoadouts.OnEvent("DoubleClick", Lv_DoubleClickEvent.Bind("LvLoadouts", GuiListviewFields["LvLoadouts"]))
LvLoadouts.OnEvent("ContextMenu", ShowContextMenu.Bind("LvLoadouts", GuiListviewFields["LvLoadouts"]))
Loop Loadouts.Length {
	StrRoute := ConvertArrayToDelimitedString(Loadouts[A_Index].Route)
	StrStrats := ConvertArrayToDelimitedString(Loadouts[A_Index].Stratagems)
	LvLoadouts.Add(, Loadouts[A_Index].Name, Loadouts[A_Index].ChosenHotkey, StrRoute, StrStrats)
}
Loop GuiListviewFields["LvLoadouts"].Length
	LvLoadouts.ModifyCol(A_Index, "AutoHdr")  ; auto-size columns

; Stratagem Keychords
MainTabs.UseTab(3)
LvStratagems := MainGui.Add("ListView", "xp y+m r20 w600 Grid Sort", GuiListviewFields["LvStratagems"])
LvStratagems.OnEvent("DoubleClick", Lv_DoubleClickEvent.Bind("LvStratagems", GuiListviewFields["LvStratagems"]))
LvStratagems.OnEvent("ContextMenu", ShowContextMenu.Bind("LvStratagems", GuiListviewFields["LvStratagems"]))
For Key, Value in Stratagems_Keychords {
	LvStratagems.Add(, Key, ConvertArrayToDelimitedString(Value))
}
Loop GuiListviewFields["LvStratagems"].Length
	LvStratagems.ModifyCol(A_Index, "AutoHdr")  ; auto-size columns

; Globals Config
MainTabs.UseTab(4)
LvGlobals := MainGui.Add("ListView", "xp y+m r20 w600 Grid", GuiListviewFields["LvGlobals"])
LvGlobals.OnEvent("DoubleClick", Lv_DoubleClickEvent.Bind("LvGlobals", GuiListviewFields["LvGlobals"]))
LvGlobals.OnEvent("ContextMenu", ShowContextMenu.Bind("LvGlobals", GuiListviewFields["LvGlobals"]))
For Key, Value in Config {
	LvGlobals.Add(, Key, Value)
}
Loop GuiListviewFields["LvGlobals"].Length
	LvGlobals.ModifyCol(A_Index, "AutoHdr")  ; auto-size columns
LvGlobals.ModifyCol(2, "Integer")  ; For sorting purposes, indicate that column 2 is an integer.

MainTabs.UseTab() ; end tab assignments

; Cleanup
MainGui.OnEvent("Close", (*) => ExitApp())
MainGui.OnEvent("Escape", (*) => ExitApp())

;======================================================================
;; Event Functions
;======================================================================

Lv_DoubleClickEvent(LvName, LvFields, Lv, RowNumber) {
	KeyVals := GetListviewRowValues(LvName, LvFields, RowNumber)
	If (RowNumber < 1) ; don't show edit menu for adding new
		Return
	Switch LvName {
		Case "LvGlobals":
			ShowGlobalEditGui(KeyVals)
		Case "LvLoadouts":
			ShowLoadoutEditGui(KeyVals)
		Case "LvKeybinds":
			ShowKeybindEditGui(KeyVals)
		Case "LvStratagems":
			ShowStratagemEditGui(KeyVals)
	}
	Return
}

GetEditGuiSpawnPosition() {
	; Get the position and size of the main window
	WinGetPos &MainX, &MainY, &MainWidth, &MainHeight, MainGui
	
	; Calculate the popup window's position (to the right and below the main window)
	PopupX := MainX + 100 ; pixels offset
	PopupY := MainY + 100 ; pixels offset
	Output := "x" . PopupX . "y" . PopupY
	
	Return Output
}


NoAction(*) {
	; Do nothing
}

;======================================================================
;; CRUD Right click menu
;======================================================================

CrudMenu := Menu()

ShowContextMenu(LvName, KeyVals, Lv, RowNumber, IsRightClick, X, Y) {
	If (not IsRightClick) {
		Return
	}
	
	CrudMenu.Delete() ; delete all to start over
	
	If (LvName = "LvGlobals") {
		CrudMenu.Add("Edit", CrudMenuHandler.Bind(LvName, KeyVals))
		CrudMenu.Add("Save", CrudMenuHandler.Bind(LvName, KeyVals))
		CrudMenu.Show()
		Return
	}
	
	For each, MenuItem in ["New", "Edit", "Delete", "Save"] {
		CrudMenu.Add(MenuItem, CrudMenuHandler.Bind(LvName, KeyVals))
	}

	CrudMenu.Show(X, Y)
	Return
}

CrudMenuHandler(LvName, LvFields, ItemName, ItemPos, MyMenu) {
	Lv := %LvName%
	
	Switch LvName {
		Case "LvGlobals":
			ShowEditGui := "ShowGlobalEditGui"
		Case "LvLoadouts":
			ShowEditGui := "ShowLoadoutEditGui"
		Case "LvKeybinds":
			ShowEditGui := "ShowKeybindEditGui"
		Case "LvStratagems":
			ShowEditGui := "ShowStratagemEditGui"
	}
	
	RowNumber := 0  ; start the search at the top of the list
	
	Switch ItemName {
		Case "New":
			KeyVals := GetListviewRowValues(LvName, LvFields, RowNumber)
			%ShowEditGui%(KeyVals)
		Case "Edit":
			; could also bind RowNumber from ShowContextMenu call if wanted, but might add multi-edit later
			RowNumber := Lv.GetNext(RowNumber) ; only a single result, not multi-editing (otherwise use Loop)
			If (RowNumber = 0) ; don't show edit menu when clicking empty space
				Return
			KeyVals := GetListviewRowValues(LvName, LvFields, RowNumber)
			%ShowEditGui%(KeyVals)
		Case "Delete":
			Loop {
				; REMEMBER: GetNext parameter is the START position of where to search
				; Since deleting a row reduces the RowNumber of all other rows beneath it,
				; subtract 1 so that the search includes the same row number that was previously
				; found (in case adjacent rows are selected):
				RowNumber := Lv.GetNext(RowNumber - 1)
				if not RowNumber  ; The above returned zero, so there are no more selected rows.
					break
				
				Field1 := Lv.GetText(RowNumber)
				Field2 := Lv.GetText(RowNumber, 2)
				If (LvName = "LvKeybinds") {
					Hotkey(Field1,NoAction,"Off")
					Stratagem_Keybinds.Delete(Field1)
				}
				Else If (LvName = "LvLoadouts") {
					Hotkey(Field2,NoAction,"Off")
					Loadouts.RemoveAt(GetLoadoutObjIndexByName(Field1))
				}
				Else If (LvName = "LvStratagems") {
					Stratagems_Keychords.Delete(Field1)
				}
				Lv.Delete(RowNumber)  ; Clear the row from the ListView.
			}
		Case "Save":
			If (LvName = "LvGlobals") {
				MsgBox("Saving globals to config.ini")
				GlobalsToIni()
			}
			Else If (LvName = "LvLoadouts") {
				MsgBox("Saving loadouts to loadouts.ini")
				LoadoutsToIni()
			}
			Else If (LvName = "LvKeybinds") {
				MsgBox("Saving keybinds to stratagems.ini")
				KeybindsToIni()
			}
			Else If (LvName = "LvStratagems") {
				MsgBox("Saving stratagem keychords to stratagems.ini")
				KeychordsToIni()
			}
	}
}

;======================================================================
;; Globals Editing Gui
;======================================================================

GlobalsEditGui := Gui(,"Edit Globals")
GlobalsEditGui.Opt("+Owner" MainGui.Hwnd)
GlobalsEditGui.Add("Text", "xm", "RowNumber: ")
GlobalsEditGui.Add("Edit", "yp x100 w200 vRowNumber", 0)
GlobalsEditGui["RowNumber"].Enabled := 0
GlobalsEditGui.Add("Text", "xm", "Name: ")
GlobalsEditGui.Add("Edit", "yp x100 w200 vName", 0)
GlobalsEditGui["Name"].Enabled := 0
GlobalsEditGui.Add("Text", "xm", "Value: ")
GlobalsEditGui.Add("Edit", "yp x100 w200 vValue", 0)
GlobalsEditGui["Value"].Enabled := 1
GlobalsEditGui.Add("Button", "Default", "Register").OnEvent("Click", ModifyGlobalSettings.Bind("GlobalsEditGui"))

ShowGlobalEditGui(KeyVals) {
	GlobalsEditGui["RowNumber"].Value := KeyVals["RowNumber"]
	GlobalsEditGui["Name"].Value := KeyVals["Name"]
	GlobalsEditGui["Value"].Value := KeyVals["Value"]
	GlobalsEditGui.Show(GetEditGuiSpawnPosition())
	Return
}

ModifyGlobalSettings(ControlName, *) {
	Saved := %ControlName%.Submit(False) or 0
	If (IsInteger(Saved.Value)) {
		LvGlobals.Modify(Integer(Saved.RowNumber),,Trim(Saved.Name),Integer(Saved.Value))
		Config[Saved.Name] := Saved.Value
	}
	Else {
		MsgBox("Error, value must be a whole number.")
	}
}

;======================================================================
;; Loadouts Editing Gui
;======================================================================

LoadoutsEditGui := Gui(,"Edit Loadout")
LoadoutsEditGui.Opt("+Owner" MainGui.Hwnd)
LoadoutsEditGui.Add("Text", "xm", "RowNumber: ")
LoadoutsEditGui.Add("Edit", "yp x100 w200 vRowNumber", 0)
LoadoutsEditGui["RowNumber"].Enabled := 0
LoadoutsEditGui.Add("Text", "xm", "Name: ")
LoadoutsEditGui.Add("Edit", "yp x100 w200 vName", "")
LoadoutsEditGui.Add("Text", "xm", "Hotkey: ")
LoadoutsEditGui.Add("Hotkey", "yp x100 w200 vChosenHotkey", "None")
LoadoutsEditGui.Add("Text", "xm", "Route: ")
LoadoutsEditGui.Add("Edit", "yp x100 w400 vRoute", "")
LoadoutsEditGui.Add("Text", "xm", "Stratagems: ")
LoadoutsEditGui.Add("Edit", "yp x100 w400 vStratagems", "")
LoadoutsEditGui.Add("Button", "Default", "Register").OnEvent("Click", RegisterLoadout.Bind("LoadoutsEditGui"))

ShowLoadoutEditGui(KeyVals) {
	LoadoutsEditGui["RowNumber"].Value := KeyVals["RowNumber"]
	LoadoutsEditGui["Name"].Value := KeyVals["Name"]
	LoadoutsEditGui["ChosenHotkey"].Value := KeyVals["ChosenHotkey"]
	
	If (KeyVals["RowNumber"] = 0) {
		Route := ''
		Stratagems := ''
	}
	Else {
		Route := KeyVals["Route"]
		Stratagems := KeyVals["Stratagems"]
	}
	
	LoadoutsEditGui["Route"].Value := Route
	LoadoutsEditGui["Stratagems"].Value := Stratagems
	LoadoutsEditGui.Show(GetEditGuiSpawnPosition())
	Return
}

RegisterLoadout(ControlName, *) {
	Saved := %ControlName%.Submit(False) or 0
	RowNumber := Integer(Saved.RowNumber)
	Name := Trim(StrUpper(Saved.Name))
	ChosenHotkey := Trim(Saved.ChosenHotkey)
	Route := Trim(StrUpper(Saved.Route))
	Stratagems := Trim(StrUpper(Saved.Stratagems))
	
	If (Name = '' or Name = "None" or ChosenHotkey = '' or Route = '' or Stratagems = '') {
		MsgBox("Error saving. Make sure all fields are filled.")
		Return
	}
	
	; does loadout name and/or keybind exists already
	NameExists := False
	LoadoutKeybindExists := False
	StratagemKeybindExists := False
	Loop Loadouts.Length {
		If (Loadouts[A_Index].Name = Name)
			NameExists := True
		If (Loadouts[A_Index].ChosenHotkey = ChosenHotkey)
			LoadoutKeybindExists := True
	}
	If (ArrayHasValue(GetMapKeys(Stratagem_Keybinds), ChosenHotkey)) {
		StratagemKeybindexists := True
	}
	
	NewLoadoutObj := Object()
	NewLoadoutObj.Name := Name
	NewLoadoutObj.ChosenHotkey := ChosenHotkey
	NewLoadoutObj.Route := StrSplit(Route, ',')
	NewLoadoutObj.Stratagems := StrSplit(Stratagems, ',')
	
	; if this is a new record
	If (RowNumber = 0) {
		If (NameExists) {
			MsgBox("Loadout name already set for another loadout.")
			Return
		}
		Else If (LoadoutKeybindExists) {
			MsgBox("Keybind already set for another loadout.")
			Return
		}
		Else If (StratagemKeybindExists) {
			MsgBox("Keybind already set for a stratagem.")
			Return
		}
		LvLoadouts.Add(,Name,ChosenHotkey,Route,Stratagems)
		Loadouts.Push(NewLoadoutObj)
	}
	; if this is editing existing
	Else If (RowNumber > 0) {
		; check for duplicate loadout name
		Loop LvLoadouts.GetCount() {
			LvRowName := LvLoadouts.GetText(A_Index)
			If ((LvRowName = Name) and (A_Index != RowNumber)) {
				MsgBox("Loadout name already set for another loadout.")
				Return
			}
		}
		
		; check if keybind already exists elsewhere (that isn't itself)
		If (LoadoutKeybindExists and LvLoadouts.GetText(RowNumber, 2) != ChosenHotkey) {
			MsgBox("Keybind already set for another loadout.")
			Return
		}
		Else If (StratagemKeybindExists) {
			MsgBox("Keybind already set for a stratagem.")
			Return
		}
		
		LoadoutObjIndex := GetLoadoutObjIndexByName(LvLoadouts.GetText(RowNumber))
		For Key, Value in NewLoadoutObj.OwnProps() {
			Loadouts[LoadoutObjIndex].%Key% := Value
		}
		; modify the listview after the global, needs the original Name value before edit
		LvLoadouts.Modify(RowNumber,,Name,ChosenHotkey,Route,Stratagems)
	}
	
	SetupLoadoutHotkey(NewLoadoutObj.ChosenHotkey, GetLoadoutObjIndexByName(Name), IsDebugging := False)
}

;======================================================================
;; Keybind Editing Gui
;======================================================================

KeybindEditGui := Gui(,"Edit Keybinding")
KeybindEditGui.Opt("+Owner" MainGui.Hwnd)
KeybindEditGui.Add("Text", "xm", "RowNumber: ")
KeybindEditGui.Add("Edit", "yp x100 w200 vRowNumber", 0)
KeybindEditGui["RowNumber"].Enabled := 0
KeybindEditGui.Add("Text", "xm", "Hotkey: ")
KeybindEditGui.Add("Hotkey", "yp x100 w200 vChosenHotkey", "None")
KeybindEditGui.Add("Text", "xm", "Stratagem:")
KeybindEditGui.Add("DropDownList", "yp x100 w200 vStratagem Choose" 0, GetStratagemNames())
KeybindEditGui.Add("Button", "Default", "Register").OnEvent("Click", RegisterHotkey.Bind("KeybindEditGui"))

ShowKeybindEditGui(KeyVals) {
	StratagemNames := GetStratagemNames()
	KeybindEditGui["RowNumber"].Value := KeyVals["RowNumber"]
	KeybindEditGui["ChosenHotkey"].Value := KeyVals["ChosenHotkey"]
	
	; refresh the keybind edit gui in case stratagems were edited
	KeyBindEditGui["Stratagem"].Delete()
	KeybindEditGui["Stratagem"].Add(StratagemNames)
	KeybindEditGui["Stratagem"].Value := GetValueIndexFromArray(StratagemNames, KeyVals["Stratagem"])
	
	KeybindEditGui.Show(GetEditGuiSpawnPosition())
	Return
}

RegisterHotkey(ControlName, *) {
    Saved := %ControlName%.Submit(False) or 0
	
	RowNumber := Integer(Saved.RowNumber)
	ChosenHotkey := Trim(Saved.ChosenHotkey)
	Stratagem := Trim(Saved.Stratagem)
	
	;For Name, Value in Saved.OwnProps() {
	;	MsgBox(Name . " " . Value)
	;}
	
	If (ChosenHotkey = '' or ChosenHotkey = "None" or Stratagem = '') {
		MsgBox("Error saving. Invalid hotkey/stratagem combination.")
		Return
	}
	
	; does hotkey keybind exists already
	LoadoutKeybindExists := False
	StratagemKeybindExists := False
	Loop Loadouts.Length {
		If (Loadouts[A_Index].ChosenHotkey = ChosenHotkey)
			LoadoutKeybindExists := True
	}
	If (ArrayHasValue(GetMapKeys(Stratagem_Keybinds), ChosenHotkey)) {
		StratagemKeybindExists := True
	}
	
	; if this is a new record
	If (RowNumber = 0) {
		If (LoadoutKeybindExists) {
			MsgBox("Keybind already set for a loadout.")
			Return
		}
		Else If (StratagemKeybindExists) {
			MsgBox("Keybind already set for another stratagem.")
			Return
		}

		LvKeybinds.Add(,ChosenHotkey,Stratagem)
	}
	; if this is editing existing
	Else If (RowNumber > 0) {
		; check for any duplicate keys before committing the edit
		Loop LvKeybinds.GetCount() {
			LvRowHotkey := LvKeybinds.GetText(A_Index)
			If ((LvRowHotkey = ChosenHotkey) and (A_Index != RowNumber)) {
				MsgBox("Hotkey already defined. Cannot submit edit.")
				Return
			}
		}
		
		; check if keybind already exists elsewhere (that isn't itself)
		If (StratagemKeybindExists and LvKeybinds.GetText(RowNumber, 1) != ChosenHotkey) {
			MsgBox("Keybind already set for another stratagem.")
			Return
		}
		Else If (LoadoutKeybindExists) {
			MsgBox("Keybind already set for a loadout.")
			Return
		}
		
		; remove old keybind from global so it won't export if saved
		; and disable old hotkey as well
		OldKeybind := LvKeybinds.GetText(RowNumber)
		Stratagem_Keybinds.Delete(OldKeybind)
		Hotkey(OldKeybind,NoAction,"Off")
		
		LvKeybinds.Modify(RowNumber,,ChosenHotkey,Stratagem)
	}
	
	Stratagem_Keybinds[ChosenHotkey] := Stratagem
	SetupStratagemHotkey(ChosenHotkey, Stratagem, IsDebugging := False)
}

;======================================================================
;; Stratagem Editing Gui
;======================================================================

StratagemEditGui := Gui(,"Edit Stratagem Keychords")
StratagemEditGui.Opt("+Owner" MainGui.Hwnd)
StratagemEditGui.Add("Text", "xm", "RowNumber: ")
StratagemEditGui.Add("Edit", "yp x100 w200 vRowNumber", 0)
StratagemEditGui["RowNumber"].Enabled := 0
StratagemEditGui.Add("Text", "xm", "Name: ")
StratagemEditGui.Add("Edit", "yp x100 w200 vName", "None")
StratagemEditGui.Add("Text", "xm", "Keychords:")
StratagemEditGui.Add("Edit", "yp x100 w200 vKeychords", "")
StratagemEditGui.Add("Button", "Default", "Register").OnEvent("Click", RegisterStratagem.Bind("StratagemEditGui"))

ShowStratagemEditGui(KeyVals) {
	StratagemEditGui["RowNumber"].Value := KeyVals["RowNumber"]
	StratagemEditGui["Name"].Value := KeyVals["Name"]
	If (KeyVals["RowNumber"] = 0)
		KeyChords := ''
	Else
		Keychords := ConvertArrayToDelimitedString(Stratagems_Keychords[KeyVals["Name"]])
	StratagemEditGui["Keychords"].Value := Keychords
		
	StratagemEditGui.Show(GetEditGuiSpawnPosition())
	Return
}

RegisterStratagem(ControlName, *) {
	Saved := %ControlName%.Submit(False) or 0
	RowNumber := Integer(Saved.RowNumber)
	Name := Trim(StrUpper(Saved.Name))
	Keychords := Trim(StrUpper(Saved.Keychords))
	
	If (Name = '' or Name = "None" or Keychords = '') {
		MsgBox("Error saving. Invalid Name/Keychord combination.")
		Return
	}
	
	; if this is a new record
	If (RowNumber = 0) {
		If (ArrayHasValue(GetStratagemNames(), Name)) {
			MsgBox("Stratagem already defined, use the edit option instead.")
			Return
		}
		LvStratagems.Add(,Name,Keychords)
	}
	; if this is editing existing
	Else If (RowNumber > 0) {
		Loop LvStratagems.GetCount() {
			LvRowName := LvStratagems.GetText(A_Index)
			If ((LvRowName = Name) and (A_Index != RowNumber)) {
				MsgBox("Stratagem already defined, use another.")
				Return
			}
		}
		LvStratagems.Modify(RowNumber,,Name,Keychords)
	}
	
	Stratagems_Keychords[Name] := StrSplit(Keychords, ',')
}

