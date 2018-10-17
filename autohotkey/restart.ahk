global targetWin = "Farming Simulator 17"

#Include laptop.ahk
#Include common.ahk
WinActivate, %targetWin% ahk_class SDL_app
quitGame()
Sleep 12000
startGame(7)

