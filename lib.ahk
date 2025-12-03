#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

;======================================================================
;; Globals (super globals explicitly declared)
;======================================================================

Global DefaultConfig_Dir := '.\default-configs'
Global Config_Dir := '.\configs'

Global DefaultConfig_FilePath := DefaultConfig_Dir '\config.ini'
Global DefaultLoadouts_FilePath := DefaultConfig_Dir '\loadouts.ini'
Global DefaultStratagems_FilePath := DefaultConfig_Dir '\stratagems.ini'

Global Config_FilePath := Config_Dir '\config.ini'
Global Loadouts_FilePath := Config_Dir '\loadouts.ini'
Global Stratagems_FilePath := Config_Dir '\stratagems.ini'

; check for config dir, if none then copy defaults
try {
	If not DirExist(Config_Dir) {
		DirCreate(Config_Dir)
		FileCopy(DefaultConfig_FilePath, Config_FilePath)
		FileCopy(DefaultLoadouts_FilePath, Loadouts_FilePath)
		FileCopy(DefaultStratagems_FilePath, Stratagems_FilePath)
	}
}
catch as err {
	MsgBox("Error: " err.Message)
	Exit
}

; Cannot create super globals at runtime, workaround is using a global object
Global Config := Map()
For Key, Value in IniSectionToMap(IniRead(Config_FilePath, "Globals")) {
	TKey := Trim(Key)
	Config[TKey] := Trim(Value)
}

Global Loadouts := GetLoadoutObjs(Loadouts_FilePath)
Global Stratagems_Keychords := IniSectionToMap(IniRead(Stratagems_FilePath, "StratagemsAndKeychords"), "StrUpper")
Global Stratagem_Keybinds := IniStratagemKeybindsToMap(IniRead(Stratagems_FilePath, "StratagemKeybinds"))

;======================================================================
;; Ini
;======================================================================

GetLoadoutObjs(IniFile) {
	; One paramter to get list of section Names
	; The intended output is an array of Objects with the following properties:
	; Obj.Name := String
	; Obj.ChosenHotkey := String
	; Obj.Route := Array[String]
	; Obj.Stratagems := Array[String]
	LoadoutsFromSections := StrSplit(IniRead(IniFile), '`n')
	MyLoadouts := Array()
	Loop LoadoutsFromSections.Length {
		Obj := {}
		Obj.Name := LoadoutsFromSections[A_Index]
		LoadoutSectionMap := IniSectionToMap(IniRead(Loadouts_FilePath, LoadoutsFromSections[A_Index]))
		
		Obj.ChosenHotkey := LoadoutSectionMap["ChosenHotkey"]
		StrTemp := StrUpper(ConvertArrayToDelimitedString(LoadoutSectionMap["Route"]))
		Obj.Route := ConvertDelimitedStringToArray(StrTemp)
		StrTemp := StrUpper(ConvertArrayToDelimitedString(LoadoutSectionMap["Stratagems"]))
		Obj.Stratagems := ConvertDelimitedStringToArray(StrTemp)

		MyLoadouts.Push(Obj)
	}
	Return MyLoadouts
}

IniSectionToMap(IniFile, StringManipulator := "") {
	; This function requires IniRead section information
	; So call should have two parms, ex: IniRead("config.ini", "StratagemsAndKeychords")
	; StringManipulator values refer to StrLower / StrUpper / StrTitle
	MyMap := Map()
	For Each, Line in StrSplit(IniFile, '`n') {
		Switch StringManipulator {
			Case "StrLower":
				Part := StrSplit(Line, '='), Key := StrLower(Trim(Part[1])), Value := StrLower(Trim(Part[2]))
			Case "StrUpper":
				Part := StrSplit(Line, '='), Key := StrUpper(Trim(Part[1])), Value := StrUpper(Trim(Part[2]))
			Case "StrTitle":
				Part := StrSplit(Line, '='), Key := StrTitle(Trim(Part[1])), Value := StrTitle(Trim(Part[2]))
			Default:
				Part := StrSplit(Line, '='), Key := Trim(Part[1]), Value := Trim(Part[2])
		}
		MyMap[Key] := InStr(Value, ',') != 0 ? StrSplit(Value, ',') : Value
	}
	Return MyMap
}

IniStratagemKeybindsToMap(IniFile) {
	; Meant to handle the following nested list within ini
	; ex: 3=Numpad2,RESUPPLY
	; expect output is a Map("Numpad2", "RESUPPLY")
	MyMap := Map()
	For Each, Line in StrSplit(IniFile, '`n') {
		Part := StrSplit(Line, '='), LeftOfEquals := Trim(Part[1]), RightOfEquals := Trim(Part[2])
		KeybindAndStratagem := StrSplit(RightOfEquals, ',')
		MyMap[KeybindAndStratagem[1]] := StrUpper(KeybindAndStratagem[2])
	}
	Return MyMap
}

GlobalsToIni(FilePath := Config_FilePath) {
	For Name, Value in Config {
		IniWrite(Value, FilePath, "Globals", Name)
	}
	Return
}

LoadoutsToIni(FilePath := Loadouts_FilePath) {
	; easiest to delete the loadouts.ini file as renamed loadouts will stay around otherwise
	FileDelete(Filepath)
	
	Loop Loadouts.Length {
		CurrentLoadout := Loadouts[A_Index]
		
		; Prep the Route for output to string
		Loop CurrentLoadout.Route.Length {
			If (A_Index != CurrentLoadout.Route.Length) {
				StrRoute .= CurrentLoadout.Route[A_Index] . ","
			}
			Else {
				StrRoute .= CurrentLoadout.Route[A_Index]
			}
		}
		
		; Prep stratagems for output to string
		Loop CurrentLoadout.Stratagems.Length {
			If (A_Index != CurrentLoadout.Stratagems.Length) {
				StrStratagems .= CurrentLoadout.Stratagems[A_Index] . ","
			}
			Else {
				StrStratagems .= CurrentLoadout.Stratagems[A_Index]
			}
		}
		
		IniWrite(CurrentLoadout.ChosenHotkey, Filepath, CurrentLoadout.Name, "ChosenHotkey")
		IniWrite(StrRoute, Filepath, CurrentLoadout.Name, "Route")
		IniWrite(StrStratagems, Filepath, CurrentLoadout.Name, "Stratagems")
		
		; clear these so they won't append between loops
		StrRoute := ''
		StrStratagems := ''
	}
	Return
}

KeybindsToIni(FilePath := Stratagems_FilePath) {
	Counter := 0
	IniDelete(FilePath, "StratagemKeybinds")
	For Keybind, Stratagem in Stratagem_Keybinds {
		Value := Keybind . ',' . Stratagem
		IniWrite(Value, FilePath, "StratagemKeybinds", Counter)
		Counter++
	}
	Return
}

KeychordsToIni(FilePath := Stratagems_FilePath) {
	IniDelete(FilePath, "StratagemsAndKeychords")
	For StratagemName, Keychords in Stratagems_Keychords {
		Loop Keychords.Length {
			If (A_Index != Keychords.Length) {
				Chords .= Keychords[A_Index] . ","
			}
			Else {
				Chords .= Keychords[A_Index]
			}
		}
		IniWrite(Chords, FilePath, 'StratagemsAndKeychords', StratagemName)
		Chords := '' ; need to clear the variable or it keeps the previous appended
	}
	Return
}

SaveAllSettingsToIni() {
	GlobalsToIni()
	LoadoutsToIni()
	KeybindsToIni()
	KeychordsToIni()
	MsgBox("All Settings Saved.")
	Return
}

;======================================================================
;; Keying
;======================================================================

KeyPressSimple(KeyName, DownSleep := Config["Sleep_Default"], UpSleep := Config["Sleep_Default"], IsBlind := True) {
	StrVal := (IsBlind) ? "{Blind}{" . KeyName : "{" . KeyName . " "
	Send(StrVal . ' Down}')
	Sleep DownSleep
	Send(StrVal . ' Up}')
	Sleep UpSleep
	Return
}

KL() {
	KeyPressSimple("Left")
	Return
}

KR() {
	KeyPressSimple("Right")
	Return
}

KU() {
	KeyPressSimple("Up")
	Return
}

KD() {
	KeyPressSimple("Down")
	Return
}

;======================================================================
;; Stratagems
;======================================================================

GetStratagemNames() {
	Return GetMapKeys(Stratagems_Keychords)
}

SetupStratagemKeybinds(IsDebugging := False) {
	For Key, Value in Stratagem_Keybinds {
		StratagemHotkeys := Key
		StratagemName := Value
		SetupStratagemHotkey(StratagemHotkeys, StratagemName, IsDebugging)
	}
}

SetupStratagemHotkey(StratagemHotkeys, StratagemName, IsDebugging := False) {
	
	If (IsDebugging) {
		Hotkey(StratagemHotkeys, (ThisHotkey) => DebugStratagem(StratagemName), "On")
	}
	Else {
		HotIfWinActive("HELLDIVERS™ 2")
		Hotkey(StratagemHotkeys, (ThisHotkey) => CallStratagem(StratagemName), "On")
		HotIfWinActive
	}
}

CallStratagem(Stratagem)  {
	Send "{LCtrl Down}"
	Sleep Config["Sleep_Default"]
	Loop Stratagems_Keychords[Stratagem].Length {
		%Stratagems_Keychords[Stratagem][A_Index]%()
	}
	Send "{LCtrl Up}"
	Return
}

DebugStratagem(Stratagem)  {
	Loop Stratagems_Keychords[Stratagem].Length {
		MsgBox(Stratagems_Keychords[Stratagem][A_Index])
	}
	Return
}

;======================================================================
;; Loadout Selection
;======================================================================

SetupLoadoutKeybinds(IsDebugging := False) {
	Loop Loadouts.Length {
		LoadoutHotkeys := Loadouts[A_Index].ChosenHotkey
		SetupLoadoutHotkey(LoadoutHotkeys, A_Index, IsDebugging)
	}
}

SetupLoadoutHotkey(LoadoutHotkeys, LoadoutIndex, IsDebugging := False) {
	If (IsDebugging) {
		Hotkey(LoadoutHotkeys, (ThisHotkey) => DebugLoadout(LoadoutIndex), "On")
	}
	Else {
		HotIfWinActive("HELLDIVERS™ 2")
		Hotkey(LoadoutHotkeys, (ThisHotkey) => SelectLoadout(LoadoutIndex), "On")
		HotIfWinActive
	}
}

GetLoadoutObjIndexByName(Name) {
	Loop Loadouts.Length {
		If (Loadouts[A_Index].Name = Name)
			Return A_Index
	}
	Return 0
}

SelectLoadout(LoadoutIndex) {
	IsFirstSpacebar := True
	Loop Loadouts[LoadoutIndex].Route.Length 	{
		Action := SubStr(Loadouts[LoadoutIndex].Route[A_Index], 1, 1)
		ActionCount := 0
		If (Action != "K") {
			ActionCount := Integer(SubStr(Loadouts[LoadoutIndex].Route[A_Index], 2))
		}

		Switch Action {
			Case "K":
				If (IsFirstSpacebar) {
					KeyPressSimple("Space", Config["Sleep_Loadout_Stage1"], Config["Sleep_Loadout_SpacebarLong"])
					IsFirstSpacebar := False
				}
				Else {
					KeyPressSimple("Space", Config["Sleep_Loadout_Stage1"], Config["Sleep_Loadout_Spacebar_Stage2"])
				}
			Case "D":
				Loop ActionCount {
					KeyPressSimple("Down", Config["Sleep_Loadout_Stage1"], Config["Sleep_Loadout_Stage2"])
				}
			Case "R":
				Loop ActionCount {
					KeyPressSimple("Right", Config["Sleep_Loadout_Stage1"], Config["Sleep_Loadout_Stage2"])
				}
			Case "U":
				Loop ActionCount {
					KeyPressSimple("Up", Config["Sleep_Loadout_Stage1"], Config["Sleep_Loadout_Stage2"])
				}
			Case "L":
				Loop ActionCount {
					KeyPressSimple("Left", Config["Sleep_Loadout_Stage1"], Config["Sleep_Loadout_Stage2"])
				}
		}
	}
	Return
}

DebugLoadout(LoadoutIndex) {
	MsgBox("Loadout Index: " . LoadoutIndex . '`n' . "Loadout Name: " . Loadouts[LoadoutIndex].Name)
	Loop Loadouts[LoadoutIndex].Route.Length {
		MsgBox(Loadouts[LoadoutIndex].Route[A_Index])
	}
	Return
}

;======================================================================
;; Miscellaneous 
;======================================================================

GetMapKeys(MyMap) {
	; shorthand - use only one var to retrieve only keys
	MyArray := Array()
	For MyKey in MyMap {
		MyArray.Push(MyKey)
	}
	Return MyArray
}

ArrayHasValue(TheArray, SearchTarget) {
    If (not IsObject(TheArray) or TheArray.Length = 0)
        Return False
    For Index, Value in TheArray
        If (Value = SearchTarget)
            Return True
    Return False
}

GetValueIndexFromArray(MyArray, SearchValue) {
	Loop MyArray.Length {
		If (SearchValue = MyArray[A_Index]) {
			Return Integer(A_Index)
		}
	}
	Return 0
}

ConvertArrayToDelimitedString(ArgsArray, Delim := ',') {
	OutputString := ""
	For Index, Value In ArgsArray {
	   OutputString .= "," . Value
	}
	OutputString := Trim(OutputString, ",")
	Return OutputString
}

ConvertDelimitedStringToArray(ArgStr, Delim := ',') {
	; alternative to StrSplit()
	OutputArray := Array()
	Loop Parse ArgStr, Delim {
		OutputArray.Push(A_LoopField)
	}
	Return OutputArray
}

GetListviewRowValues(LvName, LvFields, RowNumber) {
	; LvName := String name we will dereference
	; LvFields := Array of column names to grab
	Lv := %LvName%
	KeyVals := Map()
	If RowNumber = 0
		KeyVals["RowNumber"] := 0
	Else
		KeyVals["RowNumber"] := Integer(RowNumber)
	
	Loop LvFields.Length {
		If (RowNumber = 0)
			KeyVals[LvFields[A_Index]] := ''
		Else
			KeyVals[LvFields[A_Index]] := Lv.GetText(RowNumber, A_Index)
	}
	Return KeyVals
}
