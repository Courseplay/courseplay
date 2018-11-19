
SetMouseDelay 50
SetKeyDelay 500
global Green := 0x31C07F
global targetWin := "Farming Simulator 19"


;========================================================================
;
; WaitPixelColor
;   https://bit.ly/R7gT8a | https://github.com/MasterFocus/AutoHotkey
;
; Waits until a pixel is a certain color (w/ optional timeout)
;
; Created by MasterFocus
;   https://git.io/master | http://masterfocus.ahk4.net
;
; Last Update: 2012-09-06 09:00 BRT
;
;========================================================================

WaitPixelColor(p_DesiredColor,p_PosX,p_PosY,p_TimeOut=0,p_GetMode="",p_ReturnColor=0) {
    l_Start := A_TickCount
    Loop {
        PixelGetColor, l_OutputColor, %p_PosX%, %p_PosY%, %p_GetMode%
        If ( ErrorLevel )
            Return ( p_ReturnColor ? l_OutputColor : 1 )
        If ( l_OutputColor = p_DesiredColor )
            Return ( p_ReturnColor ? l_OutputColor : 0 )
        If ( p_TimeOut ) && ( A_TickCount - l_Start >= p_TimeOut )
            Return ( p_ReturnColor ? l_OutputColor : 2 )
    }
}

quitGame()
{
	WinActivate, %targetWin% ahk_class SDL_app
  Send, {Escape}
  Click, %gameMenuX%, %gameMenuY% Left, Down
  Click, %gameMenuX%, %gameMenuY% Left, Up
  Send, {Backspace}
  Send, {Enter}
}

startGame(gameNum)
{
	rights := gameNum - 1
	WinActivate, %targetWin% ahk_class SDL_app
  Send, {Enter}
	Send, {Right %rights% } {Enter 2}
	WaitPixelColor(0xffffff, startButtonX, startButtonY, 40000)
  Send, {Enter}
}

