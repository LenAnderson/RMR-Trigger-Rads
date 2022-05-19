Scriptname LenARMT_Rads:LenARMT_Rads_Main extends Quest
{Main quest script}


;-----------------------------------------------------------------------------------------------------
; general properties
Group Properties
	Actor Property Player Auto Const
	{reference to the player}
	ActorValue Property Rads Auto Const
	{rads actor value to get rads}
EndGroup


;-----------------------------------------------------------------------------------------------------
; enums

Group EnumTimer
	int Property ETimerUpdateValue = 1 Auto Const
	{timer for checking current rads and updating current value}
EndGroup


;-----------------------------------------------------------------------------------------------------
; variables

; RMR API
LenARM:LenARM_API RMR


; MCM: name of the trigger to register with RMR
string TriggerName

; MCM: seconds between checking rads
float UpdateDelay


; current rads
float CurrentValue

; whether RMR is currently running
bool RmrIsRunning = false

; whether the mod is currently shutting down
bool IsShuttingDown = false

; whether the trigger has been successfully registered with RMR
bool IsRegistered = false


;-----------------------------------------------------------------------------------------------------
; versioning

; version the mod was last run with
string Version

;
; For some reason doc comments from the first function after variable declarations are not picked up.
;
Function DummyFunction()
EndFunction

;
; Get the current version of this mod.
;
string Function GetVersion()
	return "0.0.2"; Sat May 14 17:53:29 CEST 2022
EndFunction




;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
; event listeners


;-----------------------------------------------------------------------------------------------------
; game events

Event OnQuestInit()
	RegisterForExternalEvent("OnMCMSettingChange|RMR_Rads", "OnMCMSettingChange")
	RegisterForRemoteEvent(Player, "OnPlayerLoadGame")
	Startup()
EndEvent

Event OnQuestShutdown()
	UnregisterForExternalEvent("OnMCMSettingChange|RMR_Rads")
	UnregisterForRemoteEvent(Player, "OnPlayerLoadGame")
	Shutdown()
EndEvent


Event Actor.OnPlayerLoadGame(Actor akSender)
	PerformUpdateIfNecessary()
	If (!RMR)
		Startup()
	EndIf
EndEvent


Event OnTimer(int timerId)
	If (timerId == ETimerUpdateValue)
		UpdateValue()
	EndIf
EndEvent


;-----------------------------------------------------------------------------------------------------
; MCM events

Function OnMCMSettingChange(string modName, string id)
	If (id == "sTriggerName:General")
		If (UpdateTriggerName())
			UpdateValue(true)
		EndIf
	EndIf
EndFunction


;-----------------------------------------------------------------------------------------------------
; RMR events

Event LenARM:LenARM_API.OnStartup(LenARM:LenARM_API akSender, Var[] akArgs)
	RmrIsRunning = true
	If (UpdateTriggerName())
		UpdateValue(true)
	EndIf
EndEvent

Event LenARM:LenARM_API.OnShutdown(LenARM:LenARM_API akSender, Var[] akArgs)
	RmrIsRunning = false
	IsRegistered = false
	CancelTimer(ETimerUpdateValue)
EndEvent




;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
; startup and shutdown

;
; Start the mod.
;
Function Startup()
	; try to get reference to RMR API
	RMR = Game.GetFormFromFile(0x4C50, "LenA_RadMorphing.esp") as LenARM:LenARM_API
	If (!RMR)
		Debug.Notification("[RMR_Rads] " + "RMR API was not found")
		Debug.Trace("[RMR_Rads] " + "RMR API was not found")
	Else
		Debug.Trace("[RMR_Rads] " + "RMR API was found.")

		; listen to RMR events (startup and shutdown)
		RegisterForCustomEvent(RMR, "OnStartup")
		RegisterForCustomEvent(RMR, "OnShutdown")

		; load MCM values
		TriggerName = MCM.GetModSettingString("RMR_Rads", "sTriggerName:General")
		UpdateDelay = MCM.GetModSettingFloat("RMR_Rads", "fUpdateDelay:General")

		; check whether RMR is running and start the timer
		RmrIsRunning = RMR.IsRunning()
		If (UpdateTriggerName())
			UpdateValue(true)
		EndIf
	EndIf
EndFunction


;
; Stop the mod.
;
Function Shutdown()
	IsShuttingDown = true
	IsRegistered = false
	CancelTimer(ETimerUpdateValue)
	If (RMR)
		UnregisterForCustomEvent(RMR, "OnStartup")
		UnregisterForCustomEvent(RMR, "OnShutdown")
		RMR.UnregisterTrigger(TriggerName)
		RMR = None
	EndIf
	IsShuttingDown = false
EndFunction


;
; Check if a new version has been installed and restart the mod if necessary.
;
Function PerformUpdateIfNecessary()
	If (Version == "")
		; mod has never run before
		Version = GetVersion()
	ElseIf (Version != GetVersion())
		Shutdown()
		Startup()
		Version = GetVersion()
	EndIf
EndFunction




;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
; mod logic

;
; Update the current value (i.e. check player's rads) and restart the timer.
; If @forced is true, RMR will be notified even if the value has not changed.
;
Function UpdateValue(bool forced=false)
	If (RmrIsRunning && IsRegistered)
		Debug.Trace("[RMR_Rads] " + "UpdateValue")
		float newValue = Player.GetValue(Rads) / 1000.0
		If (forced || newValue != CurrentValue)
			Debug.Trace("[RMR_Rads] " + "  " + CurrentValue + "  -->  " + newValue)
			CurrentValue = newValue
			RMR.UpdateTrigger(TriggerName, CurrentValue)
		EndIf
		If (RmrIsRunning && !IsShuttingDown)
			StartTimer(UpdateDelay, ETimerUpdateValue)
		EndIf
	EndIf
EndFunction


;
; Update the trigger name with the current value from MCM.
; Unregister the old and register the new name with RMR.
;
bool Function UpdateTriggerName()
	Debug.Trace("[RMR_Rads] " + "UpdateTriggerName")
	If (RMR)
		If (IsRegistered)
			RMR.UnregisterTrigger(TriggerName)
		EndIf
		TriggerName = MCM.GetModSettingString("RMR_Rads", "sTriggerName:General")
		IsRegistered = RMR.RegisterTrigger(TriggerName)
		If (!IsRegistered)
			Debug.MessageBox("RMR: Rads - The trigger name \"" + TriggerName + "\" is already in use. Please change the name in the MCM for this mod.")
		EndIf
		return IsRegistered
	Else
		return false
	EndIf
EndFunction