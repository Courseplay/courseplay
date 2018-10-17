; This script was created using Pulover's Macro Creator
; www.macrocreator.com

#NoEnv
SetWorkingDir %A_ScriptDir%
CoordMode, Mouse, Window
SendMode Input
#SingleInstance Force
SetTitleMatchMode 2
#WinActivateForce
SetControlDelay 1
SetWinDelay 0
SetKeyDelay -1
SetMouseDelay -1
SetBatchLines -1


;F4::
;Macro1:
targetWin = "Farming Simulator 17"
WinActivate, "%targetWin%" ahk_class SDL_app
ControlClick, 810, 395, %targetWin%
Sleep, 858
ControlSend, {Right}, %targetWin%
Sleep, 172
ControlSend, {Right}, %targetWin%
Sleep, 140
ControlSend, {Right}, %targetWin%
Sleep, 172
ControlSend, {Right}, %targetWin%
Sleep, 140
ControlSend, {Right}, %targetWin%
Sleep, 172
ControlSend, {Right}, %targetWin%
Sleep, 156
ControlSend, {Right}, %targetWin%
Sleep, 172
ControlSend, {Right}, %targetWin%
Sleep, 312
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 406
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 202
ControlSend, {Right}, %targetWin%
Sleep, 905s
ControlClick, 1367, 987, %targetWin%
Sleep, 1000 
ControlClick, 1367, 987, %targetWin%
Sleep, 24000 
ControlClick, 1367, 987, %targetWin%
Sleep, 4000 
ControlSend, {Tab}, %targetWin%
Sleep, 265
ControlSend, {Tab}, %targetWin%
Sleep, 187
ControlSend, {Tab}, %targetWin%
Return

