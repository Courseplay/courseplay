
CpGuiUtil = {}

---@param settingList SettingList
function CpGuiUtil.bindSetting(settingList, guiElement, infoText)
	---@type SettingList
	local setting = settingList[guiElement.name] or settingList[guiElement.id]
	if setting and setting.getGuiElement then
		setting:setGuiElement(guiElement)
		guiElement.labelElement.text = setting:getLabel()
		guiElement.toolTipText = setting:getToolTip()
		guiElement:setTexts(setting:getGuiElementTexts())
		guiElement:setState(setting:getGuiElementState())
		guiElement:setDisabled(setting:isDisabled())
	else
		courseplay.info(infoText or 'bindSetting' .. ': can\'t find setting %s', guiElement.name)
	end
end 