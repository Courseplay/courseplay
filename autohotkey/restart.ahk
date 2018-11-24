#Include coords1920x1080.ahk
#Include common.ahk

WinActivate, %targetWin% ahk_class SDL_app
quitGame()
Sleep 6000
startGame(2)

