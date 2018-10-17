
SetMouseDelay 50
SetKeyDelay 50
global Green = 0x31C07F

waitForGreen()
{
	Loop {
		Sleep, 100
		PixelGetColor, colorToCheck, %carreerX%, %carreerY%
		;MsgBox % "Green =" . Green . " Pixel = " . colorToCheck
	} Until %colorToCheck% == %Green%
}

quitGame()
{
	ControlSend, , {Esc}, %targetWin%
	Click, %quitGameX%, %quitGameY%
	Click, %dontSaveX%, %dontSaveY%
}

startGame(gameNum)
{
	WinActivate, %targetWin% ahk_class SDL_app
  Sleep, 200
	Click, %carreerX%, %carreerY%
	Sleep, 200
	SetKeyDelay, 200
	Send, {Right %gameNum% - 1} {Enter 2}
}

