---@field HudUtil table
HudUtil = {}
local function round(num)
	return math.floor(num + 0.5);
end

---Converts pixel to normals.
---@param px number px are in targetSize for 1920x1080
---@param dimension string x or y 
---@param fullPixel boolean still needed ???
function HudUtil.pxToNormal(px, dimension, fullPixel)
	local ret
	if dimension == 'x' then
		ret = (px / 1920) * courseplay.hud.sizeRatio * courseplay.hud.uiScale * g_aspectScaleX
	else
		ret = (px / 1080) * courseplay.hud.sizeRatio * courseplay.hud.uiScale * g_aspectScaleY
	end
	if fullPixel == nil or fullPixel then
		ret = HudUtil.getFullPx(ret, dimension)
	end

	return ret
end

---No idea what this function does ???.
---@param n number no idea ???
---@param dimension string x or y 
function HudUtil.getFullPx(n, dimension)
	if dimension == 'x' then
		return round(n * g_screenWidth) / g_screenWidth
	else
		return round(n * g_screenHeight) / g_screenHeight
	end
end

function HudUtil.getPxToNormalConstant(widthPx, heightPx)
	return widthPx/g_screenWidth, heightPx/g_screenHeight
end

---Converts rgb values to normal values (0..1)
---@param r number red
---@param g number green
---@param b number blue
---@param a number alpha (optional)
function HudUtil.rgbToNormal(r, g, b, a)
	if a then
		return { r/255, g/255, b/255, a }
	end

	return { r/255, g/255, b/255 }
end

---Sets font size, text color, text alignment and text boldness.
---@param color table text color, can also be a reference string index for courseplay.hud.colors[].
---@param fontBold boolean should the text be bold ?
---@param align string text alignment, should be improved!!
function HudUtil.setFontSettings(color, fontBold, align)
	if color ~= nil then
		local prmType = type(color);
		if prmType == 'string' and courseplay.hud.colors[color] ~= nil then
			setTextColor(unpack(courseplay.hud.colors[color]));
		elseif prmType == 'table' then
			setTextColor(unpack(color));
		end;
	else --Backup
		setTextColor(unpack(courseplay.hud.colors.white));
	end;

	if fontBold ~= nil then
		setTextBold(fontBold);
	else
		setTextBold(false);
	end;

	if align ~= nil then
		setTextAlignment(RenderText['ALIGN_' .. align:upper()]);
	end;
end;

---Sets uvs to an overlay.
---@param overlay table giants overlay object.
---@param UVs table cp uvs: leftX, bottomY, rightX, topY
---@param textureSizeX number image file x size
---@param textureSizeY number image file y size
function HudUtil.setOverlayUVsPx(overlay, UVs, textureSizeX, textureSizeY)
	if overlay.overlayId and overlay.currentUVs == nil or overlay.currentUVs ~= UVs then
		setOverlayUVs(overlay.overlayId, unpack(HudUtil.getUvs(UVs, textureSizeX, textureSizeY)));
		overlay.currentUVs = UVs;
	end;
end;

---Gets uvs for an overlay.
---@param UVs table cp uvs: leftX, bottomY, rightX, topY
---@param textureSizeX number image file x size
---@param textureSizeY number image file y size
function HudUtil.getUvs(UVs, textureSizeX, textureSizeY)
	local leftX, bottomY, rightX, topY = unpack(UVs);

	local fromTop = false;
	if topY < bottomY then
		fromTop = true;
	end;
	local leftXNormal = leftX / textureSizeX;
	local rightXNormal = rightX / textureSizeX;
	local bottomYNormal = bottomY / textureSizeY;
	local topYNormal = topY / textureSizeY;
	if fromTop then
		bottomYNormal = 1 - bottomYNormal;
		topYNormal = 1 - topYNormal;
	end
	return {leftXNormal,bottomYNormal, leftXNormal,topYNormal, rightXNormal,bottomYNormal, rightXNormal,topYNormal}
end


