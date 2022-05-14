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

; whether the mod is currently running
bool IsRunning = false

; whether the mod is currently shutting down
bool IsShuttingDown = false


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
	; D.Log("OnQuestInit")
	RegisterForExternalEvent("OnMCMSettingChange|RMR_Rads", "OnMCMSettingChange")
	RegisterForRemoteEvent(Player, "OnPlayerLoadGame")
	Startup()
EndEvent

Event OnQuestShutdown()
	; D.Log("OnQuestShutdown")
	UnregisterForExternalEvent("OnMCMSettingChange|RMR_Rads")
	UnregisterForRemoteEvent(Player, "OnPlayerLoadGame")
	Shutdown()
EndEvent


Event Actor.OnPlayerLoadGame(Actor akSender)
	PerformUpdateIfNecessary()
	If (!IsRunning)
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
	; D.Log("OnMCMSettingChange: " + modName + "; " + id)
EndFunction


;-----------------------------------------------------------------------------------------------------
; RMR events

Event LenARM:LenARM_API.OnStartup(LenARM:LenARM_API akSender, Var[] akArgs)
	RMR.RegisterTrigger(TriggerName)
	RMR.UpdateTrigger(TriggerName, CurrentValue)
	IsRunning = true
	StartTimer(UpdateDelay, ETimerUpdateValue)
EndEvent

Event LenARM:LenARM_API.OnShutdown(LenARM:LenARM_API akSender, Var[] akArgs)
	IsRunning = false
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

		;TODO check if RMR is running
		IsRunning = true
	EndIf
EndFunction


;
; Stop the mod.
;
Function Shutdown()
	IsShuttingDown = true
	IsRunning = false
	CancelTimer(ETimerUpdateValue)
	If (RMR)
		UnregisterForCustomEvent(RMR, "OnStartup")
		UnregisterForCustomEvent(RMR, "OnShutdown")
		RMR = None
	EndIf
	IsShuttingDown = false
EndFunction


;
; check if a new version has been installed and restart the mod if necessary
;
Function PerformUpdateIfNecessary()
	If (Version == "")
		Version = GetVersion()
	ElseIf (Version != GetVersion())
		;TODO perform update
		Shutdown()
		Startup()
		Version = GetVersion()
	EndIf
EndFunction




;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------
; mod logic

Function UpdateValue()
	Debug.Trace("[RMR_Rads] " + "UpdateValue")
	float newValue = Player.GetValue(Rads) / 1000.0
	If (newValue != CurrentValue)
		Debug.Trace("[RMR_Rads] " + "  " + CurrentValue + "  -->  " + newValue)
		CurrentValue = newValue
		RMR.UpdateTrigger(TriggerName, CurrentValue)
	EndIf
	If (IsRunning && !IsShuttingDown)
		StartTimer(UpdateDelay, ETimerUpdateValue)
	EndIf
EndFunction