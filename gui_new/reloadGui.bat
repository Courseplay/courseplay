@echo off
set outfile=gui_new/reloadGui.xml
echo ^<code^> > %outfile%
echo ^<![CDATA[ >> %outfile%
type gui_new\GuiManager.lua >> %outfile%
@echo, >> %outfile%
type gui_new\FakeGui.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Gui.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\GuiElement.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Borders.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Button.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\FlowLayout.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\GuiScreen.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\IngameMap.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Input.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Overlay.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Page.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\PageSelector.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Slider.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Table.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\TableSort.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\GuiMover.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\Text.lua >> %outfile%
@echo, >> %outfile%
type gui_new\elements\GuiPage.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Main.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\CourseManager.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_drivers.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_driversSearch.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_settingsFilling.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_settingsField.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_settingsVehicle.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_shovel.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_siloCompaction.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_speed.lua >> %outfile%
@echo, >> %outfile%
type gui_new\screens\Page_steering.lua >> %outfile%
@echo, >> %outfile%
echo ]]^> >> %outfile%
echo ^</code^> >> %outfile%