#Include laptop.ahk
#Include common.ahk

WinActivate, %targetWin% ahk_class SDL_app
quitGame()
Sleep 2000
startGame(2)

