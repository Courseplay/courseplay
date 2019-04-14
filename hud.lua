courseplay.hud = {};

local abs, ceil, floor, max = math.abs, math.ceil, math.floor, math.max;
local function round(num)
	return floor(num + 0.5);
end

courseplay.hud.sizeRatio = 1;
courseplay.hud.uiScale = g_gameSettings:getValue("uiScale");

-- px are in targetSize for 1920x1080
function courseplay.hud:pxToNormal(px, dimension, fullPixel)
	local ret;
	if dimension == 'x' then
		ret = (px / 1920) * courseplay.hud.sizeRatio * courseplay.hud.uiScale * g_aspectScaleX;
	else
		ret = (px / 1080) * courseplay.hud.sizeRatio * courseplay.hud.uiScale * g_aspectScaleY;
	end;
	if fullPixel == nil or fullPixel then
		ret = self:getFullPx(ret, dimension);
	end;

	return ret;
end;

function courseplay.hud:getFullPx(n, dimension)
	if dimension == 'x' then
		return round(n * g_screenWidth) / g_screenWidth;
	else
		return round(n * g_screenHeight) / g_screenHeight;
	end;
end;

function courseplay.hud:getPxToNormalConstant(widthPx, heightPx)
	return widthPx/g_screenWidth, heightPx/g_screenHeight;
end;

-- 800x600:   g_cM vehicleHudPosX=0.826458, vehicleHudPosY=0.020833, vehicleBaseHudHeight=0.027708, vehicleHudScale=0.700000
-- 1024x768:  g_cM vehicleHudPosX=0.826458, vehicleHudPosY=0.020833, vehicleBaseHudHeight=0.027708, vehicleHudScale=0.700000
-- 1280x800:  g_cM vehicleHudPosX=0.826458, vehicleHudPosY=0.025000, vehicleBaseHudHeight=0.033250, vehicleHudScale=0.700000
-- 1680x1050: g_cM vehicleHudPosX=0.826458, vehicleHudPosY=0.025000, vehicleBaseHudHeight=0.033250, vehicleHudScale=0.700000
-- 1920x1080: g_cM vehicleHudPosX=0.826458, vehicleHudPosY=0.027778, vehicleBaseHudHeight=0.036944, vehicleHudScale=0.700000


-- ####################################################################################################
-- SETUP
courseplay.hud.basePosX = 0.5 - courseplay.hud:pxToNormal(630 / 2, 'x'); -- Center Screen - half hud width
courseplay.hud.basePosY = courseplay.hud:pxToNormal(32, 'y');

function courseplay.hud:setup()
	-- self = courseplay.hud

	print('## Courseplay: setting up hud');

	self.PAGE_COMBINE_CONTROLS	= 0;
	self.PAGE_CP_CONTROL		= 1;
	self.PAGE_MANAGE_COURSES	= 2;
	self.PAGE_COMBI_MODE		= 3;
	self.PAGE_MANAGE_COMBINES	= 4;
	self.PAGE_SPEEDS			= 5;
	self.PAGE_GENERAL_SETTINGS	= 6;
	self.PAGE_DRIVING_SETTINGS	= 7;
	self.PAGE_COURSE_GENERATION	= 8;
	self.PAGE_SHOVEL_POSITIONS	= 9;
	self.PAGE_BUNKERSILO_SETTINGS = 10;

	self.basePosX = courseplay.hud.basePosX;
	self.basePosY = courseplay.hud.basePosY;
	self.baseWidth  = self:pxToNormal(630, 'x');
	self.baseHeight = self:pxToNormal(347, 'y');
	self.baseCenterPosX = self.basePosX + self.baseWidth * 0.5;

	self.baseUVsPx = { 10,357, 640,10 };
	self.baseWithModeButtonsUVsPx = {10,724, 640,377 }; 
	self.baseTextureSize = {
		x = 1024;
		y = 1024;
	};
	-- COLORS NOTE:
	-- Because Giants fucked up big time, overlay colors that don't use full values are displayed way brighter than they should.
	-- Until Giants fixes this, we're gonna have to use fake color values that effectively produce our desired colors
	self.colors = {
		white 		  = courseplay.utils:rgbToNormal(255, 255, 255, 1.00),
		whiteInactive = courseplay.utils:rgbToNormal(255, 255, 255, 0.75),
		whiteDisabled = courseplay.utils:rgbToNormal(255, 255, 255, 0.15),
		hover 		  = courseplay.utils:rgbToNormal(  4,  98, 180, 1.00), -- IS FAKE COLOR! ORIG COLOR: 32/168/219/1
		activeGreen   = courseplay.utils:rgbToNormal( 43, 205,  10, 1.00), -- IS FAKE COLOR! ORIG COLOR: 110/235/56/1
		activeRed 	  = courseplay.utils:rgbToNormal(153,  22,  19, 1.00), -- IS FAKE COLOR! ORIG COLOR: 206/83/77/1
		closeRed 	  = courseplay.utils:rgbToNormal(116,   0,   0, 1.00), -- IS FAKE COLOR! ORIG COLOR: 180/0/0/1
		warningRed 	  = courseplay.utils:rgbToNormal(222,   2,   3, 1.00), -- IS FAKE COLOR! ORIG COLOR: 240/25/25/1
		shadow 		  = courseplay.utils:rgbToNormal(  4,   4,   4, 1.00), -- IS FAKE COLOR! ORIG COLOR: 35/35/35/1
		textDark 	  = courseplay.utils:rgbToNormal(  1,   1,   1, 1.00)  -- IS FAKE COLOR! ORIG COLOR: 15/15/15/1
	};

	self.visibleArea = {};
	self.visibleArea.width = self:pxToNormal(600, 'x');
	self.visibleArea.x1 = self.basePosX + self:pxToNormal(15, 'x');
	self.visibleArea.x2 = self.visibleArea.x1 + self.visibleArea.width;
	self.visibleArea.height = self:pxToNormal(326, 'y');
	self.visibleArea.y1 = self.basePosY + self:pxToNormal(8, 'y');
	self.visibleArea.y2 = self.visibleArea.y1 + self.visibleArea.height;

	-- SEEDUSAGECALCULATOR
	self.suc = {};
	self.suc.UVsPx = { 10,876, 476,744 };
	self.suc.width  = self:pxToNormal(466, 'x');
	self.suc.height = self:pxToNormal(132, 'y');
	self.suc.x1 = self.baseCenterPosX - self.suc.width * 0.5;
	self.suc.x2 = self.baseCenterPosX + self.suc.width * 0.5;
	self.suc.y1 = self.basePosY + self.baseHeight; -- + self:pxToNormal(5, 'y');
	self.suc.y2 = self.suc.y1 + self.suc.height;

	self.suc.visibleArea = {};
	self.suc.visibleArea.width  = self:pxToNormal(450, 'x');
	self.suc.visibleArea.height = self:pxToNormal(116, 'y');
	self.suc.visibleArea.x1 = self.baseCenterPosX - self.suc.visibleArea.width * 0.5;
	self.suc.visibleArea.x2 = self.baseCenterPosX + self.suc.visibleArea.width * 0.5;
	self.suc.visibleArea.y1 = self.suc.y1 + self:pxToNormal(8, 'y');
	self.suc.visibleArea.y2 = self.suc.y2 - self:pxToNormal(8, 'y');
	self.suc.visibleArea.hPadding = self:pxToNormal(10, 'x');
	self.suc.visibleArea.vPadding = self:pxToNormal(10, 'y');
	self.suc.visibleArea.overlayWidth = 50 -- To Do replace this with somthingg_currentMission.hudTipperOverlay.width * 2.75;
	self.suc.visibleArea.overlayHeight = self.suc.visibleArea.overlayWidth * g_screenAspectRatio;
	self.suc.visibleArea.overlayPosX = self.suc.visibleArea.x2 - self.suc.visibleArea.overlayWidth - self.suc.visibleArea.hPadding;
	self.suc.visibleArea.overlayPosY = self.suc.visibleArea.y1 + self.suc.visibleArea.vPadding;


	--print(string.format("\t\tposX=%f,posY=%f, visX1=%f,visX2=%f, visY1=%f,visY2=%f, visCenter=%f", self.basePosX, self.basePosY, self.visibleArea.x1, self.visibleArea.x2, self.visibleArea.y1, self.visibleArea.y2, self.baseCenterPosX));

	-- LINES AND TEXT
	self.fontSizes = {
		seedUsageCalculator = self:pxToNormal(16, 'y');
		pageTitle = self:pxToNormal(22, 'y');
		contentTitle = self:pxToNormal(17, 'y');
		contentValue = self:pxToNormal(15, 'y');
		bottomInfo = self:pxToNormal(16, 'y');
		bottomInfoSmall = self:pxToNormal(13, 'y');
		version = self:pxToNormal(11, 'y');
		infoText = self:pxToNormal(16, 'y');
	};
	self.numPages = 10;
	self.numLines = 8;
	self.lineHeight = self:pxToNormal(23, 'y');
	self.linesPosY = {};
	self.linesButtonPosY = {};
	for l=1,self.numLines do
		if l == 1 then
			self.linesPosY[l] = self.basePosY + self:pxToNormal(229 + 23*0.5 - 17*0.5 + 2, 'y'); -- gfx line bottom y + lineHeight/2 - fontSize/2 plus some magic 2px for good measure
			self.linesButtonPosY[l] = self.basePosY + self:pxToNormal(229 + 23*0.5 - 16*0.5, 'y'); -- gfx line bottom y + lineHeight/2 - buttonSize/2
		else
			self.linesPosY[l] = self.linesPosY[1] - ((l-1) * self.lineHeight);
			self.linesButtonPosY[l] = self.linesButtonPosY[1] - ((l-1) * self.lineHeight);
		end;
	end;
	self.contentMinX = self.visibleArea.x1 + self:pxToNormal(10, 'x');
	self.contentMaxX = self.visibleArea.x2 - self:pxToNormal(10, 'x');
	self.contentMaxWidth = self.contentMaxX - self.contentMinX;
	self.col1posX = self.contentMinX;
	self.col2posX = {
		[self.PAGE_COMBINE_CONTROLS]  = self.basePosX + self:pxToNormal(368, 'x'),
		[self.PAGE_CP_CONTROL] 		  = self.basePosX + self:pxToNormal(368, 'x'),
		[self.PAGE_MANAGE_COURSES] 	  = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_COMBI_MODE] 		  = self.basePosX + self:pxToNormal(368, 'x'),
		[self.PAGE_MANAGE_COMBINES]   = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_SPEEDS] 			  = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_GENERAL_SETTINGS]  = self.basePosX + self:pxToNormal(350, 'x'),
		[self.PAGE_DRIVING_SETTINGS]  = self.basePosX + self:pxToNormal(368, 'x'),
		[self.PAGE_COURSE_GENERATION] = self.basePosX + self:pxToNormal(368, 'x'),
		[self.PAGE_SHOVEL_POSITIONS]  = self.basePosX + self:pxToNormal(390, 'x'),
		[self.PAGE_BUNKERSILO_SETTINGS]  = self.basePosX + self:pxToNormal(390, 'x'),
	};
	self.col2posXforce = {
		--[[[self.PAGE_COMBINE_CONTROLS] = {
			[4] = self.basePosX + self:pxToNormal(407, 'x');
			[5] = self.basePosX + self:pxToNormal(407, 'x');
			[7] = self.basePosX + self:pxToNormal(407, 'x');
		};
		[self.PAGE_GENERAL_SETTINGS] = {
			[4] = self.basePosX + self:pxToNormal(240, 'x');
		};
		[self.PAGE_DRIVING_SETTINGS] = {
			[7] = self.basePosX + self:pxToNormal(202, 'x');
			[8] = self.basePosX + self:pxToNormal(202, 'x');
		};]]
	};
	self.col3posX = {
		[self.PAGE_COURSE_GENERATION] = self.basePosX + self:pxToNormal(450, 'x'),
	};

	self.versionPosY = self.visibleArea.y1 + self:pxToNormal(16, 'y');

	-- PAGE TITLES
	self.pageTitles = {
		[self.PAGE_COMBINE_CONTROLS]  = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBINE_CONTROLS"), -- combine controls
		[self.PAGE_CP_CONTROL] 		  = courseplay:loc("COURSEPLAY_PAGE_TITLE_CP_CONTROL"), -- courseplay control
		[self.PAGE_MANAGE_COURSES] 	  = { courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COURSES"), courseplay:loc("COURSEPLAY_PAGE_TITLE_CHOOSE_FOLDER"), courseplay:loc("COURSEPLAY_COURSES_FILTER_TITLE") }, -- courses & filter
		[self.PAGE_COMBI_MODE] 		  = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBI_MODE"), -- combi mode settings
		[self.PAGE_MANAGE_COMBINES]   = courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COMBINES"), -- manage combines
		[self.PAGE_SPEEDS] 			  = courseplay:loc("COURSEPLAY_PAGE_TITLE_SPEEDS"), -- speeds
		[self.PAGE_GENERAL_SETTINGS]  = courseplay:loc("COURSEPLAY_PAGE_TITLE_GENERAL_SETTINGS"), -- general settings
		[self.PAGE_DRIVING_SETTINGS]  = courseplay:loc("COURSEPLAY_PAGE_TITLE_DRIVING_SETTINGS"), -- Driving settings
		[self.PAGE_COURSE_GENERATION] = courseplay:loc("COURSEPLAY_MODESPECIFIC_SETTINGS"), -- course generation
		[self.PAGE_SHOVEL_POSITIONS]  = courseplay:loc("COURSEPLAY_SHOVEL_POSITIONS"), -- shovel
		[self.PAGE_BUNKERSILO_SETTINGS]  = courseplay:loc("COURSEPLAY_MODE10_SETTINGS") -- compacter
	};

	self.pageTitlePosX = self.visibleArea.x1 + self:pxToNormal(55, 'x');
	self.pageTitlePosY = self.visibleArea.y1 + self:pxToNormal(249 + 34*0.5 - 23*0.5 + 5, 'y'); -- title line bottom y + title line height/2 - fontSize/2 plus some magic 5px for good measure


	-- BUTTON SIZES AND POSITIONS
	self.buttonSize = {
		big = {
			w = self:pxToNormal(32, 'x');
			h = self:pxToNormal(32, 'y');
			margin = self:pxToNormal(10, 'x');
		};
		middle = {
			w = self:pxToNormal(24, 'x');
			h = self:pxToNormal(24, 'y');
			margin = self:pxToNormal(8, 'x');
		};
		small = {
			w = self:pxToNormal(16, 'x');
			h = self:pxToNormal(16, 'y');
			margin = self:pxToNormal(8, 'x');
		};
	};

	self.indent = self.buttonSize.small.w * 1.25;
	self.topIconsY = self.basePosY + self:pxToNormal(263, 'y');

	self.buttonPosX = {};
	for i=1,5 do
		self.buttonPosX[i] = self.contentMaxX + self.buttonSize.small.margin - i * (self.buttonSize.small.w + self.buttonSize.small.margin);
	end;

	self.buttonCoursesPosX = {};
	self.buttonCoursesPosX[0] = self.contentMinX;
	for i=1,5 do
		self.buttonCoursesPosX[i] = self.buttonPosX[i] - self.buttonSize.middle.w - self.buttonSize.middle.margin;
	end;

	-- ICON SPRITE
	self.iconSpritePath = Utils.getFilename('img/iconSprite.png', courseplay.path);
	self.iconSpriteSize = {
		x = 256;
		y = 512;
	};

	self.modeButtonsUVsPx = {
		[courseplay.MODE_GRAIN_TRANSPORT]		 = { 112, 72, 144,40 };
		[courseplay.MODE_COMBI]					 = { 148, 72, 180,40 };
		[courseplay.MODE_OVERLOADER]			 = { 184, 72, 216,40 };
		[courseplay.MODE_SEED_FERTILIZE]		 = { 220, 72, 252,40 };
		[courseplay.MODE_TRANSPORT]				 = {   4,108,  36,76 };
		[courseplay.MODE_FIELDWORK]				 = {  40,108,  72,76 };
		[courseplay.MODE_COMBINE_SELF_UNLOADING] = {  76,108, 108,76 };
		[courseplay.MODE_LIQUIDMANURE_TRANSPORT] = { 112,108, 144,76 };
		[courseplay.MODE_SHOVEL_FILL_AND_EMPTY]	 = { 148,108, 180,76 };
		[courseplay.MODE_BUNKERSILO_COMPACTER]	 = { 219,431, 251,399 };
	};

	self.pageButtonsUVsPx = {
		[self.PAGE_COMBINE_CONTROLS]  = {   4,36,  36, 4 };
		[self.PAGE_CP_CONTROL] 		  = {  40,36,  72, 4 };
		[self.PAGE_MANAGE_COURSES] 	  = {  76,36, 108, 4 };
		[self.PAGE_COMBI_MODE] 		  = { 112,36, 144, 4 };
		[self.PAGE_MANAGE_COMBINES]   = { 148,36, 180, 4 };
		[self.PAGE_SPEEDS] 			  = { 184,36, 216, 4 };
		[self.PAGE_GENERAL_SETTINGS]  = { 220,36, 252, 4 };
		[self.PAGE_DRIVING_SETTINGS]  = {   4,72,  36,40 };
		[self.PAGE_COURSE_GENERATION] = {  40,72,  72,40 };
		[self.PAGE_SHOVEL_POSITIONS]  = {  76,72, 108,40 };
		[self.PAGE_BUNKERSILO_SETTINGS]  = { 219,431, 251,399 };  --{ 220,396, 252,365 };
	};

	self.buttonUVsPx = {
		calculator         = {  76,288, 108,256 };
		cancel             = {  40,288,  72,256 };
		close              = { 148,216, 180,184 };
		copy               = { 184,180, 216,148 };
		courseAdd          = {  40,252,  72,220 };
		courseLoadAppend   = {   4,252,  36,220 };
		courseClear        = { 184,360, 216,328 };
		eye                = { 148,180, 180,148 };
		delete             = { 184,216, 216,184 };
		folderNew          = { 220,216, 252,184 };
		folderParentFrom   = {  76,252, 108,220 };
		folderParentTo     = { 112,252, 144,220 };
		headlandDirCW      = {   4,324,  36,292 };
		headlandDirCCW     = {  40,324,  72,292 };
		headlandOrdBef     = { 112,288, 176,256 };
		headlandOrdAft     = { 184,288, 248,256 };
		generateCourse     = {  40, 72,  72, 40 };
		courseGenSettings  = { 220, 36, 252,  4 }; -- same as settings cogwheel for now
		navUp              = {  76,216, 108,184 };
		navDown            = { 112,216, 144,184 };
		navLeft            = {   4,216,  36,184 };
		navRight           = {  40,216,  72,184 };
		navPlus            = { 148,252, 180,220 };
		navMinus           = { 184,252, 216,220 };
		recordingAddSplit  = { 220,360, 252,328 };
		recordingCross     = {  76,180, 108,148 };
		recordingDelete    = { 148,360, 180,328 };
		recordingPause     = {  40,360,  72,328 };
		recordingPlay      = { 220,324, 252,292 };
		recordingReverse   = { 112,360, 144,328 };
		recordingStop      = {  76,360, 108,328 };
		recordingTurn      = {   4,360,  36,328 };
		recordingWait      = {  40,180,  72,148 };
		recordingUnload	   = {   4,431,  36,399 };
		refresh            = { 220,252, 252,220 };
		save               = { 220,180, 252,148 };
		search             = {   4,288,  36,256 };
		shovelLoading      = {  76,324, 108,292 };
		shovelUnloading    = { 112,324, 144,292 };
		shovelPreUnload    = { 148,324, 180,292 };
		shovelTransport    = { 184,324, 216,292 };
		waypointSignsAll   = {  76,396, 144,364 };
		waypointSignsEnd   = { 148,396, 216,364 };
		waypointSignsStart = {   4,396,  72,364 };
	};

	-- bottom info
	self.bottomInfo = {};
	self.bottomInfo.iconWidth  = self.buttonSize.middle.w;
	self.bottomInfo.iconHeight = self.buttonSize.middle.h;
	self.bottomInfo.textPosY = self.basePosY + self:pxToNormal(36 + 16*0.5 + 1, 'y');
	self.bottomInfo.textSmallPosY = self.bottomInfo.textPosY; -- + self:pxToNormal(1, 'y');
	self.bottomInfo.iconPosY = self.basePosY + self:pxToNormal(36 + 30*0.5 - 24*0.5, 'y');

	self.bottomInfo.modeIconX = self.col1posX;
	self.bottomInfo.courseNameX = self.bottomInfo.modeIconX + self.bottomInfo.iconWidth * 1.25;
	self.bottomInfo.crossingPointsIconX = self.contentMaxX - self.bottomInfo.iconWidth * 2;
	self.bottomInfo.crossingPointsTextX = self.bottomInfo.crossingPointsIconX + self.bottomInfo.iconWidth * 1.5; -- rendered with center alignment
	self.bottomInfo.waitPointsIconX = self.bottomInfo.crossingPointsIconX - self.buttonSize.middle.margin - self.bottomInfo.iconWidth * 2;
	self.bottomInfo.waitPointsTextX = self.bottomInfo.waitPointsIconX + self.bottomInfo.iconWidth * 1.5; -- rendered with center alignment
	self.bottomInfo.waypointIconX = self.bottomInfo.waitPointsIconX - self.buttonSize.middle.margin - self.bottomInfo.iconWidth * 4;
	self.bottomInfo.waypointTextX = self.bottomInfo.waypointIconX + self.bottomInfo.iconWidth * 1.25;
	self.bottomInfo.additionalContentX = self.bottomInfo.waypointIconX - self.bottomInfo.iconWidth
	
	self.bottomInfo.modeUVsPx = {
		[courseplay.MODE_GRAIN_TRANSPORT]		 = { 184,108, 216, 76 };
		[courseplay.MODE_COMBI]					 = { 220,108, 252, 76 };
		[courseplay.MODE_OVERLOADER]			 = {   4,144,  36,112 };
		[courseplay.MODE_SEED_FERTILIZE]		 = {  40,144,  72,112 };
		[courseplay.MODE_TRANSPORT]				 = {  76,144, 108,112 };
		[courseplay.MODE_FIELDWORK]				 = { 112,144, 144,112 };
		[courseplay.MODE_COMBINE_SELF_UNLOADING] = { 148,144, 180,112 };
		[courseplay.MODE_LIQUIDMANURE_TRANSPORT] = { 184,144, 216,112 };
		[courseplay.MODE_SHOVEL_FILL_AND_EMPTY]	 = { 220,144, 252,112 };
		[courseplay.MODE_BUNKERSILO_COMPACTER]	 = { 219,394, 251,362 };
	};

	-- TOOLTIP
	self.toolTipIconWidth  = self:pxToNormal(20, 'x');
	self.toolTipIconHeight = self:pxToNormal(20, 'y');
	self.toolTipIconPosX = self.col1posX;
	self.toolTipIconPosY = self.basePosY + self:pxToNormal(11, 'y');
	self.toolTipTextPosX = self.toolTipIconPosX + self.toolTipIconWidth * 1.25;
	self.toolTipTextPosY = self.basePosY + self:pxToNormal(16, 'y');

	-- INFO TEXT
	self.infoTextPosX = self.col1posX;
	self.infoTextPosY = self.toolTipTextPosY;

	-- DIRECTION ARROW
	self.directionArrowWidth = self:pxToNormal(128, 'x');
	self.directionArrowHeight = self:pxToNormal(128, 'y');
	self.directionArrowPosX = self.baseCenterPosX - self.directionArrowWidth * 0.5;
	self.directionArrowPosY = self.linesPosY[8]; -- self.basePosY + self:pxToNormal(118, 'y');

	-- INGAME MAP ICONS
	self.ingameMapIconsUVs = {
		[courseplay.MODE_GRAIN_TRANSPORT] 			= courseplay.utils:rgbToNormal(255, 113,  16, 1),       -- Orange
		[courseplay.MODE_COMBI] 					= courseplay.utils:rgbToNormal(255, 203,  24, 1),       -- Yellow
		[courseplay.MODE_OVERLOADER] 				= courseplay.utils:rgbToNormal(129, 204,  52, 1),       -- Green
		[courseplay.MODE_SEED_FERTILIZE] 			= courseplay.utils:rgbToNormal( 30, 255, 156, 1),       -- Light Green
		[courseplay.MODE_TRANSPORT] 				= courseplay.utils:rgbToNormal( 21, 198, 255, 1),       -- Blue
		[courseplay.MODE_FIELDWORK] 				= courseplay.utils:rgbToNormal( 49,  52, 140, 1),       -- Dark Blue
		[courseplay.MODE_COMBINE_SELF_UNLOADING]	= courseplay.utils:rgbToNormal(159,  29, 250, 1),       -- Purple
		[courseplay.MODE_LIQUIDMANURE_TRANSPORT] 	= courseplay.utils:rgbToNormal(255,  27, 231, 1),       -- Pink
		[courseplay.MODE_SHOVEL_FILL_AND_EMPTY]		= courseplay.utils:rgbToNormal(231,  19,  19, 1),       -- Red
		[courseplay.MODE_BUNKERSILO_COMPACTER]		= courseplay.utils:rgbToNormal(231,  19,  19, 1),       -- Red
	};

	self.pagesWithSaveCourseIcon = { 	[1]=true;
										[2]=true;
									}
									
	-- SOUND
	self.clickSound = createSample('clickSound');
	loadSample(self.clickSound, Utils.getFilename('sounds/cpClickSound.wav', courseplay.path), false);
end;


-- ####################################################################################################
-- set the content cyclic
function courseplay.hud:setContent(vehicle)
	-- self = courseplay.hud
	if vehicle.cp.hud.firstTimeSetContent then
		--- Reset tools
		-- This is to show the silo filltype line on first time opening the hud and the mode is Grain Transport.
		if vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT then
			--courseplay:resetTools(vehicle); TODO Tommi shouldn't be needed anymore
		end;
		vehicle.cp.hud.firstTimeSetContent = false
	end;

	-- BOTTOM GLOBAL INFO
	-- mode icon
	vehicle.cp.hud.content.bottomInfo.showModeIcon = vehicle.cp.mode > 0 and vehicle.cp.mode <= courseplay.NUM_MODES;

	-- course name
	if vehicle.cp.currentCourseName ~= nil then
		vehicle.cp.hud.content.bottomInfo.courseNameText = vehicle.cp.currentCourseName;
	elseif vehicle.Waypoints[1] ~= nil then
		vehicle.cp.hud.content.bottomInfo.courseNameText = courseplay:loc('COURSEPLAY_TEMP_COURSE');
	else
		vehicle.cp.hud.content.bottomInfo.courseNameText = courseplay:loc('COURSEPLAY_NO_COURSE_LOADED');
	end;

	if vehicle.Waypoints[vehicle.cp.waypointIndex] ~= nil or vehicle.cp.isRecording or vehicle.cp.recordingIsPaused or g_server == nil then
		-- waypoints
		if not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused then
			local str = ('%d/%d'):format(vehicle.cp.waypointIndex, vehicle.cp.numWaypoints);
			if str:len() > 7 then
				vehicle.cp.hud.content.bottomInfo.waypointTextSmall = str;
				vehicle.cp.hud.content.bottomInfo.waypointText = nil;
			else
				vehicle.cp.hud.content.bottomInfo.waypointText = str;
			end;
		else
			vehicle.cp.hud.content.bottomInfo.waypointText = tostring(vehicle.cp.waypointIndex);
		end;

		-- waitPoints
		vehicle.cp.hud.content.bottomInfo.waitPointsText = tostring(vehicle.cp.numWaitPoints);

		-- crossingPoints
		vehicle.cp.hud.content.bottomInfo.crossingPointsText = tostring(vehicle.cp.numCrossingPoints);
	else
		vehicle.cp.hud.content.bottomInfo.waypointText = nil;
		vehicle.cp.hud.content.bottomInfo.waypointTextSmall = nil;
		vehicle.cp.hud.content.bottomInfo.waitPointsText = nil;
		vehicle.cp.hud.content.bottomInfo.crossingPointsText = nil;
	end;

	--setup bottomInfo texts
	if vehicle.cp.timeRemaining ~= nil then
		local timeRemaining = courseplay:sekToTimeFormat(vehicle.cp.timeRemaining)
		vehicle.cp.hud.content.bottomInfo.timeRemainingText = ('%02.f:%02.f:%02.f'):format(timeRemaining.nHours,timeRemaining.nMins,timeRemaining.nSecs)
	else
		vehicle.cp.hud.content.bottomInfo.timeRemainingText = nil
	end
	
	if vehicle.cp.convoyActive then
		vehicle.cp.hud.content.bottomInfo.convoyText = string.format("<--%s--> %d/%d",(vehicle.cp.convoy.distance == 0 and "--" or string.format("%d%s",vehicle.cp.convoy.distance,courseplay:loc('COURSEPLAY_UNIT_METER'))),vehicle.cp.convoy.number,vehicle.cp.convoy.members)
	else
		vehicle.cp.hud.content.bottomInfo.convoyText = nil
	end	
		
	if vehicle.cp.runCounterActive and vehicle.cp.canDrive and vehicle.cp.driver.runCounter then
		vehicle.cp.hud.content.bottomInfo.runCounterText = g_fillTypeManager:getFillTypeByIndex(vehicle.cp.siloSelectedFillType).title..string.format(": %d / %d",vehicle.cp.driver.runCounter, vehicle.cp.maxRunNumber);
	else
		vehicle.cp.hud.content.bottomInfo.runCounterText = nil 
	end
	------------------------------------------------------------------

	-- AUTOMATIC PAGE RELOAD BASED ON VARIABLE STATE
	-- ALL PAGES
	if vehicle.cp.hud.reloadPage[-1] then
		for page=0,self.numPages do
			self:setReloadPageOrder(vehicle, page, true);
		end;
		self:setReloadPageOrder(vehicle, -1, false);
	end;

	-- RELOAD PAGE
	if vehicle.cp.hud.reloadPage[vehicle.cp.hud.currentPage] then
		for line=1,self.numLines do
			for column=1,3 do
				vehicle.cp.hud.content.pages[vehicle.cp.hud.currentPage][line][column].text = nil;
			end;
		end;
		self:showRecordingButtons(vehicle,false)
		self:showCpModeButtons(vehicle, false)
		vehicle.cp.hud.saveCourseButton:setShow(false)
		vehicle.cp.hud.clearCurrentCourseButton:setShow(false)
		vehicle.cp.hud.copyCourseButton:setShow(false)
		self:deleteAllTexts(vehicle,vehicle.cp.hud.currentPage)
		self:updatePageContent(vehicle, vehicle.cp.hud.currentPage);
		self:updateDebugChannelButtons(vehicle)
	end;
end; --END setHudContent()

function courseplay.hud:deleteAllTexts(vehicle,page)
	for line=1,self.numLines do
		for column=1,3 do
			vehicle.cp.hud.content.pages[page][line][column].text = nil;
		end;
	end;
end

function courseplay.hud:renderHud(vehicle)
	-- self = courseplay.hud

	-- SEEDUSAGECALCULATOR
	if vehicle.cp.suc.active then
		vehicle.cp.hud.suc:render();
		if vehicle.cp.suc.selectedFruit.overlay then
			vehicle.cp.suc.selectedFruit.overlay:render();
		end;
	end;

	-- BASE HUD
	if vehicle.cp.hud.currentPage == self.PAGE_CP_CONTROL and vehicle.cp.canSwitchMode and not vehicle.cp.distanceCheck then
		vehicle.cp.hud.bgWithModeButtons:render();
	else
		vehicle.cp.hud.bg:render();
	end;


	-- BUTTONS
	courseplay.buttons:renderButtons(vehicle, vehicle.cp.hud.currentPage);
	if vehicle.cp.hud.mouseWheel.render then
		vehicle.cp.hud.mouseWheel.icon:render();
	end;

	-- VERSION INFO
	if courseplay.versionDisplayStr ~= nil then
		courseplay:setFontSettings('white', false, 'right');
		renderText(self.contentMaxX, self.versionPosY, self.fontSizes.version, courseplay.versionDisplayStr);
	end;


	-- HUD TITLES
	courseplay:setFontSettings('white', true, 'left');
	local hudPageTitle = self.pageTitles[vehicle.cp.hud.currentPage];
	if vehicle.cp.hud.currentPage == 2 then
		if not vehicle.cp.hud.choose_parent and vehicle.cp.hud.filter == '' then
			hudPageTitle = self.pageTitles[vehicle.cp.hud.currentPage][1];
		elseif vehicle.cp.hud.choose_parent then
			hudPageTitle = self.pageTitles[vehicle.cp.hud.currentPage][2];
		elseif vehicle.cp.hud.filter ~= '' then
			hudPageTitle = string.format(self.pageTitles[vehicle.cp.hud.currentPage][3], vehicle.cp.hud.filter);
		end;
	end;
	renderText(self.pageTitlePosX, self.pageTitlePosY, self.fontSizes.pageTitle, hudPageTitle);


	--MAIN CONTENT
	courseplay:setFontSettings('white', false);
	local page = vehicle.cp.hud.currentPage;
	for line,columns in pairs(vehicle.cp.hud.content.pages[page]) do
		for column,entry in pairs(columns) do
			if column == 1 and entry.text ~= nil and entry.text ~= '' then
				if entry.isClicked then
					courseplay:setFontSettings('activeRed', false);
				elseif entry.isHovered then
					courseplay:setFontSettings('hover', false);
				end;
				renderText(self.col1posX + entry.indention, self.linesPosY[line], self.fontSizes.contentTitle, entry.text);
				courseplay:setFontSettings('white', false);
			elseif column >= 2 and entry.text ~= nil and entry.text ~= "" then
				renderText(vehicle.cp.hud.content.pages[page][line][column].posX, self.linesPosY[line], self.fontSizes.contentValue, entry.text);
			end;
		end;
	end;
	if page == 6 then -- debug channels text
		courseplay:setFontSettings('textDark', true, 'center');
		local channelNum;
		for i,data in ipairs(courseplay.debugButtonPosData) do
			channelNum = courseplay.debugChannelSectionStart + (i - 1);
			renderText(data.textPosX, data.textPosY, self.fontSizes.contentValue, tostring(channelNum));
		end
		courseplay:setFontSettings('white', false, 'left');
	end;

	-- SEED USAGE CALCULATOR
	if vehicle.cp.suc.active then
		local x = vehicle.cp.suc.textMinX;
		local selectedField = courseplay.fields.fieldData[ vehicle.cp.fieldEdge.selectedField.fieldNum ];
		local selectedFruit = vehicle.cp.suc.selectedFruit;
		courseplay:setFontSettings('shadow', true);
		renderText(x, vehicle.cp.suc.lines.title.posY - 0.001, vehicle.cp.suc.lines.title.fontSize, vehicle.cp.suc.lines.title.text);
		courseplay:setFontSettings('white', true);
		renderText(x, vehicle.cp.suc.lines.title.posY        , vehicle.cp.suc.lines.title.fontSize, vehicle.cp.suc.lines.title.text);

		courseplay:setFontSettings('white', false);
		renderText(x, vehicle.cp.suc.lines.field.posY, vehicle.cp.suc.lines.field.fontSize, selectedField.fieldAreaText);
		renderText(x, vehicle.cp.suc.lines.fruit.posY, vehicle.cp.suc.lines.fruit.fontSize, selectedFruit.sucText);

		renderText(x, vehicle.cp.suc.lines.result.posY, vehicle.cp.suc.lines.result.fontSize, selectedField.seedDataText[selectedFruit.name]);
	end;

	-- BOTTOM GLOBAL INFO
	if vehicle.cp.hud.content.bottomInfo.waitPointsText ~= nil and vehicle.cp.hud.content.bottomInfo.crossingPointsText ~= nil and vehicle.cp.hud.content.bottomInfo.timeRemainingText == nil then
		courseplay:setFontSettings('white', false, 'center');

		renderText(self.bottomInfo.waitPointsTextX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.waitPointsText);
		vehicle.cp.hud.waitPointsIcon:render();

		renderText(self.bottomInfo.crossingPointsTextX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.crossingPointsText);
		vehicle.cp.hud.crossingPointsIcon:render();
	end;
	
	
	-- 2D/DEBUG LINE BUTTON MODE
	if CpManager.isDeveloper and vehicle.cp.drawCourseMode ~= courseplay.COURSE_2D_DISPLAY_OFF then
		local txt;
		if vehicle.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_2DONLY then
			txt = '2D';
		elseif vehicle.cp.drawCourseMode == courseplay.COURSE_2D_DISPLAY_DBGONLY then
			txt = '\nDBG';
		else
			txt = '2D\nDBG';
		end;
		courseplay:setFontSettings('white', true);
		renderText(vehicle.cp.hud.changeDrawCourseModeButton.x + vehicle.cp.hud.changeDrawCourseModeButton.width * 0.5, self.topIconsY + self.fontSizes.version * 1.25, self.fontSizes.version, txt);
		courseplay:setFontSettings('white', false);
	end;
end;

function courseplay.hud:renderHudBottomInfo(vehicle)	
	courseplay:setFontSettings('white', false, 'left');
	if vehicle.cp.hud.content.bottomInfo.showModeIcon then
		vehicle.cp.hud.currentModeIcon:render();
	end;
	
	if vehicle.cp.hud.content.bottomInfo.courseNameText ~= nil then
		renderText(self.bottomInfo.courseNameX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.courseNameText);
	end;
	if vehicle.cp.hud.content.bottomInfo.waypointText ~= nil then
		renderText(self.bottomInfo.waypointTextX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.waypointText);
		vehicle.cp.hud.currentWaypointIcon:render();
	elseif vehicle.cp.hud.content.bottomInfo.waypointTextSmall ~= nil then
		renderText(self.bottomInfo.waypointTextX, self.bottomInfo.textSmallPosY, self.fontSizes.bottomInfoSmall, vehicle.cp.hud.content.bottomInfo.waypointTextSmall);
		vehicle.cp.hud.currentWaypointIcon:render();
	end;

	if vehicle.cp.hud.content.bottomInfo.timeRemainingText ~= nil  then
		courseplay:setFontSettings('white', false, 'right');
		--renderText(self.bottomInfo.additionalContentX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.timeRemainingText);
		renderText(self.bottomInfo.crossingPointsTextX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.timeRemainingText);
	end	
	
	if vehicle.cp.hud.content.bottomInfo.convoyText  ~= nil  then
		courseplay:setFontSettings('white', false, 'right');
		renderText(self.bottomInfo.additionalContentX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.convoyText);
	end
	
	if vehicle.cp.hud.content.bottomInfo.runCounterText ~= nil  then
		courseplay:setFontSettings('white', false, 'right');
		renderText(self.bottomInfo.additionalContentX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.runCounterText);
	end
	
end

-- set the content on demand
function courseplay.hud:updatePageContent(vehicle, page)
	-- self = courseplay.hud

	courseplay:debug(string.format('%s: loadPage(..., %d), set content', nameNum(vehicle), page), 18);
	--go through all the HUD stuff and update the content	
	for line,columns in pairs(vehicle.cp.hud.content.pages[page]) do
		for column,entry in pairs(columns) do
			if entry.functionToCall ~= nil then
				if entry.functionToCall == 'startStop' then
					if vehicle.cp.canDrive then
						self:enableButtonWithFunction(vehicle,page, 'startStop')
						if not vehicle:getIsCourseplayDriving() then
							vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_START_COURSE')
						else
							vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_STOP_COURSE')
						end
						self:enableButtonsOnThisPage(vehicle,page)
					else
						self:disableButtonWithFunction(vehicle,page, 'startStop')
					end
					self:showCpModeButtons(vehicle, not vehicle:getIsCourseplayDriving())
				elseif entry.functionToCall == 'start_record' then
					if not vehicle.cp.canDrive then
						if (not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused) then
							self:enableButtonWithFunction(vehicle,page, 'start_record')
							if vehicle.cp.numWaypoints == 0 then
								vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_RECORDING_START');
							end;
						else
							self:disableButtonsOnThisPage(vehicle,page)
							self:showRecordingButtons(vehicle, true)
						end
					else
						self:disableButtonWithFunction(vehicle,page, 'cancelWait')
					end
				
				elseif entry.functionToCall == 'cancelWait' then
					if vehicle:getIsCourseplayDriving() and vehicle.cp.driver:isWaiting() then
						self:enableButtonWithFunction(vehicle,page, 'cancelWait')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_CONTINUE')
					else
						self:disableButtonWithFunction(vehicle,page, 'cancelWait')
					end				
				elseif entry.functionToCall == 'changeStartAtPoint' then
					if not vehicle:getIsCourseplayDriving() and vehicle.cp.canDrive then
						self:enableButtonWithFunction(vehicle,page, 'changeStartAtPoint')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_START_AT_POINT');
						if vehicle.cp.startAtPoint == courseplay.START_AT_NEAREST_POINT then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_NEAREST_POINT');
						elseif vehicle.cp.startAtPoint == courseplay.START_AT_FIRST_POINT then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_FIRST_POINT');
						elseif vehicle.cp.startAtPoint == courseplay.START_AT_CURRENT_POINT then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_CURRENT_POINT');
						elseif vehicle.cp.startAtPoint == courseplay.START_AT_NEXT_POINT then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_NEXT_POINT');
						end;
					else
						self:disableButtonWithFunction(vehicle,page, 'changeStartAtPoint')
					end				
				elseif entry.functionToCall == 'setStopAtEnd' then
					if vehicle.cp.canDrive then
						self:enableButtonWithFunction(vehicle,page, 'setStopAtEnd')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_STOP_AT_LAST_POINT');
						vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.stopAtEnd and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
					else
						self:disableButtonWithFunction(vehicle,page, 'setStopAtEnd')
					end				
				
				elseif entry.functionToCall == 'toggleAutomaticCoverHandling' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_COVER_HANDLING');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.automaticCoverHandling and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_DEACTIVATED');
				
				elseif entry.functionToCall == 'changeSiloFillType' then
					if vehicle.cp.siloSelectedFillType ~= nil then 
						self:enableButtonWithFunction(vehicle,page, 'changeSiloFillType')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_FARM_SILO_FILL_TYPE');
						vehicle.cp.hud.content.pages[page][line][2].text = g_fillTypeManager:getFillTypeByIndex(vehicle.cp.siloSelectedFillType).title
					else
						self:disableButtonWithFunction(vehicle,page, 'changeSiloFillType')
					end
				elseif entry.functionToCall == 'changemaxRunNumber' then
					if vehicle.cp.canDrive then
						self:enableButtonWithFunction(vehicle,page, 'changemaxRunNumber')
						self:enableButtonWithFunction(vehicle,page, 'toggleRunCounterActive')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_NUMBER_OF_RUNS');
						if vehicle.cp.runCounterActive then
							vehicle.cp.hud.content.pages[page][line][2].text = string.format("%d", vehicle.cp.maxRunNumber);
						else
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_UNLIMITED');
							self:disableButtonWithFunction(vehicle,page, 'changemaxRunNumber')
						end
					
					else
						self:disableButtonWithFunction(vehicle,page, 'changemaxRunNumber')
						self:disableButtonWithFunction(vehicle,page, 'toggleRunCounterActive')
					end
					
				elseif entry.functionToCall == 'resetRunCounter' then
					if vehicle.cp.canDrive and vehicle.cp.runCounterActive then
						self:enableButtonWithFunction(vehicle,page, 'resetRunCounter')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_RESET_NUMBER_OF_RUNS') ;
					else
						self:disableButtonWithFunction(vehicle,page, 'resetRunCounter')
					end
					
					
				elseif entry.functionToCall == 'switchDriverCopy' then
					if not vehicle.cp.canDrive and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused then
						self:enableButtonWithFunction(vehicle,page, 'switchDriverCopy')
						vehicle.cp.hud.copyCourseButton:setShow(true)
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_COPY_COURSE');
						if vehicle.cp.copyCourseFromDriver ~= nil then
							local printString = ''
							local driverName = vehicle.cp.copyCourseFromDriver:getName() or courseplay:loc('COURSEPLAY_VEHICLE');
							local dist = courseplay:distanceToObject(vehicle, vehicle.cp.copyCourseFromDriver);
							if dist >= 1000 then
								printString = printString..('%s %s (%.1f%s)'):format(courseplay:loc('COURSEPLAY_COPY_COURSE'),driverName, dist * 0.001, courseplay:getMeasuringUnit());
							else
								printString = printString..('%s %s (%d%s)'):format(courseplay:loc('COURSEPLAY_COPY_COURSE'),driverName, dist, courseplay:loc('COURSEPLAY_UNIT_METER'));
							end;
							printString = printString..' (' .. (vehicle.cp.copyCourseFromDriver.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE')) .. ')';
							vehicle.cp.hud.content.pages[page][line][1].text = printString
						else
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_NONE');
						end;
					else
						self:disableButtonWithFunction(vehicle,page, 'switchDriverCopy')
					end
				elseif entry.functionToCall == 'openAdvancedCourseGeneratorSettings' then
					if not vehicle:getIsCourseplayDriving() and not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused then
						self:enableButtonWithFunction(vehicle,page, 'openAdvancedCourseGeneratorSettings')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_PAGE_TITLE_COURSE_GENERATION').."...";
					else
						self:disableButtonWithFunction(vehicle,page, 'openAdvancedCourseGeneratorSettings')
					end
				
				elseif entry.functionToCall == 'changeTurnSpeed' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SPEED_TURN');
					vehicle.cp.hud.content.pages[page][line][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.turn), courseplay:getSpeedMeasuringUnit());
				
				elseif entry.functionToCall == 'changeFieldSpeed' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SPEED_FIELD');
					vehicle.cp.hud.content.pages[page][line][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.field), courseplay:getSpeedMeasuringUnit());
				
				elseif entry.functionToCall == 'changeReverseSpeed' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SPEED_REVERSING');
					vehicle.cp.hud.content.pages[page][line][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.reverse), courseplay:getSpeedMeasuringUnit());

							
				elseif entry.functionToCall == 'changeMaxSpeed' then
					local streetSpeedStr = ('%d %s'):format(g_i18n:getSpeed(vehicle.cp.speeds.street), courseplay:getSpeedMeasuringUnit());
					if vehicle.cp.speeds.useRecordingSpeed then
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SPEED_MAX');
						vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_AUTOMATIC'):format(streetSpeedStr);
					else
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SPEED_MAX');
						vehicle.cp.hud.content.pages[page][line][2].text = streetSpeedStr
					end
				elseif entry.functionToCall == 'toggleUseRecordingSpeed' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE');
					if vehicle.cp.speeds.useRecordingSpeed then
						vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_RECORDING');
					else
						vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_MAX');
					end;	
				
				elseif entry.functionToCall == 'changeWarningLightsMode' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_WARNING_LIGHTS');
					vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_WARNING_LIGHTS_MODE_' .. vehicle.cp.warningLightsMode);
				elseif entry.functionToCall == 'toggleShowMiniHud' then
					vehicle.cp.hud.content.pages[page][line][1].text = 'Mini- HUD' --courseplay:loc('COURSEPLAY_WARNING_LIGHTS');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.hud.showMiniHud and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
				
				elseif entry.functionToCall == 'toggleOpenHudWithMouse' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_OPEN_HUD_MODE');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.hud.openWithMouse and courseplay.inputBindings.mouse.secondaryTextI18n or courseplay.inputBindings.keyboard.openCloseHudTextI18n;

				elseif entry.functionToCall == 'toggleIngameMapIconShowText' then
					if CpManager.ingameMapIconActive and CpManager.ingameMapIconShowTextLoaded then
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT');
						if CpManager.ingameMapIconShowName and not CpManager.ingameMapIconShowCourse then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_NAME_ONLY');
						elseif CpManager.ingameMapIconShowName and CpManager.ingameMapIconShowCourse then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_NAME_AND_COURSE');
						else
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_DEACTIVATED');
						end;			
					end;
				elseif entry.functionToCall == 'toggleFuelSaveOption' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_FUELSAVEOPTION');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.saveFuelOptionActive and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
				
				elseif entry.functionToCall == 'toggleAutoRefuel' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_FUEL_SEARCH_FOR');
					if vehicle.cp.allwaysSearchFuel then
						vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_FUEL_ALWAYS');
					else
						vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_FUEL_BELOW_20PCT');
					end
				

				elseif entry.functionToCall == 'changeLoadUnloadOffsetX' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_LOAD_UNLOAD_OFFSET_X');
					if vehicle.cp.loadUnloadOffsetX and vehicle.cp.loadUnloadOffsetX ~= 0 then
						vehicle.cp.hud.content.pages[page][line][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.loadUnloadOffsetX), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.loadUnloadOffsetX > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;
				elseif entry.functionToCall == 'changeLoadUnloadOffsetZ' then
					--load/Unload vertical offset
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_LOAD_UNLOAD_OFFSET_Z');
					if vehicle.cp.loadUnloadOffsetZ and vehicle.cp.loadUnloadOffsetZ ~= 0 then
						vehicle.cp.hud.content.pages[page][line][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.loadUnloadOffsetZ), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.loadUnloadOffsetZ > 0 and 'COURSEPLAY_FRONT' or 'COURSEPLAY_BACK'));
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;
				elseif entry.functionToCall == 'toggleRealisticDriving' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_PATHFINDING');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.realisticDriving and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

				elseif entry.functionToCall == 'changeTurnDiameter' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_TURN_RADIUS');
					if vehicle.cp.turnDiameterAuto ~= nil or vehicle.cp.turnDiameter ~= nil then
						vehicle.cp.hud.content.pages[page][line][2].text = ('%s %d%s'):format(vehicle.cp.turnDiameterAutoMode and '(auto)' or '(mnl)', vehicle.cp.turnDiameter, courseplay:loc('COURSEPLAY_UNIT_METER'));
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;
				elseif entry.functionToCall == 'changeWorkWidth' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_WORK_WIDTH');
					if vehicle.cp.manualWorkWidth then 
						vehicle.cp.hud.content.pages[page][line][2].text = string.format('%.1fm (mnl)', vehicle.cp.workWidth);
					else
						vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.workWidth ~= nil and string.format('%.1fm', vehicle.cp.workWidth) or '---';
					end
				
				elseif entry.functionToCall == 'changeLaneNumber' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_LANE_OFFSET');
					if vehicle.cp.multiTools > 1 then
						self:enableButtonWithFunction(vehicle,page, 'changeLaneNumber')
						if vehicle.cp.laneNumber == 0 then
							vehicle.cp.hud.content.pages[page][line][2].text = ('%s'):format(courseplay:loc('COURSEPLAY_CENTER'));
						else
							vehicle.cp.hud.content.pages[page][line][2].text = ('%d %s'):format(abs(vehicle.cp.laneNumber), courseplay:loc(vehicle.cp.laneNumber > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
						end						
					else
						self:disableButtonWithFunction(vehicle,page, 'changeLaneNumber')
					end
				
				elseif entry.functionToCall == 'changeLaneOffset' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_LANE_OFFSET');
					if vehicle.cp.multiTools == 1 then
						self:enableButtonWithFunction(vehicle,page, 'changeLaneOffset')
						if vehicle.cp.laneOffset and vehicle.cp.laneOffset ~= 0 then 
							vehicle.cp.hud.content.pages[page][line][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.laneOffset), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.laneOffset > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
						else
							vehicle.cp.hud.content.pages[page][line][2].text = '---';
						end
					else
						self:disableButtonWithFunction(vehicle,page, 'changeLaneOffset')	
					end
				
				elseif entry.functionToCall == 'toggleTurnOnField' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_TURN_ON_FIELD');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.turnOnField and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
	
	
	
				elseif entry.functionToCall == 'setCustomSingleFieldEdge' then
					if not vehicle.cp.fieldEdge.customField.isCreated 
					and not vehicle:getIsCourseplayDriving() 
					and not vehicle:getIsCourseplayDriving() 
					and not vehicle.cp.isRecording 
					and not vehicle.cp.recordingIsPaused then
						self:enableButtonWithFunction(vehicle,page, 'setCustomSingleFieldEdge')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SCAN_CURRENT_FIELD_EDGES');
					else
						self:disableButtonWithFunction(vehicle,page, 'setCustomSingleFieldEdge')
					end	
				elseif entry.functionToCall == 'setCustomFieldEdgePathNumber' then
					if vehicle.cp.fieldEdge.customField.isCreated then
						self:enableButtonWithFunction(vehicle,page, 'setCustomFieldEdgePathNumber')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER');
						if vehicle.cp.fieldEdge.customField.fieldNum > 0 then
							vehicle.cp.hud.content.pages[page][line][2].text = tostring(vehicle.cp.fieldEdge.customField.fieldNum);
						else
							vehicle.cp.hud.content.pages[page][line][2].text = '---';
						end;
					else
						self:disableButtonWithFunction(vehicle,page, 'setCustomFieldEdgePathNumber')
					end					
				
				
				elseif entry.functionToCall == 'addCustomSingleFieldEdgeToList' then
					if vehicle.cp.fieldEdge.customField.isCreated and vehicle.cp.fieldEdge.customField.fieldNum > 0 then
						self:enableButtonWithFunction(vehicle,page, 'addCustomSingleFieldEdgeToList')
						if vehicle.cp.fieldEdge.customField.selectedFieldNumExists then
							vehicle.cp.hud.content.pages[page][line][1].text = string.format(courseplay:loc('COURSEPLAY_OVERWRITE_CUSTOM_FIELD_EDGE_PATH_IN_LIST'), vehicle.cp.fieldEdge.customField.fieldNum);
						else
							vehicle.cp.hud.content.pages[page][line][1].text = string.format(courseplay:loc('COURSEPLAY_ADD_CUSTOM_FIELD_EDGE_PATH_TO_LIST'), vehicle.cp.fieldEdge.customField.fieldNum);
						end;
					else
						self:disableButtonWithFunction(vehicle,page, 'addCustomSingleFieldEdgeToList')
					end
				elseif entry.functionToCall == 'toggleSymmetricLaneChange' then
					--Symmetrical lane change
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SYMMETRIC_LANE_CHANGE');
					if vehicle.cp.laneOffset ~= 0 then
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SYMMETRIC_LANE_CHANGE');
						vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.symmetricLaneChange and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;
				elseif entry.functionToCall == 'changeToolOffsetX' then
					--Tool horizontal offset
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_TOOL_OFFSET_X');
					if vehicle.cp.toolOffsetX and vehicle.cp.toolOffsetX ~= 0 then
						vehicle.cp.hud.content.pages[page][line][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.toolOffsetX), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.toolOffsetX > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;
				elseif entry.functionToCall == 'changeToolOffsetZ' then
					--Tool vertical offset
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_TOOL_OFFSET_Z');
					if vehicle.cp.toolOffsetZ and vehicle.cp.toolOffsetZ ~= 0 then
						vehicle.cp.hud.content.pages[page][line][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.toolOffsetZ), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.toolOffsetZ > 0 and 'COURSEPLAY_FRONT' or 'COURSEPLAY_BACK'));
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;
				elseif entry.functionToCall == 'changeWaitTime' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_WAITING_TIME');
					local str;
					if vehicle.cp.waitTime < 1 then
						str = '---';
					elseif vehicle.cp.waitTime < 60 then
						str = courseplay:loc('COURSEPLAY_SECONDS'):format(vehicle.cp.waitTime);
					else
						local minutes, seconds = floor(vehicle.cp.waitTime/60), vehicle.cp.waitTime % 60;
						str = courseplay:loc('COURSEPLAY_MINUTES'):format(minutes);
						if seconds > 0 then
							str = str .. ', ' .. courseplay:loc('COURSEPLAY_SECONDS'):format(seconds);
						end;
					end;
					vehicle.cp.hud.content.pages[page][line][2].text = str;
				
				elseif entry.functionToCall == 'toggleAlignmentWaypoint' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_ALIGNMENT_WAYPOINT');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.alignment.enabled and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
				
				elseif entry.functionToCall == 'toggleConvoyActive' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_COMBINE_CONVOY');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.convoyActive and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED')
				
				elseif entry.functionToCall == 'setConvoyMinDistance' then
					vehicle.cp.hud.content.pages[page][line][1].text = string.format('  %s',courseplay:loc('COURSEPLAY_CONVOY_MAX_DISTANCE'));
					vehicle.cp.hud.content.pages[page][line][2].text = string.format('%dm', vehicle.cp.convoy.minDistance);
				
				elseif entry.functionToCall == 'setConvoyMaxDistance' then
					vehicle.cp.hud.content.pages[page][line][1].text = string.format('  %s',courseplay:loc('COURSEPLAY_CONVOY_MIN_DISTANCE'));
					vehicle.cp.hud.content.pages[page][line][2].text = string.format('%dm', vehicle.cp.convoy.maxDistance);
				
				
				elseif entry.functionToCall == 'changeDriveOnAtFillLevel' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_DRIVE_ON_AT');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.driveOnAtFillLevel ~= nil and ('%d%%'):format(vehicle.cp.driveOnAtFillLevel) or '---';

				elseif entry.functionToCall == 'setDriveNow' then
					if not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused then
						if vehicle.cp.driver and vehicle.cp.driver.getCanShowDriveOnButton then
							if vehicle:getIsCourseplayDriving() and vehicle.cp.driver:getCanShowDriveOnButton() and not vehicle.cp.driveUnloadNow then
								self:enableButtonWithFunction(vehicle,page, 'setDriveNow')
								vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_DRIVE_NOW')
							else
								self:disableButtonWithFunction(vehicle,page, 'setDriveNow')			
							end
						else --temp solution for old mode2
							if vehicle:getIsCourseplayDriving() and not vehicle.cp.driveUnloadNow and vehicle.cp.waypointIndex < 2 then
								self:enableButtonWithFunction(vehicle,page, 'setDriveNow')
								vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_DRIVE_NOW')
							else
								self:disableButtonWithFunction(vehicle,page, 'setDriveNow')			
							end					
						end
					end					
				elseif entry.functionToCall == 'toggleWantsCourseplayer' then
					if not vehicle.cp.driver:getHasCourseplayers() then
						self:enableButtonWithFunction(vehicle,page, 'toggleWantsCourseplayer')
						if vehicle.cp.wantsCourseplayer then
							vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_REQUESTED');
						else
							vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_REQUEST_UNLOADING_DRIVER');
						end
					else
						local courseplayer = vehicle.cp.driver:getFirstCourseplayer()
						self:disableButtonWithFunction(vehicle,page, 'toggleWantsCourseplayer')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_DRIVER');
						vehicle.cp.hud.content.pages[page][line][2].text =  courseplayer:getName();
					end
				elseif entry.functionToCall == 'startStopCourseplayer' then
					if vehicle.cp.driver:getHasCourseplayers() then
						self:enableButtonWithFunction(vehicle,page, 'startStopCourseplayer')
						local courseplayer = vehicle.cp.driver:getFirstCourseplayer()
						if courseplayer.cp.forcedToStop then
							vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_START');
						else
							vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_STOP');
						end
					else
						self:disableButtonWithFunction(vehicle,page, 'startStopCourseplayer')
					end
				elseif entry.functionToCall == 'sendCourseplayerHome' then
					if vehicle.cp.driver:getHasCourseplayers() then
						self:enableButtonWithFunction(vehicle,page, 'sendCourseplayerHome')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_SEND_HOME');
					else
						self:disableButtonWithFunction(vehicle,page, 'sendCourseplayerHome')
					end
		
				elseif entry.functionToCall == 'switchCourseplayerSide' then
					if vehicle.cp.driver:getHasCourseplayers() then
						self:enableButtonWithFunction(vehicle,page, 'switchCourseplayerSide')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_UNLOADING_SIDE');
						if vehicle.cp.forcedSide == 'left' then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_LEFT');
						elseif vehicle.cp.forcedSide == 'right' then
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_RIGHT');
						else
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_UNLOADING_SIDE_NONE');
						end;
					else
						self:disableButtonWithFunction(vehicle,page, 'switchCourseplayerSide')
					end
			
				elseif entry.functionToCall == 'toggleTurnStage' then
					if vehicle.cp.driver:getHasCourseplayers() then
						--manual chopping: initiate/end turning maneuver
						if not  vehicle:getIsCourseplayDriving()  then
							self:enableButtonWithFunction(vehicle,page, 'toggleTurnStage')
							vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_TURN_MANEUVER');
							if vehicle.cp.turnStage == 0 then
								vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_START');
							elseif vehicle.cp.turnStage == 1 then
								vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_FINISH');
							end;
						end;
					else
						self:disableButtonWithFunction(vehicle,page, 'toggleTurnStage')
					end

				elseif entry.functionToCall == 'toggleDriverPriority' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_PRIORITY');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.driverPriorityUseFillLevel and courseplay:loc('COURSEPLAY_FILLEVEL') or courseplay:loc('COURSEPLAY_DISTANCE');

					
				elseif entry.functionToCall == 'toggleStopWhenUnloading' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_STOP_DURING_UNLOADING');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.stopWhenUnloading and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
		
		
				elseif entry.functionToCall == 'changeHeadlandReverseManeuverType' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_HEADLAND_REVERSE_MANEUVER_TYPE')
					vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc( courseplay.headlandReverseManeuverTypeText[ vehicle.cp.headland.reverseManeuverType ])
		
		
				elseif entry.functionToCall == 'changeCombineOffset' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_COMBINE_OFFSET_HORIZONTAL');
					if vehicle.cp.modeState ~= nil then
						if vehicle.cp.combineOffset ~= 0 then
							vehicle.cp.hud.content.pages[page][line][2].text = ('%s %.1fm'):format(vehicle.cp.combineOffsetAutoMode and '(auto)' or '(mnl)', vehicle.cp.combineOffset);
						else
							vehicle.cp.hud.content.pages[page][line][2].text = 'auto';
						end;
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;
		
				elseif entry.functionToCall == 'changeTipperOffset' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_COMBINE_OFFSET_VERTICAL');
					if vehicle.cp.tipperOffset ~= nil then
						if vehicle.cp.tipperOffset ~= 0 then
							vehicle.cp.hud.content.pages[page][line][2].text = ('auto%+.1fm'):format(vehicle.cp.tipperOffset);
						else
							vehicle.cp.hud.content.pages[page][line][2].text = 'auto';
						end;
					else
						vehicle.cp.hud.content.pages[page][line][2].text = '---';
					end;	
					
				elseif entry.functionToCall == 'changeFollowAtFillLevel' then	
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_START_AT');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.followAtFillLevel ~= nil and ('%d%%'):format(vehicle.cp.followAtFillLevel) or '---';
					
				elseif entry.functionToCall == 'changeDriveOnAtFillLevel' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_DRIVE_ON_AT');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.driveOnAtFillLevel ~= nil and ('%d%%'):format(vehicle.cp.driveOnAtFillLevel) or '---';

					
				elseif entry.functionToCall == 'toggleSearchCombineMode' then    --automatic or manual
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_COMBINE_SEARCH_MODE'); --always
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.searchCombineAutomatically and courseplay:loc('COURSEPLAY_AUTOMATIC_SEARCH') or courseplay:loc('COURSEPLAY_MANUAL_SEARCH');
				
				elseif entry.functionToCall == 'selectAssignedCombine' then -- if manual toggle through combines to select one
					--Line 2: select combine manually
					if not vehicle.cp.searchCombineAutomatically then
						self:enableButtonWithFunction(vehicle,page, 'selectAssignedCombine')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_CHOOSE_COMBINE'); --only if manual
						if vehicle.cp.savedCombine ~= nil then
							local name = vehicle.cp.savedCombine:getName()
							local dist = courseplay:distanceToObject(vehicle, vehicle.cp.savedCombine);
							if dist >= 1000 then
								vehicle.cp.hud.content.pages[page][line][2].text = ('%s (%.1f%s)'):format(name, dist * 0.001, courseplay:getMeasuringUnit());
							else
								vehicle.cp.hud.content.pages[page][line][2].text = ('%s (%d%s)'):format(name, dist, courseplay:loc('COURSEPLAY_UNIT_METER'));
							end;
						else
							vehicle.cp.hud.content.pages[page][line][2].text = courseplay:loc('COURSEPLAY_NONE');
						end;
					else
						self:disableButtonWithFunction(vehicle,page, 'selectAssignedCombine')					
					end;
				
				elseif entry.functionToCall == 'setSearchCombineOnField' then 
					--Line 3: choose field for automatic search --only if automatic
					if vehicle.cp.searchCombineAutomatically and courseplay.fields.numAvailableFields > 0 then
						self:enableButtonWithFunction(vehicle,page, 'setSearchCombineOnField')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_SEARCH_COMBINE_ON_FIELD'):format(vehicle.cp.searchCombineOnField > 0 and tostring(vehicle.cp.searchCombineOnField) or '---');
					else
						self:disableButtonWithFunction(vehicle,page, 'setSearchCombineOnField')
					end;
								
				elseif entry.functionToCall == 'showCombineName' then
					self:disableButtonWithFunction(vehicle,page, 'showCombineName')
					--Line 4: current assigned combine
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_CURRENT'); --always
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.activeCombine ~= nil and vehicle.cp.activeCombine.name or courseplay:loc('COURSEPLAY_NONE');

				elseif entry.functionToCall == 'removeActiveCombineFromTractor' then
					--Line 5: remove active combine from tractor
					if vehicle.cp.activeCombine ~= nil then --only if activeCombine
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_REMOVEACTIVECOMBINEFROMTRACTOR');
					end;
					
				elseif entry.functionToCall == 'toggleOppositeTurnMode' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_OPPOSITE_TURN_DIRECTION');
					vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.oppositeTurnMode and courseplay:loc('COURSEPLAY_OPPOSITE_TURN_WHEN_POSSIBLE') or courseplay:loc('COURSEPLAY_OPPOSITE_TURN_AT_END');
				
				elseif entry.functionToCall == 'toggleFertilizeOption' then
					if vehicle.cp.hasFertilizerSowingMachine and not vehicle:getIsCourseplayDriving() then
						self:enableButtonWithFunction(vehicle,page, 'toggleFertilizeOption')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_FERTILIZERFUNCTION');
						vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.fertilizerEnabled and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
					else
						self:disableButtonWithFunction(vehicle,page, 'toggleFertilizeOption')
					end
					
				elseif entry.functionToCall == 'toggleRidgeMarkersAutomatic' then
					if vehicle.cp.hasSowingMachine then
						self:enableButtonWithFunction(vehicle,page, 'toggleRidgeMarkersAutomatic')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_RIDGEMARKERS');
						vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.ridgeMarkersAutomatic and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_DEACTIVATED');
					else
						self:disableButtonWithFunction(vehicle,page, 'toggleRidgeMarkersAutomatic')
					end
					
				elseif entry.functionToCall == 'changeRefillUntilPct' then
					vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_REFILL_UNTIL_PCT');
					vehicle.cp.hud.content.pages[page][line][2].text = ('%d%%'):format(vehicle.cp.refillUntilPct);
							
				elseif entry.functionToCall == 'toggleAutomaticUnloadingOnField' then
					if not vehicle.cp.hasUnloadingRefillingCourse then
						self:enableButtonWithFunction(vehicle,page, 'toggleAutomaticUnloadingOnField')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_UNLOADING_ON_FIELD');
						vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.automaticUnloadingOnField and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_MANUAL');
					else
						self:disableButtonWithFunction(vehicle,page, 'toggleAutomaticUnloadingOnField')
					end
					
				elseif entry.functionToCall == 'togglePlowFieldEdge' then
					if vehicle.cp.hasPlow then
						self:enableButtonWithFunction(vehicle,page, 'togglePlowFieldEdge')
						vehicle.cp.hud.content.pages[page][line][1].text = courseplay:loc('COURSEPLAY_PLOW_FIELD_EDGE');
						vehicle.cp.hud.content.pages[page][line][2].text = vehicle.cp.plowFieldEdge and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
					else
						self:disableButtonWithFunction(vehicle,page, 'togglePlowFieldEdge')
					end
					
				end					
			end		
		end
	end
	
	if self.pagesWithSaveCourseIcon[page] then
		vehicle.cp.hud.saveCourseButton:setShow(vehicle.cp.canDrive and not vehicle.cp.isDriving)
		vehicle.cp.hud.clearCurrentCourseButton:setShow(vehicle.cp.canDrive and not vehicle.cp.isDriving) --TODO the waypoint thing is a hack, make it nicer;
	end

	if page == self.PAGE_MANAGE_COURSES then
		self:updateCourseList(vehicle, self.PAGE_MANAGE_COURSES)
		vehicle.cp.hud.filterButton:setShow(not vehicle.cp.hud.choose_parent);
		vehicle.cp.hud.reloadCourses:setShow(g_server ~= nil and not vehicle.cp.canDrive and not g_currentMission.missionDynamicInfo.isMultiplayer);
		vehicle.cp.hud.newFolderButton:setShow(not vehicle.cp.isDriving)
		self:showShiftHudButtons(vehicle, true)
		self:updateCourseButtonsVisibilty(vehicle)
	else
		self:showShiftHudButtons(vehicle, false)
		vehicle.cp.hud.filterButton:setShow(false);
		vehicle.cp.hud.reloadCourses:setShow(false);
		vehicle.cp.hud.newFolderButton:setShow(false)
	end
	
	if page == self.PAGE_GENERAL_SETTINGS then
		vehicle.cp.hud.content.pages[6][3][1].text = courseplay:loc('COURSEPLAY_WAYPOINT_MODE');
		
		self:showShowWaypointsButtons(vehicle, true)
		vehicle.cp.hud.visualWaypointsStartButton:setActive(vehicle.cp.visualWaypointsStartEnd);
		vehicle.cp.hud.visualWaypointsAllButton:setActive(vehicle.cp.visualWaypointsAll)
		vehicle.cp.hud.visualWaypointsEndButton:setActive(vehicle.cp.visualWaypointsStartEnd)
		vehicle.cp.hud.visualWaypointsCrossingButton:setActive(vehicle.cp.visualWaypointsCrossing)

		
		-- Debug channels
		if courseplay.isDevVersion then
			vehicle.cp.hud.content.pages[6][8][1].text = courseplay:loc('COURSEPLAY_DEBUG_CHANNELS');
		end
	else
		self:showShowWaypointsButtons(vehicle, false)
	end
		
--[[



	--PAGE 1: COURSEPLAY CONTROL
	elseif page == self.PAGE_CP_CONTROL then

		if vehicle.cp.canDrive then
			if not vehicle:getIsCourseplayDriving() then -- only 6 lines available, as the mode buttons are in lines 7 and 8!
				
				if vehicle.cp.hasAugerWagon and not vehicle.cp.hasSugarCaneAugerWagon and (vehicle.cp.mode == courseplay.MODE_OVERLOADER or vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT) then
					vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc('COURSEPLAY_SAVE_PIPE_POSITION');
					if vehicle.cp.pipeWorkToolIndex ~= nil then
						vehicle.cp.hud.content.pages[1][4][2].text = 'OK';
					else
						vehicle.cp.hud.content.pages[1][4][2].text = courseplay:loc('UNKNOWN');
					end
				end
	
	
		if vehicle.cp.lastValidTipDistance ~= nil then
			vehicle.cp.hud.content.pages[3][6][1].text = courseplay:loc('COURSEPLAY_LAST_VAILD_TIP_DIST');
			vehicle.cp.hud.content.pages[3][6][2].text = ('%.1fm'):format(vehicle.cp.lastValidTipDistance);
		end;
	
	--PAGE 3: MODE 2 SETTINGS
	elseif page == self.PAGE_COMBI_MODE then
		
	-- PAGE 8: COURSE GENERATION
	elseif page == self.PAGE_COURSE_GENERATION then
		-- line 1 = field edge path
		vehicle.cp.hud.content.pages[8][1][1].text = courseplay:loc('COURSEPLAY_FIELD_EDGE_PATH');
		if courseplay.fields.numAvailableFields > 0 and vehicle.cp.fieldEdge.selectedField.fieldNum > 0 then
			vehicle.cp.hud.content.pages[8][1][2].text = courseplay.fields.fieldData[vehicle.cp.fieldEdge.selectedField.fieldNum].name;
		elseif vehicle.cp.numWaypoints >= 4 then
			vehicle.cp.hud.content.pages[8][1][2].text = courseplay:loc('COURSEPLAY_CURRENTLY_LOADED_COURSE');
		else
			vehicle.cp.hud.content.pages[8][1][2].text = '---';
		end;

		-- line 2 = work width
		vehicle.cp.hud.content.pages[8][2][1].text = courseplay:loc('COURSEPLAY_WORK_WIDTH');
		if vehicle.cp.manualWorkWidth then 
			vehicle.cp.hud.content.pages[8][2][2].text = string.format('%.1fm (mnl)', vehicle.cp.workWidth);
		else
			vehicle.cp.hud.content.pages[8][2][2].text = vehicle.cp.workWidth ~= nil and string.format('%.1fm', vehicle.cp.workWidth) or '---';
		end
		-- line 3 = starting corner
		if vehicle.cp.isNewCourseGenSelected() and not vehicle.cp.headland.orderBefore then
			vehicle.cp.hud.content.pages[8][3][1].text = courseplay:loc('COURSEPLAY_ENDING_LOCATION');
		else
			vehicle.cp.hud.content.pages[8][3][1].text = courseplay:loc('COURSEPLAY_STARTING_LOCATION');
		end
		-- 1 = SW, 2 = NW, 3 = NE, 4 = SE
		if vehicle.cp.hasStartingCorner then
			vehicle.cp.hud.content.pages[8][3][2].text = courseplay:loc(string.format('COURSEPLAY_CORNER_%d', vehicle.cp.startingCorner)); -- NE/SE/SW/NW
			if vehicle.cp.startingCorner == courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION and vehicle.cp.generationPosition.hasSavedPosition then
				vehicle.cp.hud.content.pages[8][3][2].text = vehicle.cp.hud.content.pages[8][3][2].text..string.format(" (%s %d)",courseplay:loc('COURSEPLAY_FIELD'),vehicle.cp.generationPosition.fieldNum);
			end
		else
			vehicle.cp.hud.content.pages[8][3][2].text = '---';
		end;

		-- line 4 = starting direction
		vehicle.cp.hud.content.pages[8][4][1].text = courseplay:loc('COURSEPLAY_STARTING_DIRECTION');
		-- 1 = North, 2 = East, 3 = South, 4 = West
		if vehicle.cp.hasStartingDirection then
			vehicle.cp.hud.content.pages[8][4][2].text = courseplay:loc(string.format('COURSEPLAY_DIRECTION_%d', vehicle.cp.startingDirection)); -- East/South/West/North
			-- only allow for the new course generator
			if vehicle.cp.startingDirection == courseGenerator.ROW_DIRECTION_MANUAL then
				vehicle.cp.hud.content.pages[8][4][3].text = tostring( courseGenerator.getCompassAngleDeg( vehicle.cp.rowDirectionDeg )) .. '°' .. 
					' (' .. courseplay:loc( courseGenerator.getCompassDirectionText( vehicle.cp.rowDirectionDeg )) .. ')'
			else
				--vehicle.cp.hud.content.pages[8][4][3].text = '---'
			end
		else
			vehicle.cp.hud.content.pages[8][4][2].text = '---';
		end;

		
		-- line 5 = return to first point
		vehicle.cp.hud.content.pages[8][5][1].text = courseplay:loc('COURSEPLAY_RETURN_TO_FIRST_POINT');
		vehicle.cp.hud.content.pages[8][5][2].text = vehicle.cp.returnToFirstPoint and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

		-- line 6 = headland
		vehicle.cp.hud.content.pages[8][6][1].text = courseplay:loc('COURSEPLAY_HEADLAND');
		if vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NARROW_FIELD then
			vehicle.cp.hud.content.pages[8][6][3].text = courseplay:loc('COURSEPLAY_HEADLAND_MODE_NARROW_FIELD');
		else
			vehicle.cp.hud.content.pages[8][6][3].text = vehicle.cp.headland.getNumLanes() ~= 0 and tostring(vehicle.cp.headland.numLanes) or '-';
		end
		-- only allow for the new course generator
		if vehicle.cp.headland.exists() and vehicle.cp.isNewCourseGenSelected() then
			vehicle.cp.hud.content.pages[8][6][2].text = courseplay:loc( courseplay.cornerTypeText[ vehicle.cp.headland.turnType ])
		else
			vehicle.cp.hud.content.pages[8][6][2].text = '---'
		end

		-- line 7 = bypass islands
		vehicle.cp.hud.content.pages[8][7][1].text = courseplay:loc('COURSEPLAY_BYPASS_ISLANDS');
		-- only allow for the new course generator
		if vehicle.cp.isNewCourseGenSelected() then
			vehicle.cp.hud.content.pages[8][7][2].text = courseplay:loc( Island.bypassModeText[ vehicle.cp.courseGeneratorSettings.islandBypassMode ]);
		else
			vehicle.cp.hud.content.pages[8][7][2].text = '---'
		end

		-- line 8 Multiple Tools
		vehicle.cp.hud.content.pages[8][8][1].text = courseplay:loc('COURSEPLAY_MULTI_TOOLS');
		vehicle.cp.hud.content.pages[8][8][2].text = string.format("%d (%.1f%s)",vehicle.cp.multiTools,vehicle.cp.multiTools*vehicle.cp.workWidth,courseplay:loc('COURSEPLAY_UNIT_METER'));
	

	-- PAGE 9: SHOVEL SETTINGS
	elseif page == self.PAGE_SHOVEL_POSITIONS then
		vehicle.cp.hud.content.pages[9][1][1].text = courseplay:loc('COURSEPLAY_SHOVEL_LOADING_POSITION');
		vehicle.cp.hud.content.pages[9][2][1].text = courseplay:loc('COURSEPLAY_SHOVEL_TRANSPORT_POSITION');
		vehicle.cp.hud.content.pages[9][3][1].text = courseplay:loc('COURSEPLAY_SHOVEL_PRE_UNLOADING_POSITION');
		vehicle.cp.hud.content.pages[9][4][1].text = courseplay:loc('COURSEPLAY_SHOVEL_UNLOADING_POSITION');

		for state=2,5 do
			if vehicle.cp.hasShovelStatePositions[state] then
				vehicle.cp.hud.content.pages[9][state-1][2].text = 'OK';
			end;
		end;

		vehicle.cp.hud.content.pages[9][5][1].text = courseplay:loc('COURSEPLAY_SHOVEL_STOP_AND_GO');
		vehicle.cp.hud.content.pages[9][5][2].text = vehicle.cp.shovelStopAndGo and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
		
		vehicle.cp.hud.content.pages[9][6][1].text = courseplay:loc('COURSEPLAY_WORK_WIDTH');
		vehicle.cp.hud.content.pages[9][6][2].text = vehicle.cp.workWidth ~= nil and string.format('%.1fm', vehicle.cp.workWidth) or '---';
	
	--Page 10: BunkerSilo compacter 
	elseif page == self.PAGE_BUNKERSILO_SETTINGS then
		vehicle.cp.hud.content.pages[10][1][1].text = courseplay:loc('COURSEPLAY_MODE10_MODE');
		vehicle.cp.hud.content.pages[10][2][1].text = courseplay:loc('COURSEPLAY_MODE10_SEARCH_MODE');
		vehicle.cp.hud.content.pages[10][3][1].text = courseplay:loc('COURSEPLAY_MODE10_SEARCHRADIUS');
		vehicle.cp.hud.content.pages[10][4][1].text = courseplay:loc('COURSEPLAY_MODE10_BLADE_WIDTH');
		vehicle.cp.hud.content.pages[10][5][1].text = courseplay:loc('COURSEPLAY_MODE10_MAX_BUNKERSPEED');
		
		vehicle.cp.hud.content.pages[10][3][2].text = ('%i%s'):format(vehicle.cp.mode10.searchRadius, courseplay:loc('COURSEPLAY_UNIT_METER'));
		vehicle.cp.hud.content.pages[10][4][2].text = ('%.1f%s'):format(vehicle.cp.workWidth, courseplay:loc('COURSEPLAY_UNIT_METER'));
		if vehicle.cp.mode10.automaticSpeed and vehicle.cp.mode10.leveling then
			vehicle.cp.hud.content.pages[10][5][2].text = courseplay:loc('COURSEPLAY_AUTOMATIC');
		else		
			vehicle.cp.hud.content.pages[10][5][2].text = ('%i %s'):format(vehicle.cp.speeds.bunkerSilo, courseplay:getSpeedMeasuringUnit());
		end
		if vehicle.cp.mode10.leveling then
			vehicle.cp.hud.content.pages[10][6][1].text = courseplay:loc('COURSEPLAY_MODE10_BLADE_HEIGHT');
			if vehicle.cp.mode10.automaticHeigth then
				vehicle.cp.hud.content.pages[10][6][2].text = courseplay:loc('COURSEPLAY_AUTOMATIC');
			else
				vehicle.cp.hud.content.pages[10][6][2].text = ('%.1f%s'):format(vehicle.cp.mode10.shieldHeight, courseplay:loc('COURSEPLAY_UNIT_METER'));
			end
			vehicle.cp.hud.content.pages[10][1][2].text = courseplay:loc('COURSEPLAY_MODE10_MODE_LEVELING');
			vehicle.cp.hud.content.pages[10][7][1].text = courseplay:loc('COURSEPLAY_MODE10_SILO_LOADEDBY');
			if vehicle.cp.mode10.drivingThroughtLoading then
				vehicle.cp.hud.content.pages[10][7][2].text = courseplay:loc('COURSEPLAY_MODE10_DRIVINGTHROUGH');
			else
				vehicle.cp.hud.content.pages[10][7][2].text = courseplay:loc('COURSEPLAY_MODE10_REVERSE_UNLOADING');
			end
		else
			vehicle.cp.hud.content.pages[10][1][2].text = courseplay:loc('COURSEPLAY_MODE10_MODE_BUILDUP');
		end
		if vehicle.cp.mode10.searchCourseplayersOnly then
			vehicle.cp.hud.content.pages[10][2][2].text = courseplay:loc('COURSEPLAY_MODE10_SEARCH_MODE_CP');
		else
			vehicle.cp.hud.content.pages[10][2][2].text = courseplay:loc('COURSEPLAY_MODE10_SEARCH_MODE_ALL');
		end
	end; -- END if page == n
]]
	self:setReloadPageOrder(vehicle, page, false);
end;
--END updatePageContent

function courseplay.hud:setReloadPageOrder(vehicle, page, bool)
	-- self = courseplay.hud

	if vehicle.cp.hud.reloadPage[page] ~= bool then
		vehicle.cp.hud.reloadPage[page] = bool;
		if courseplay.debugChannels[18] and bool == true then
			courseplay:debug(string.format('%s: set reloadPage[%d]', nameNum(vehicle), page), 18);
		end;
	end;
end;

function courseplay:setFontSettings(color, fontBold, align)
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

function courseplay.hud:setupVehicleHud(vehicle)
	-- self = courseplay.hud
	local wSmall	   = self.buttonSize.small.w;
	local hSmall	   = self.buttonSize.small.h;
	local marginSmall  = self.buttonSize.small.margin;
	local wMiddle	   = self.buttonSize.middle.w;
	local hMiddle	   = self.buttonSize.middle.h;
	local marginMiddle = self.buttonSize.middle.margin;
	local wBig		   = self.buttonSize.big.w;
	local hBig		   = self.buttonSize.big.h;
	local marginBig    = self.buttonSize.big.margin;
	local w32pxConstant, h32pxConstant = self:getPxToNormalConstant(32, 32);

	local gfxPath = Utils.getFilename('img/hud.png', courseplay.path);
	vehicle.cp.hud = {
		bg				  = Overlay:new(gfxPath, self.basePosX, self.basePosY, self.baseWidth, self.baseHeight);
		bgWithModeButtons = Overlay:new(gfxPath, self.basePosX, self.basePosY, self.baseWidth, self.baseHeight);
		suc				  = Overlay:new(gfxPath, self.suc.x1,	  self.suc.y1,	 self.suc.width, self.suc.height);
		currentPage = 1;
		show = false;
		openWithMouse = true;
		showMiniHud = true;
		firstTimeSetContent = true;
		content = {
			bottomInfo = {};
			pages = {};
		};
		mouseWheel = {
			icon = Overlay:new(courseplay.path .. 'img/mouseIcons/mouseMMB.png', 0, 0, w32pxConstant, h32pxConstant); -- FS15
			--icon = InputBinding.controllerSymbols["mouse_MOUSE_BUTTON_MIDDLE"].overlay;
			--width = w32pxConstant;
			--height = h32pxConstant;
			render = false;
		};
	};
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.bg,				   self.baseUVsPx,				  self.baseTextureSize.x, self.baseTextureSize.y);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.bgWithModeButtons, self.baseWithModeButtonsUVsPx, self.baseTextureSize.x, self.baseTextureSize.y);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.suc,			   self.suc.UVsPx,				  self.baseTextureSize.x, self.baseTextureSize.y);



	-- direction arrow to the first/last waypoint (during paused recording)
	vehicle.cp.directionArrowOverlay = Overlay:new(Utils.getFilename('img/arrow.png', courseplay.path), self.directionArrowPosX, self.directionArrowPosY, self.directionArrowWidth, self.directionArrowHeight);

	-- clickable buttons
	vehicle.cp.buttons = {};
	vehicle.cp.buttons.global = {};
	vehicle.cp.buttons.suc = {};
	vehicle.cp.buttons[-2] = {};
		
	for page=0, self.numPages do
		vehicle.cp.buttons[page] = {};
	end;

	-- SeedUsageCalculator
	vehicle.cp.suc = {
		active = false;
		fontSize = self.fontSizes.seedUsageCalculator;
	};
	local lineHeight = vehicle.cp.suc.fontSize;
	local sucVa = self.suc.visibleArea;
	vehicle.cp.suc.textMinX = sucVa.x1 + sucVa.hPadding + self.buttonSize.small.w + self.buttonSize.small.margin + self.buttonSize.small.w + sucVa.hPadding;
	vehicle.cp.suc.textMaxX = sucVa.x2 - sucVa.hPadding;
	vehicle.cp.suc.textMaxWidth = vehicle.cp.suc.textMaxX - vehicle.cp.suc.textMinX;

	vehicle.cp.suc.lines = {};
	vehicle.cp.suc.lines.title = {
		fontSize = vehicle.cp.suc.fontSize * 1.1;
		text = courseplay:loc('COURSEPLAY_SEEDUSAGECALCULATOR');
	};
	vehicle.cp.suc.lines.title.posY = sucVa.y2 - sucVa.vPadding - vehicle.cp.suc.lines.title.fontSize;
	vehicle.cp.suc.lines.field = {
		fontSize = vehicle.cp.suc.fontSize;
		posY = vehicle.cp.suc.lines.title.posY - lineHeight * 1.5;
		text = '';
	};
	vehicle.cp.suc.lines.fruit = {
		fontSize = vehicle.cp.suc.fontSize;
		posY = vehicle.cp.suc.lines.field.posY - lineHeight;
		text = '';
	};
	vehicle.cp.suc.lines.result = {
		fontSize = vehicle.cp.suc.fontSize * 1.05;
		posY = vehicle.cp.suc.lines.fruit.posY - lineHeight * 4/3;
		text = '';
	};
	local w,h = self.buttonSize.small.w, self.buttonSize.small.h;
	local xL = sucVa.x1 + sucVa.hPadding;
	local xR = xL + w + self.buttonSize.small.margin;
	local y = vehicle.cp.suc.lines.fruit.posY - self:pxToNormal(3, 'y');
	vehicle.cp.suc.fruitNegButton = courseplay.button:new(vehicle, 'suc', { 'iconSprite.png', 'navLeft' },  'sucChangeFruit', -1, xL, y, w, h);
	vehicle.cp.suc.fruitPosButton = courseplay.button:new(vehicle, 'suc', { 'iconSprite.png', 'navRight' }, 'sucChangeFruit',  1, xR, y, w, h);
	vehicle.cp.suc.selectedFruitIdx = 1;
	vehicle.cp.suc.selectedFruit = nil;


	-- main hud content
	vehicle.cp.hud.reloadPage = {};
	self:setReloadPageOrder(vehicle, -1, true); --reload all

	for page=0,self.numPages do
		vehicle.cp.hud.content.pages[page] = {};
		for line=1,self.numLines do
			vehicle.cp.hud.content.pages[page][line] = {
				{ text = nil, isClicked = false, isHovered = false, indention = 0 },
				{ text = nil, posX = self.col2posX[page] },
				{ text = nil, posX = Utils.getNoNil( self.col3posX[page], 0 ) }
			};
			if self.col2posXforce[page] ~= nil and self.col2posXforce[page][line] ~= nil then
				vehicle.cp.hud.content.pages[page][line][2].posX = self.col2posXforce[page][line];
			end;
		end;
	end;
	
	-- course list
	vehicle.cp.hud.filterEnabled = true;
	vehicle.cp.hud.filter = "";
	vehicle.cp.hud.choose_parent = false
	vehicle.cp.hud.showFoldersOnly = false
	vehicle.cp.hud.showZeroLevelFolder = false
	vehicle.cp.hud.courses = {}
	--vehicle.cp.hud.courseListPrev = false;
	--vehicle.cp.hud.courseListNext = false; -- will be updated after loading courses into the hud

	--Camera backups: allowTranslation
	vehicle.cp.camerasBackup = {};
	for camIndex, camera in pairs(vehicle.spec_enterable.cameras) do
		if camera.allowTranslation then
			vehicle.cp.camerasBackup[camIndex] = camera.allowTranslation;
		end;
	end;

	--[[
	--default hud conditional variables
	vehicle.cp.HUD0noCourseplayer = false;
	vehicle.cp.HUD0wantsCourseplayer = false;
	vehicle.cp.HUD0tractorName = "";
	vehicle.cp.HUD0tractorForcedToStop = false;
	vehicle.cp.HUD0tractor = false;
	vehicle.cp.HUD0combineForcedSide = nil;
	vehicle.cp.HUD0isManual = false;
	vehicle.cp.HUD0turnStage = 0;
	vehicle.cp.HUD1notDrive = false;
	vehicle.cp.HUD1wait = false;
	vehicle.cp.HUD1noWaitforFill = false;
	vehicle.cp.HUD4combineName = "";
	vehicle.cp.HUD4hasActiveCombine = false;
	vehicle.cp.HUD4savedCombine = nil;
	vehicle.cp.HUD4savedCombineName = "";

	]]
	vehicle.cp.attachedCombine = nil;
	
	local mouseWheelArea = {
		x = self.contentMinX,
		w = self.contentMaxWidth,
		h = self.lineHeight
	};

	local listArrowX = self.contentMaxX - wMiddle;
	local topIconsX = {};
	topIconsX[3] = listArrowX - wSmall - wMiddle;
	topIconsX[2] = topIconsX[3] - wSmall - wMiddle;
	topIconsX[1] = topIconsX[2] - wSmall - wMiddle;
	topIconsX[0] = topIconsX[1] - wSmall - wMiddle;

	-- ##################################################
	-- Global
	vehicle.cp.hud.hudPageButtons ={}
	local posY = self.basePosY + self:pxToNormal(300, 'y');
	local totalWidth = ((self.numPages + 1) * wBig) + (self.numPages * marginBig); --numPages=9, real numPages=10
	local baseX = self.baseCenterPosX - totalWidth/2;
	for p=0, self.numPages do
		local posX = baseX + (p * (wBig + marginBig));
		local toolTip = self.pageTitles[p];
		if p == 2 then
			toolTip = self.pageTitles[p][1];
		end;
		vehicle.cp.hud.hudPageButtons[p] = courseplay.button:new(vehicle, 'global', 'iconSprite.png', 'setHudPage', p, posX, posY, wBig, hBig, nil, nil, false, false, false, toolTip);
	end;

	local closeX = self.visibleArea.x2 - marginMiddle - wMiddle;
	local closeY = self.basePosY + self:pxToNormal(280, 'y');
	courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'close' }, 'openCloseHud', false, closeX, closeY, wMiddle, hMiddle);

	vehicle.cp.hud.saveCourseButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'save' }, 'showSaveCourseForm', 'course', topIconsX[3], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_SAVE_CURRENT_COURSE'));
	vehicle.cp.hud.clearCurrentCourseButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'courseClear' }, 'clearCurrentLoadedCourse', nil, topIconsX[0], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_CLEAR_COURSE'));
	vehicle.cp.hud.changeDrawCourseModeButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'eye' }, 'changeDrawCourseMode', 1, self.col1posX, self.topIconsY, wMiddle, hMiddle, nil, -1, false, false, true);
	self:setupCpModeButtons(vehicle)
	self:setupRecordingButtons(vehicle)
	self:setupCoursePageButtons(vehicle,2)

	-- ##################################################
	-- Page 0: Combine controls
	--[[for i=1, self.numLines do
		if ( i == 7 ) then
			courseplay.button:new(vehicle, 0, nil, 'changeHeadlandReverseManeuverType', nil, self.col1posX, self.linesPosY[i], self.contentMaxWidth, self.lineHeight, i, nil, true);
		else
			courseplay.button:new(vehicle, 0, nil, "rowButton", i, self.basePosX, self.linesPosY[i], self.contentMaxWidth, self.lineHeight, i, nil, true);
		end
	end;]]


	-- ##################################################
	-- Page 1


	--[[ 
	
	-- Custom field edge path
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'cancel' }, 'clearCustomFieldEdge', nil, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'eye' }, 'toggleCustomFieldEdgePathShow', nil, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);

	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navMinus' }, 'setCustomFieldEdgePathNumber', -1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, -5, false);
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navPlus' },  'setCustomFieldEdgePathNumber',  1, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4,  5, false);
	courseplay.button:new(vehicle, 1, nil, 'setCustomFieldEdgePathNumber', 1, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	-- Find first waypoint
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'search' }, 'toggleFindFirstWaypoint', nil, topIconsX[1], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, true, courseplay:loc('COURSEPLAY_SEARCH_FOR_FIRST_WAYPOINT'));


	--go to pipe position in mode3
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'recordingPlay' }, 'movePipeToPosition', 1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, nil, true, false, false, courseplay:loc('COURSEPLAY_MOVE_PIPE_TO_POSITION'));
					
	-- ##################################################

	-- Page 3
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navMinus' }, 'changeCombineOffset', -0.1, self.buttonPosX[2], self.linesButtonPosY[1], wSmall, hSmall, 1, -0.5, false);
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navPlus' },  'changeCombineOffset',  0.1, self.buttonPosX[1], self.linesButtonPosY[1], wSmall, hSmall, 1,  0.5, false);
	courseplay.button:new(vehicle, 3, nil, 'changeCombineOffset', 0.1, mouseWheelArea.x, self.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);
	courseplay.button:new(vehicle, 3, nil, 'rowButton', 1, self.basePosX, self.linesButtonPosY[1], self.contentMaxWidth, self.lineHeight, 1, nil, true);

	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navMinus' }, 'changeTipperOffset', -0.1, self.buttonPosX[2], self.linesButtonPosY[2], wSmall, hSmall, 2, -0.5, false);
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navPlus' },  'changeTipperOffset',  0.1, self.buttonPosX[1], self.linesButtonPosY[2], wSmall, hSmall, 2,  0.5, false);
	courseplay.button:new(vehicle, 3, nil, 'changeTipperOffset', 0.1, mouseWheelArea.x, self.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);
	courseplay.button:new(vehicle, 3, nil, 'rowButton', 2, self.basePosX, self.linesButtonPosY[2], self.contentMaxWidth, self.lineHeight, 2, nil, true);


	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navMinus' }, 'changeFollowAtFillLevel', -5, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, -10, false);
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navPlus' },  'changeFollowAtFillLevel',  5, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4,  10, false);
	courseplay.button:new(vehicle, 3, nil, 'changeFollowAtFillLevel', 5, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 10, true, true);

	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navMinus' }, 'changeDriveOnAtFillLevel', -5, self.buttonPosX[2], self.linesButtonPosY[5], wSmall, hSmall, 5, -10, false);
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navPlus' },  'changeDriveOnAtFillLevel',  5, self.buttonPosX[1], self.linesButtonPosY[5], wSmall, hSmall, 5,  10, false);
	courseplay.button:new(vehicle, 3, nil, 'changeDriveOnAtFillLevel', 5, mouseWheelArea.x, self.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 10, true, true);

	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navMinus' }, 'changeRefillUntilPct', -1, self.buttonPosX[2], self.linesButtonPosY[6], wSmall, hSmall, 6, -5, false);
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navPlus' },  'changeRefillUntilPct',  1, self.buttonPosX[1], self.linesButtonPosY[6], wSmall, hSmall, 6,  5, false);
	courseplay.button:new(vehicle, 3, nil, 'changeRefillUntilPct', 1, mouseWheelArea.x, self.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, 5, true, true);
	
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navMinus' }, 'changeLastValidTipDistance', -0.5, self.buttonPosX[2], self.linesButtonPosY[6], wSmall, hSmall, 6, -2, false);
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navPlus' },  'changeLastValidTipDistance',  0.5, self.buttonPosX[1], self.linesButtonPosY[6], wSmall, hSmall, 6,  2, false);
	courseplay.button:new(vehicle, 3, nil, 'changeLastValidTipDistance', 0.5, mouseWheelArea.x, self.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, 2, true, true);

	-- Plow to Field Edge
	courseplay.button:new(vehicle, 3, nil, 'togglePlowFieldEdge', nil,  self.contentMinX, self.linesPosY[7], self.contentMaxWidth, self.lineHeight, 7, nil, true);
	courseplay.button:new(vehicle, 3, nil, 'toggleAlignmentWaypoint', nil,  self.contentMinX, self.linesPosY[8], self.contentMaxWidth, self.lineHeight, 8, nil, true);


	-- ##################################################
	-- Page 4: Combine management
	courseplay.button:new(vehicle, 4, nil, 'toggleSearchCombineMode', nil, self.col1posX, self.linesPosY[1], self.visibleArea.width, self.lineHeight, 1, nil, true);

	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navUp' },   'selectAssignedCombine', -1, self.buttonPosX[2], self.linesButtonPosY[2], wSmall, hSmall, 2, nil, false);
	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navDown' }, 'selectAssignedCombine',  1, self.buttonPosX[1], self.linesButtonPosY[2], wSmall, hSmall, 2, nil, false);
	courseplay.button:new(vehicle, 4, nil, 'selectAssignedCombine', -1, mouseWheelArea.x, self.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, -1, true, true);
	
	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navUp' },   'setSearchCombineOnField', 1, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);
	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navDown' }, 'setSearchCombineOnField',  -1, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);
	courseplay.button:new(vehicle, 4, nil, 'setSearchCombineOnField', 1, mouseWheelArea.x, self.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);
	

	courseplay.button:new(vehicle, 4, nil, 'removeActiveCombineFromTractor', nil, self.col1posX, self.linesPosY[5], self.contentMaxWidth, self.lineHeight, 5, nil, true);


-- 4WD button in line 5: only added if driveControl and 4WD exist
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navLeft' },  'changeDriveControlMode', -1, self.buttonPosX[2], self.linesButtonPosY[7], wSmall, hSmall, 7, -1, false);
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navRight' }, 'changeDriveControlMode',  1, self.buttonPosX[1], self.linesButtonPosY[7], wSmall, hSmall, 7, -1, false);


	
	-- ##################################################
	-- Page 8: Course generation
	-- Note: line 1 (field edges) will be applied in first updateTick() runthrough

	-- line 2 (workWidth)
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'calculator' }, 'calculateWorkWidth', nil, self.buttonPosX[3], self.linesButtonPosY[2], wSmall, hSmall, 2, nil, false);
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navMinus' }, 'changeWorkWidth', -0.1, self.buttonPosX[2], self.linesButtonPosY[2], wSmall, hSmall, 2, -0.5, false);
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navPlus' },  'changeWorkWidth',  0.1, self.buttonPosX[1], self.linesButtonPosY[2], wSmall, hSmall, 2,  0.5, false);
	courseplay.button:new(vehicle, 8, nil, 'changeWorkWidth', 0.1, mouseWheelArea.x, self.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);

	-- line 3 (starting corner)
	courseplay.button:new(vehicle, 8, nil, 'switchStartingCorner',     nil, self.col1posX, self.linesPosY[3], self.contentMaxWidth, self.lineHeight, 3, nil, true);

	-- line 4 (starting direction)
	courseplay.button:new(vehicle, 8, nil, 'changeStartingDirection',  nil, self.col1posX, self.linesPosY[4], self.col3posX[ self.PAGE_COURSE_GENERATION ] - self.col1posX, self.lineHeight, 4, nil, true);
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navUp' },   'changeRowAngle',  22.5, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, nil, false);
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navDown' }, 'changeRowAngle', -22.5, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4, nil, false);
	courseplay.button:new(vehicle, 8, nil, 'changeRowAngle', 1, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 0.5, true, true);
	-- line 5 (return to first point)
	courseplay.button:new(vehicle, 8, nil, 'toggleReturnToFirstPoint', nil, self.col1posX, self.linesPosY[5], self.contentMaxWidth, self.lineHeight, 5, nil, true);

	-- line 6 (headland)
	-- 6.2 turn type

	-- 6.3: order, direction, numLanes
	local orderBtnX = vehicle.cp.hud.content.pages[8][6][3].posX - self.buttonSize.small.margin - wBig;
	local dirBtnX = orderBtnX - self:pxToNormal(4, 'x') - wSmall;
	vehicle.cp.headland.orderButton = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'headlandOrdBef' }, 'toggleHeadlandOrder', nil, orderBtnX, self.linesButtonPosY[6], wBig, hSmall, 6, nil, false, nil, nil, courseplay:loc('COURSEPLAY_HEADLAND_BEFORE_AFTER'));
	vehicle.cp.headland.directionButton = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'headlandDirCW' }, 'toggleHeadlandDirection', nil, dirBtnX, self.linesButtonPosY[6], wSmall, hSmall, 6, nil, false, nil, nil, courseplay:loc('COURSEPLAY_HEADLAND_DIRECTION'));
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navUp' },   'changeHeadlandNumLanes',   1, self.buttonPosX[2], self.linesButtonPosY[6], wSmall, hSmall, 6, nil, false);
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navDown' }, 'changeHeadlandNumLanes',  -1, self.buttonPosX[1], self.linesButtonPosY[6], wSmall, hSmall, 6, nil, false);
	courseplay.button:new(vehicle, 8, nil, 'changeHeadlandTurnType', nil, self.col1posX, self.linesPosY[6], self.col3posX[ self.PAGE_COURSE_GENERATION ] - self.col1posX, self.lineHeight, 6, nil, true);

	-- line 7 (islands)
	courseplay.button:new(vehicle, 8, nil, 'changeIslandBypassMode',  nil, self.col1posX, self.linesPosY[7], self.contentMaxWidth, self.lineHeight, 7, nil, true);
	
	-- line 8 multi tools
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navDown' }, 'changeByMultiTools', -1, self.buttonPosX[2], self.linesButtonPosY[8], wSmall, hSmall, 8,  nil, false);
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navUp' },   'changeByMultiTools',  1, self.buttonPosX[1], self.linesButtonPosY[8], wSmall, hSmall, 8,  nil, false);
	courseplay.button:new(vehicle, 8, nil, 'changeByMultiTools',1, mouseWheelArea.x, self.linesButtonPosY[8], mouseWheelArea.w, mouseWheelArea.h, 8, nil, true, true);

	-- generation action button
	local toolTip = courseplay:loc('COURSEPLAY_GENERATE_FIELD_COURSE');
	vehicle.cp.hud.generateCourseButton = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'generateCourse' }, 'generateCourse', nil, topIconsX[2], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, toolTip);

	

	-- Clear current course
	vehicle.cp.hud.clearCurrentCourseButton8 = courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'courseClear' }, 'clearCurrentLoadedCourse', nil, topIconsX[0], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_CLEAR_COURSE'));


	-- ##################################################
	-- Page 9: Shovel settings
	local pg = self.PAGE_SHOVEL_POSITIONS;
	local btnW = self:pxToNormal(22, 'x');
	local btnH = self:pxToNormal(22, 'y');
	local shovelX1 = self.col2posX[pg] - btnW * 2;
	local shovelX2 = self.col2posX[pg] + btnW * 3;
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'shovelLoading'   }, 'saveShovelPosition', 2, shovelX1, self.linesButtonPosY[1], btnW, btnH, 1, nil, true, false, true, courseplay:loc('COURSEPLAY_SHOVEL_SAVE_LOADING_POSITION'));
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'shovelTransport' }, 'saveShovelPosition', 3, shovelX1, self.linesButtonPosY[2], btnW, btnH, 2, nil, true, false, true, courseplay:loc('COURSEPLAY_SHOVEL_SAVE_TRANSPORT_POSITION'));
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'shovelPreUnload' }, 'saveShovelPosition', 4, shovelX1, self.linesButtonPosY[3], btnW, btnH, 3, nil, true, false, true, courseplay:loc('COURSEPLAY_SHOVEL_SAVE_PRE_UNLOADING_POSITION'));
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'shovelUnloading' }, 'saveShovelPosition', 5, shovelX1, self.linesButtonPosY[4], btnW, btnH, 4, nil, true, false, true, courseplay:loc('COURSEPLAY_SHOVEL_SAVE_UNLOADING_POSITION'));

	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'recordingPlay' }, 'moveShovelToPosition', 2, shovelX2, self.linesButtonPosY[1], wSmall, hSmall, 1, nil, true, false, false, courseplay:loc('COURSEPLAY_SHOVEL_MOVE_TO_LOADING_POSITION'));
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'recordingPlay' }, 'moveShovelToPosition', 3, shovelX2, self.linesButtonPosY[2], wSmall, hSmall, 2, nil, true, false, false, courseplay:loc('COURSEPLAY_SHOVEL_MOVE_TO_TRANSPORT_POSITION'));
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'recordingPlay' }, 'moveShovelToPosition', 4, shovelX2, self.linesButtonPosY[3], wSmall, hSmall, 3, nil, true, false, false, courseplay:loc('COURSEPLAY_SHOVEL_MOVE_TO_PRE_UNLOADING_POSITION'));
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'recordingPlay' }, 'moveShovelToPosition', 5, shovelX2, self.linesButtonPosY[4], wSmall, hSmall, 4, nil, true, false, false, courseplay:loc('COURSEPLAY_SHOVEL_MOVE_TO_UNLOADING_POSITION'));

	courseplay.button:new(vehicle, pg, nil, 'toggleShovelStopAndGo', nil, self.col1posX, self.linesPosY[5], self.visibleArea.width, self.lineHeight, 5, nil, true);
	
	
	courseplay.button:new(vehicle, 9, { 'iconSprite.png', 'calculator' }, 'calculateWorkWidth', nil, self.buttonPosX[3], self.linesButtonPosY[6], wSmall, hSmall, 6, nil, false);
	courseplay.button:new(vehicle, 9, { 'iconSprite.png', 'navMinus' }, 'changeWorkWidth', -0.1, self.buttonPosX[2], self.linesButtonPosY[6], wSmall, hSmall, 6, -0.5, false);
	courseplay.button:new(vehicle, 9, { 'iconSprite.png', 'navPlus' },  'changeWorkWidth',  0.1, self.buttonPosX[1], self.linesButtonPosY[6], wSmall, hSmall, 6,  0.5, false);
	courseplay.button:new(vehicle, 9, nil, 'changeWorkWidth', 0.1, mouseWheelArea.x, self.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, 0.5, true, true);
	--END Page 9
	
	
	-- ##################################################
	-- Page 10: BunkerSilo settings
	-- line 1 mode
		courseplay.button:new(vehicle, 10, nil, 'rowButton', 1, self.col1posX, self.linesPosY[1], w, self.lineHeight, 1, nil, true);
	-- line 2
		courseplay.button:new(vehicle, 10, nil, 'rowButton', 2, self.col1posX, self.linesPosY[2], w, self.lineHeight, 2, nil, true);
	-- line 3 
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navMinus' }, 'changeMode10Radius', -5, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3, -10, false);
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navPlus' },  'changeMode10Radius',  5, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3,  10, false);
	courseplay.button:new(vehicle, 10, nil, 'changeMode10Radius', 5, mouseWheelArea.x, self.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 10, true, true);
	--line4 workwidth
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navMinus' }, 'changeWorkWidth', -0.1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, -0.5, false);
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navPlus' },  'changeWorkWidth',  0.1, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4,  0.5, false);
	courseplay.button:new(vehicle, 10, nil, 'changeWorkWidth', 0.1, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 0.5, true, true);
	--line5 bunkerSpeed
	courseplay.button:new(vehicle, 10, nil, 'rowButton', 5, self.col1posX, self.linesPosY[5], w, self.lineHeight, 5, nil, true);
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navMinus' }, 'changeBunkerSpeed', -1, self.buttonPosX[2], self.linesButtonPosY[5], wSmall, hSmall, 5, -0.5, false);
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navPlus' },  'changeBunkerSpeed',  1, self.buttonPosX[1], self.linesButtonPosY[5], wSmall, hSmall, 5,  0.5, false);
	courseplay.button:new(vehicle, 10, nil, 'changeBunkerSpeed', 1, mouseWheelArea.x, self.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 0.5, true, true);
	--line6 leveler
	courseplay.button:new(vehicle, 10, nil, 'rowButton', 6, self.col1posX, self.linesPosY[6], w, self.lineHeight, 6, nil, true);
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navMinus' }, 'changeShieldHeight', -0.1, self.buttonPosX[2], self.linesButtonPosY[6], wSmall, hSmall, 6, -0.5, false);
	courseplay.button:new(vehicle, 10, { 'iconSprite.png', 'navPlus' },  'changeShieldHeight',  0.1, self.buttonPosX[1], self.linesButtonPosY[6], wSmall, hSmall, 6,  0.5, false);
	courseplay.button:new(vehicle, 10, nil, 'changeShieldHeight', 0.1, mouseWheelArea.x, self.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, 0.05, true, true);
	--line7 driveThroughtLoading
	courseplay.button:new(vehicle, 10, nil, 'rowButton', 7, self.col1posX, self.linesPosY[7], w, self.lineHeight, 7, nil, true);
	]]
	-- ##################################################
	-- Status icons
	local bi = self.bottomInfo;
	local w = bi.iconWidth;
	local h = bi.iconHeight;
	local sizeX,sizeY = self.iconSpriteSize.x, self.iconSpriteSize.y;
	-- current mode icon
	vehicle.cp.hud.currentModeIcon = Overlay:new( self.iconSpritePath, bi.modeIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.currentModeIcon, bi.modeUVsPx[vehicle.cp.mode], sizeX, sizeY);

	-- waypoint icon
	vehicle.cp.hud.currentWaypointIcon = Overlay:new( self.iconSpritePath, bi.waypointIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.currentWaypointIcon, { 4, 180, 36, 148 }, sizeX, sizeY);

	-- waitPoints icon
	vehicle.cp.hud.waitPointsIcon = Overlay:new( self.iconSpritePath, bi.waitPointsIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.waitPointsIcon, self.buttonUVsPx['recordingWait'], sizeX, sizeY);

	-- crossingPoints icon
	vehicle.cp.hud.crossingPointsIcon = Overlay:new( self.iconSpritePath, bi.crossingPointsIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.crossingPointsIcon, self.buttonUVsPx['recordingCross'], sizeX, sizeY);

	-- toolTip icon
	vehicle.cp.hud.toolTipIcon = Overlay:new(self.iconSpritePath, self.toolTipIconPosX, self.toolTipIconPosY, self.toolTipIconWidth, self.toolTipIconHeight);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.toolTipIcon, { 112, 180, 144, 148 }, sizeX, sizeY);
end;
--END setupVehicleHud



--setup functions 
function courseplay.hud:setupCpModeButtons(vehicle)
	-- setCpMode buttons
	local totalWidth = (courseplay.NUM_MODES * self.buttonSize.big.w) + ((courseplay.NUM_MODES - 1) * self.buttonSize.big.margin);
	local baseX = self.baseCenterPosX - totalWidth/2;
	local y = self.linesButtonPosY[8] + self:pxToNormal(2, 'y');
	for i=1, courseplay.NUM_MODES do
		local posX = baseX + ((i - 1) * (self.buttonSize.big.w + self.buttonSize.big.margin));
		local toolTip = courseplay:loc(('COURSEPLAY_MODE_%d'):format(i));
		local button = courseplay.button:new(vehicle, 'global', 'iconSprite.png', 'setCpMode', i, posX, y, self.buttonSize.big.w, self.buttonSize.big.h, nil, nil, false, false, false, toolTip);
		button:setActive(i == vehicle.cp.mode)
	end;
end

function courseplay.hud:setupDebugButtons(vehicle,debugButtonOnPage)
	-- debug channels
	if courseplay.isDevVersion then 
		vehicle.cp.hud.debugChannelButtons = {};
		local mouseWheelArea = {
			x = self.contentMinX,
			w = self.contentMaxWidth,
			h = self.lineHeight
			};
		
		
		for dbg=1, courseplay.numDebugChannelButtonsPerLine do
			local data = courseplay.debugButtonPosData[dbg];
			local toolTip = courseplay.debugChannelsDesc[dbg];
			vehicle.cp.hud.debugChannelButtons[dbg] = courseplay.button:new(vehicle, debugButtonOnPage, 'iconSprite.png', 'toggleDebugChannel', dbg, data.posX, data.posY, data.width, data.height, nil, nil, nil, false, false, toolTip);
		end;
		courseplay.button:new(vehicle, debugButtonOnPage, { 'iconSprite.png', 'navUp' },   'changeDebugChannelSection', -1, self.buttonPosX[2], self.linesButtonPosY[8], self.buttonSize.small.w, self.buttonSize.small.h, debugButtonOnPage, -1, true, false);
		courseplay.button:new(vehicle, debugButtonOnPage, { 'iconSprite.png', 'navDown' }, 'changeDebugChannelSection',  1, self.buttonPosX[1], self.linesButtonPosY[8], self.buttonSize.small.w, self.buttonSize.small.h, debugButtonOnPage,  1, true, false);
		courseplay.button:new(vehicle, debugButtonOnPage, nil, 'changeDebugChannelSection', -1, mouseWheelArea.x, self.linesButtonPosY[8], mouseWheelArea.w, mouseWheelArea.h, debugButtonOnPage, -1, true, true);
	end
end

function courseplay.hud:setupRecordingButtons(vehicle)
	local recordingData = {
		[1] = { 'recordingStop',	 'stop_record',				 nil,  'COURSEPLAY_RECORDING_STOP'			   },
		[2] = { 'recordingPause',	 'setRecordingPause',		 true, 'COURSEPLAY_RECORDING_PAUSE'			   },
		[3] = { 'recordingDelete',	 'delete_waypoint',			 nil,  'COURSEPLAY_RECORDING_DELETE'		   },
		[4] = { 'recordingWait',	 'set_waitpoint',			 nil,  'COURSEPLAY_RECORDING_SET_WAIT'		   },
		[5] = { 'recordingUnload',	 'set_unloadPoint',			 nil,  'COURSEPLAY_RECORDING_SET_UNLOAD'	   },
		[6] = { 'recordingCross',	 'set_crossing',			 nil,  'COURSEPLAY_RECORDING_SET_CROSS'		   },
		[7] = { 'recordingTurn',	 'setRecordingTurnManeuver', true, 'COURSEPLAY_RECORDING_TURN_START'	   },
		[8] = { 'recordingReverse',	 'change_DriveDirection',	 true, 'COURSEPLAY_RECORDING_REVERSE_START'	   },
		[9] = { 'recordingAddSplit', 'addSplitRecordingPoints',	 nil,  'COURSEPLAY_RECORDING_ADD_SPLIT_POINTS' }
	};
	
	local marginBig    = self.buttonSize.big.margin;
	local wBig  = self.buttonSize.big.w;
	local hBig  = self.buttonSize.big.h;
	local totalWidth = (#recordingData - 1) * (wBig + marginBig) + wBig;
	local baseX = self.baseCenterPosX - totalWidth * 0.5;
	
	for i,data in pairs(recordingData) do
		local posX = baseX + ((wBig + marginBig) * (i-1));
		local fn = data[2];
		local isToggleButton = data[3];
		local toolTip = courseplay:loc(data[4]);
		local button = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', data[1] }, fn, nil, posX, self.linesButtonPosY[2], wBig, hBig, nil, nil, false, false, isToggleButton, toolTip);
		button:setShow(false);
		button.isRecordingButton = true;
		if isToggleButton then
			if fn == 'setRecordingPause' then
				vehicle.cp.hud.recordingPauseButton = button;
			elseif fn == 'setRecordingTurnManeuver' then
				vehicle.cp.hud.recordingTurnManeuverButton = button;
			elseif fn == 'change_DriveDirection' then
				vehicle.cp.hud.recordingDriveDirectionButton = button;
			end;
		end;
	end;
end	

function courseplay.hud:setupCopyCourseButton(vehicle,page,line)
	vehicle.cp.hud.copyCourseButton = courseplay.button:new(vehicle, page, { 'iconSprite.png', 'copy' }, 'copyCourse', nil, self.buttonPosX[3], self.linesButtonPosY[line], self.buttonSize.small.w, self.buttonSize.small.h);
end

function courseplay.hud:setupCoursePageButtons(vehicle,page)
	local wMiddle	   = self.buttonSize.middle.w;
	local hMiddle	   = self.buttonSize.middle.h;
	local wSmall	   = self.buttonSize.small.w;
	local hSmall	   = self.buttonSize.small.h;
	local arrowPosYTop = self.linesButtonPosY[1];
	local arrowPosYBottom = self.linesButtonPosY[1];
	local listArrowX = self.contentMaxX - wMiddle;
	local topIconsX = {};
	topIconsX[3] = listArrowX - wSmall - wMiddle;
	topIconsX[2] = topIconsX[3] - wSmall - wMiddle;
	topIconsX[1] = topIconsX[2] - wSmall - wMiddle;
	topIconsX[0] = topIconsX[1] - wSmall - wMiddle;
	
	local mouseWheelArea = {
		x = self.contentMinX,
		w = self.contentMaxWidth,
		h = self.lineHeight
	}
	local courseListMouseWheelArea = {
		x = self.contentMinX,
		y = self.linesPosY[self.numLines],
		width = self.buttonCoursesPosX[4] - self.contentMinX,
		height = self.linesPosY[1] + self.lineHeight - self.linesPosY[self.numLines]
	};
	vehicle.cp.hud.courseListMouseArea= courseplay.button:new(vehicle, 'global', nil, 'shiftHudCourses', -1, courseListMouseWheelArea.x, courseListMouseWheelArea.y, courseListMouseWheelArea.width, courseListMouseWheelArea.height, nil, -self.numLines, true, true); 
	
	-- courser actions
	local hoverAreaWidth = self.buttonCoursesPosX[page] + wSmall - self.buttonCoursesPosX[4];
	if g_server ~= nil then
		hoverAreaWidth = self.buttonCoursesPosX[1] + wSmall - self.buttonCoursesPosX[4];
	end;
	for i=1, self.numLines do
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'navPlus' }, 'expandFolder', i, self.buttonCoursesPosX[0], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false);
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'courseLoadAppend' }, 'loadSortedCourse', i, self.buttonCoursesPosX[4], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_LOAD_COURSE'));
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'courseAdd' }, 'addSortedCourse', i, self.buttonCoursesPosX[3], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_APPEND_COURSE'));
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'folderParentFrom' }, 'linkParent', i, self.buttonCoursesPosX[2], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_MOVE_TO_FOLDER'));
		if g_server ~= nil then
			courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'delete' }, 'deleteSortedItem', i, self.buttonCoursesPosX[1], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_DELETE_COURSE'));
		end;
		courseplay.button:new(vehicle, -2, nil, nil, nil, self.buttonCoursesPosX[4], self.linesButtonPosY[i], hoverAreaWidth, mouseWheelArea.h, i, nil, true, false);
	end;
	vehicle.cp.hud.filterButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'search' }, 'showSaveCourseForm', 'filter', topIconsX[1], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_SEARCH_FOR_COURSES_AND_FOLDERS'));
	vehicle.cp.hud.newFolderButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'folderNew' }, 'showSaveCourseForm', 'folder', topIconsX[2], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_CREATE_FOLDER'));
	vehicle.cp.hud.reloadCourses = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'refresh' }, 'reloadCoursesFromXML', nil, topIconsX[0], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_RELOAD_COURSE_LIST'));
	vehicle.cp.hud.courseListPrevButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'navUp' },   'shiftHudCourses', -self.numLines, listArrowX, self.linesButtonPosY[1],			   wMiddle, hMiddle, nil, -self.numLines*2);
	vehicle.cp.hud.courseListNextButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'navDown' }, 'shiftHudCourses',  self.numLines, listArrowX, self.linesButtonPosY[self.numLines], wMiddle, hMiddle, nil,  self.numLines*2);
end

function courseplay.hud:setupShowWaypointsButtons(vehicle,page,line)
	local btnW = self.buttonSize.small.w * 2 + self.buttonSize.small.w/8;
	local hSmall = self.buttonSize.small.h;
	local wSmall	   = self.buttonSize.small.w;
	vehicle.cp.hud.visualWaypointsStartButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'waypointSignsStart' }, 'toggleShowVisualWaypointsStartEnd', nil, self.col2posX[page], self.linesButtonPosY[line], btnW, hSmall, nil, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_STARTEND'));
	vehicle.cp.hud.visualWaypointsAllButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'waypointSignsAll' }, 'toggleShowVisualWaypointsAll', nil, self.col2posX[page] + btnW * 1.5, self.linesButtonPosY[line], btnW, hSmall, nil, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_ALL'));
	vehicle.cp.hud.visualWaypointsEndButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'waypointSignsEnd' }, 'toggleShowVisualWaypointsStartEnd', nil, self.col2posX[page] + btnW * 3, self.linesButtonPosY[line], btnW, hSmall, nil, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_STARTEND'));
	vehicle.cp.hud.visualWaypointsCrossingButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'recordingCross' }, 'toggleShowVisualWaypointsCrossing', nil, self.col2posX[page] + btnW * 4.5, self.linesButtonPosY[line], wSmall, hSmall, nil, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_CROSSING'));
	vehicle.cp.hud.visualWaypointsStartButton:setShow(false)
	vehicle.cp.hud.visualWaypointsAllButton:setShow(false)
	vehicle.cp.hud.visualWaypointsEndButton:setShow(false)
	vehicle.cp.hud.visualWaypointsCrossingButton:setShow(false)
end

function courseplay.hud:setupCourseGeneratorButton(vehicle)
	local toolTip = courseplay:loc('COURSEPLAY_ADVANCED_COURSE_GENERATOR_SETTINGS');
	vehicle.cp.hud.advancedCourseGeneratorSettingsButton =
		courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'courseGenSettings' }, 'openAdvancedCourseGeneratorSettings', nil, topIconsX[1], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, toolTip);
end

function courseplay.hud:setupCalculateWorkWidthButton(vehicle,page,line)
	courseplay.button:new(vehicle, page, { 'iconSprite.png', 'calculator' }, 'calculateWorkWidth', nil, self.buttonPosX[3], self.linesButtonPosY[line], self.buttonSize.small.w, self.buttonSize.small.h, line, nil, false);
end

--update functions 
function courseplay.hud:updateCourseList(vehicle, page)
	-- update courses?
	if vehicle.cp.reloadCourseItems then
		courseplay.courses:reloadVehicleCourses(vehicle)
		CourseplayEvent.sendEvent(vehicle,'self.cp.onMpSetCourses',true)
	end
	-- end update courses

	local numCourses = #(vehicle.cp.hud.courses)

	-- set line text
	local courseName = ''
	for line = 1, numCourses do
		courseName = vehicle.cp.hud.courses[line].displayname
		if courseName == nil or courseName == '' then
			courseName = '-';
		end;
		vehicle.cp.hud.content.pages[page][line][1].text = courseName;
		if vehicle.cp.hud.courses[line].type == 'course' then
			vehicle.cp.hud.content.pages[page][line][1].indention = vehicle.cp.hud.courses[line].level * self.indent;
		else
			vehicle.cp.hud.content.pages[page][line][1].indention = (vehicle.cp.hud.courses[line].level + 1) * self.indent;
		end
	end;
	for line = numCourses+1, self.numLines do
		vehicle.cp.hud.content.pages[page][line][1].text = nil;
	end
end

function courseplay.hud:updateDebugChannelButtons(vehicle)
	for _,button in pairs(vehicle.cp.buttons[6]) do
		if button.functionToCall == 'toggleDebugChannel' then
			button:setDisabled(button.parameter > courseplay.numDebugChannels);
			button:setActive(courseplay.debugChannels[button.parameter] == true);
			button:setCanBeClicked(not button.isDisabled);
		end;
	end;
end

function courseplay.hud:updateCourseButtonsVisibilty(vehicle)
	local enable, show = true, true;
	local numVisibleCourses = #(vehicle.cp.hud.courses);
	local nofolders = nil == next(g_currentMission.cp_folders);
	local indent = courseplay.hud.indent;
	local row, fn;
	for _, button in pairs(vehicle.cp.buttons[-2]) do
		row = button.row;
		fn = button.functionToCall;
		enable = true;
		show = true;

		if row > numVisibleCourses then
			show = false;
		else
			if fn == 'expandFolder' then
				if vehicle.cp.hud.courses[row].type == 'course' then
					show = false;
				else
					-- position the expandFolder buttons
					button:setOffset(vehicle.cp.hud.courses[row].level * indent, 0)
					
					if vehicle.cp.hud.courses[row].id == 0 then
						show = false; --hide for level 0 'folder'
					else
						-- check if plus or minus should show up
						if vehicle.cp.folder_settings[vehicle.cp.hud.courses[row].id].showChildren then
							button:setSpriteSectionUVs('navMinus');
						else
							button:setSpriteSectionUVs('navPlus');
						end;
						if g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild == 0 then
							enable = false; -- button has no children
						end;
					end;
				end;
			else
				if vehicle.cp.hud.courses[row].type == 'folder' and (fn == 'loadSortedCourse' or fn == 'addSortedCourse') then
					show = false;
				elseif vehicle.cp.hud.choose_parent ~= true then
					if fn == 'deleteSortedItem' and vehicle.cp.hud.courses[row].type == 'folder' and g_currentMission.cp_sorted.info[ vehicle.cp.hud.courses[row].uid ].lastChild ~= 0 then
						enable = false;
					elseif fn == 'linkParent' then
						button:setSpriteSectionUVs('folderParentFrom');
						if nofolders then
							enable = false;
						end;
					elseif vehicle.cp.hud.courses[row].type == 'course' and (fn == 'loadSortedCourse' or fn == 'addSortedCourse' or fn == 'deleteSortedItem') and vehicle.cp.isDriving then
						enable = false;
					end;
				else
					if fn ~= 'linkParent' then
						enable = false;
					else
						button:setSpriteSectionUVs('folderParentTo');
					end;
				end;
			end;
		end;

		button:setDisabled(not enable or not show);
		button:setShow(show);
	end; -- for buttons
	
end	

function courseplay.hud:showShiftHudButtons(vehicle, show)
	local previousLine, nextLine = courseplay.settings.validateCourseListArrows(vehicle);
	vehicle.cp.hud.courseListPrevButton:setShow(previousLine and show) 
	vehicle.cp.hud.courseListNextButton:setShow(nextLine and show) 
	vehicle.cp.hud.courseListMouseArea:setShow(show) 
end

-- Hud content functions
function courseplay.hud:showCpModeButtons(vehicle, show)
	for _,button in pairs(vehicle.cp.buttons.global) do
		local fn, cpModeToCheck = button.functionToCall, button.parameter;
		if fn == 'setCpMode'then
			button:setShow(show);
			button:setDisabled(not courseplay:getIsToolCombiValidForCpMode(vehicle,cpModeToCheck))
			button:setActive(cpModeToCheck == vehicle.cp.mode)
		end
	end
end

function courseplay.hud:showShowWaypointsButtons(vehicle, show)
	vehicle.cp.hud.visualWaypointsStartButton:setShow(show)
	vehicle.cp.hud.visualWaypointsAllButton:setShow(show)
	vehicle.cp.hud.visualWaypointsEndButton:setShow(show)
	vehicle.cp.hud.visualWaypointsCrossingButton:setShow(show)
end

function courseplay.hud:showRecordingButtons(vehicle, show)
	for _,button in pairs(vehicle.cp.buttons.global) do
		if 	button.isRecordingButton then
			button:setShow(show);
			local fn = button.functionToCall
			
			if fn == 'stop_record' then
				button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
				button:setCanBeClicked(not button.isDisabled);
			elseif fn == 'setRecordingPause' then
				button:setActive(vehicle.cp.recordingIsPaused);
				button:setDisabled(vehicle.cp.waypointIndex < 4 or vehicle.cp.isRecordingTurnManeuver);
				button:setCanBeClicked(not button.isDisabled);
			elseif fn == 'delete_waypoint' then
				button:setDisabled(not vehicle.cp.recordingIsPaused or vehicle.cp.waypointIndex <= 4);
				button:setCanBeClicked(not button.isDisabled);
			elseif fn == 'set_waitpoint' or fn == 'set_crossing' then
				button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
				button:setCanBeClicked(not button.isDisabled);
			elseif fn == 'setRecordingTurnManeuver' then --isToggleButton
				button:setActive(vehicle.cp.isRecordingTurnManeuver);
				button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.drivingDirReverse);
				button:setCanBeClicked(not button.isDisabled);
			elseif fn == 'change_DriveDirection' then --isToggleButton
				button:setActive(vehicle.cp.drivingDirReverse);
				button:setDisabled(vehicle.cp.recordingIsPaused or vehicle.cp.isRecordingTurnManeuver);
				button:setCanBeClicked(not button.isDisabled);
			elseif fn == 'addSplitRecordingPoints' then
				button:setDisabled(not vehicle.cp.recordingIsPaused);
				button:setCanBeClicked(not button.isDisabled);
			end;			
		end
	end	
end

function courseplay.hud:enablePageButton(vehicle,pageNumber)
	local button = vehicle.cp.hud.hudPageButtons[pageNumber];
	button:setDisabled(false);
	button:setCanBeClicked(not button.isDisabled);
end

function courseplay.hud:disablePageButtons(vehicle)
	for _,button in pairs(vehicle.cp.hud.hudPageButtons) do
		button:setDisabled(true);
		button:setCanBeClicked(false);
	end;
end

function courseplay.hud:clearHudPageContent(vehicle)
	for hudPage=0,self.numPages do
		vehicle.cp.buttons[hudPage]= {}
		self:deleteAllAssignedFunctions(vehicle,hudPage)
	end
end

function courseplay.hud:deleteAllAssignedFunctions(vehicle,page)
	for line=1,self.numLines do
		for column=1,3 do
			vehicle.cp.hud.content.pages[page][line][column].functionToCall = nil;
		end;
	end;
end

function courseplay.hud:enableButtonsOnThisPage(vehicle,page)
	for _, button in pairs(vehicle.cp.buttons[page])do
		button:setDisabled(false)
	end
end

function courseplay.hud:disableButtonsOnThisPage(vehicle,page)
	for _, button in pairs(vehicle.cp.buttons[page])do
		button:setDisabled(true)
	end
end

function courseplay.hud:enableButtonWithFunction(vehicle,page, func)
	self:debug(vehicle,"enableButton: "..func)
	for _, button in pairs(vehicle.cp.buttons[page])do
		if button.functionToCall == func then
			button:setDisabled(false)
			button:setShow(true)
		end
	end
end

function courseplay.hud:disableButtonWithFunction(vehicle,page, func)
	self:debug(vehicle,"disableButton: "..func)
	for _, button in pairs(vehicle.cp.buttons[page])do
		if button.functionToCall == func then
			button:setDisabled(true)
			button:setShow(false)
		end
	end
end

--call the setup for the different modes
function courseplay.hud:setAIDriverContent(vehicle)
	self:debug(vehicle,"setAIDriverContent")
	self:clearHudPageContent(vehicle)
	self:disablePageButtons(vehicle)
		
	--page 1 driving
	self:enablePageButton(vehicle,1)
	self:addRowButton(vehicle,'startStop', 1, 1, 1 )
	self:addRowButton(vehicle,'start_record', 1, 1, 2 )
	self:addRowButton(vehicle,'cancelWait', 1, 2, 1 )
	self:addRowButton(vehicle,'changeStartAtPoint', 1, 2, 2 )
	self:addRowButton(vehicle,'setStopAtEnd', 1, 3, 1 )
	self:addSettingsRowWithArrows(vehicle,'switchDriverCopy', 1, 3, 2 )
	self:setupCopyCourseButton(vehicle, 1, 3)
	
	
	--page2 courses
	self:enablePageButton(vehicle, 2)
	self:updateCourseList(vehicle, 2)
	
	--page 5 speeds
	self:enablePageButton(vehicle, 5)
	self:addSettingsRow(vehicle,'changeTurnSpeed', 5, 1, 1 )
	self:addSettingsRow(vehicle,'changeFieldSpeed', 5, 2, 1 )
	self:addSettingsRow(vehicle,'changeReverseSpeed', 5, 3, 1 )
	self:addSettingsRow(vehicle,'changeMaxSpeed', 5, 4, 1 ) 
	self:addRowButton(vehicle,'toggleUseRecordingSpeed', 5, 5, 1 ) 
	
	
	--page 6 general settings
	self:enablePageButton(vehicle, 6)
	self:setupDebugButtons(vehicle, 6)
	self:addRowButton(vehicle,'toggleShowMiniHud', 6, 1, 1 )
	self:addRowButton(vehicle,'toggleOpenHudWithMouse', 6, 2, 1 )
	self:setupShowWaypointsButtons(vehicle, 6, 3)
	self:addRowButton(vehicle,'toggleIngameMapIconShowText', 6, 4, 1 )
	
	--page 7 driving settings
	self:enablePageButton(vehicle, 7)
	self:addSettingsRow(vehicle,'changeWarningLightsMode', 7, 1, 1 )
	self:addRowButton(vehicle,'toggleFuelSaveOption', 7, 2, 1 )
	self:addRowButton(vehicle,'toggleAutoRefuel', 7, 3, 1 )
	self:addRowButton(vehicle,'toggleAutomaticCoverHandling', 7, 4, 1 )
	self:addSettingsRow(vehicle,'changeWaitTime', 7, 5, 1 )
	
	self:setReloadPageOrder(vehicle, -1, true)
end

function courseplay.hud:setGrainTransportAIDriverContent(vehicle)
	self:debug(vehicle,"setGrainTransportAIDriverContent")
	--page 1 driving
	self:addRowButton(vehicle,'setDriveNow', 1, 2, 3 )
	
	self:addSettingsRow(vehicle,'changemaxRunNumber', 1, 5, 1 )
	self:addRowButton(vehicle,'toggleRunCounterActive', 1, 5, 2 )
	self:addRowButton(vehicle,'resetRunCounter', 1, 6, 1 )
	
	
	--page 1 driving
	self:enablePageButton(vehicle, 3)
	self:addSettingsRowWithArrows(vehicle,'changeSiloFillType', 3, 1, 1 )
	self:addSettingsRowWithArrows(vehicle,'changeRefillUntilPct', 3, 2, 1 )

	--page 7 
	self:addSettingsRow(vehicle,'changeLoadUnloadOffsetX', 7, 5, 1 )
	self:addSettingsRow(vehicle,'changeLoadUnloadOffsetZ', 7, 6, 1 )
	
	self:setReloadPageOrder(vehicle, -1, true)
end


function courseplay.hud:setFieldWorkAIDriverContent(vehicle)
	self:debug(vehicle,"setFieldWorkAIDriverContent")
	--self:setupCourseGeneratorButton(vehicle)
	self:addRowButton(vehicle,'openAdvancedCourseGeneratorSettings', 1, 4, 1 )
	self:addRowButton(vehicle,'setCustomSingleFieldEdge', 1, 5, 1 )
	self:addSettingsRow(vehicle,'setCustomFieldEdgePathNumber', 1, 5, 2 )
	self:addRowButton(vehicle,'addCustomSingleFieldEdgeToList', 1, 6, 1 )
	
	--page 3 settings
	self:enablePageButton(vehicle, 3)
	self:addSettingsRow(vehicle,'changeTurnDiameter', 3, 1, 1 )
	self:addSettingsRow(vehicle,'changeWorkWidth', 3, 2, 1 )
	self:setupCalculateWorkWidthButton(vehicle,3, 2)
	self:addRowButton(vehicle,'toggleConvoyActive', 3, 3, 1 )
	self:addSettingsRow(vehicle,'setConvoyMinDistance', 3, 4, 1 )
	--self:addSettingsRow(vehicle,'setConvoyMaxDistance', 3, 5, 1 )
	
	
	--page 7
	self:addRowButton(vehicle,'toggleAlignmentWaypoint', 7, 6, 1 )
	
	
	--page 8 fieldwork settings
	self:enablePageButton(vehicle, 8)
	self:addSettingsRowWithArrows(vehicle,'changeLaneNumber', 8, 1, 1 )
	self:addSettingsRowWithArrows(vehicle,'changeLaneOffset', 8, 1, 2 )
	self:addRowButton(vehicle,'toggleSymmetricLaneChange', 8, 2, 1 )
	self:addRowButton(vehicle,'toggleTurnOnField', 8, 3, 1 )
	self:addRowButton(vehicle,'toggleRealisticDriving', 8, 4, 1 )
	self:addSettingsRowWithArrows(vehicle,'changeToolOffsetX', 8, 5, 1 )
	self:addSettingsRowWithArrows(vehicle,'changeToolOffsetZ', 8, 6, 1 )
	self:addRowButton(vehicle,'toggleOppositeTurnMode', 8, 7, 1 )
	
	--togglePlowFieldEdge
	
	self:setReloadPageOrder(vehicle, -1, true)
end

function courseplay.hud:setUnloadableFieldworkAIDriverContent(vehicle)
	self:debug(vehicle,"setUnloadableFieldworkAIDriverContent")
	
	self:addRowButton(vehicle,'setDriveNow', 1, 2, 3 )

	self:addSettingsRow(vehicle,'changeRefillUntilPct', 3, 5, 1 )
	
	self:setReloadPageOrder(vehicle, -1, true)
end

function courseplay.hud:setCombineAIDriverContent(vehicle)
	self:debug(vehicle,"setCombineAIDriverContent")
	--page 0 
	self:enablePageButton(vehicle, 0)
	self:addRowButton(vehicle,'toggleWantsCourseplayer', 0, 1, 1 )
	self:addRowButton(vehicle,'startStopCourseplayer', 0, 2, 1 )
	self:addRowButton(vehicle,'sendCourseplayerHome', 0, 3, 1 )
	if vehicle.cp.isChopper then	
		self:addRowButton(vehicle,'switchCourseplayerSide', 0, 4, 1 )
		self:addRowButton(vehicle,'toggleTurnStage', 0, 5, 1 )
	else
		self:addRowButton(vehicle,'toggleDriverPriority', 0, 4, 1 )
		self:addRowButton(vehicle,'toggleStopWhenUnloading', 0, 5, 1 )
		self:addRowButton(vehicle,'changeHeadlandReverseManeuverType', 0, 6, 1 )
	end
	self:setReloadPageOrder(vehicle, -1, true)
end

function courseplay.hud:setCombineUnloadAIDriverContent(vehicle)
	self:debug(vehicle,"setCombineUnloadAIDriverContent")

	--page 1
	self:addRowButton(vehicle,'setDriveNow', 1, 2, 3 )
	
	--page 4 
	self:enablePageButton(vehicle, 4)
	
	self:addRowButton(vehicle,'toggleSearchCombineMode', 4, 1, 1 )
	self:addSettingsRowWithArrows(vehicle,'selectAssignedCombine', 4, 2, 1 )
	self:addSettingsRowWithArrows(vehicle,'setSearchCombineOnField', 4, 3, 1 )
	self:addRowButton(vehicle,'showCombineName', 4, 4, 1 )
	self:addRowButton(vehicle,'removeActiveCombineFromTractor', 4, 5, 1 )
	
	--page 7
	self:addRowButton(vehicle,'toggleAlignmentWaypoint', 7, 6, 1 )
		
	--page 8
	self:enablePageButton(vehicle, 8)
	
	self:addSettingsRowWithArrows(vehicle,'changeCombineOffset', 8, 1, 1 )
	self:addSettingsRowWithArrows(vehicle,'changeTipperOffset', 8, 2, 1 )
	self:addSettingsRowWithArrows(vehicle,'changeDriveOnAtFillLevel', 8, 3, 1 )
	self:addSettingsRowWithArrows(vehicle,'changeFollowAtFillLevel', 8, 4, 1 )
	self:addRowButton(vehicle,'toggleRealisticDriving', 8, 5, 1 )
	self:addRowButton(vehicle,'toggleTurnOnField', 8, 6, 1 )
	
	self:setReloadPageOrder(vehicle, -1, true)
end


function courseplay.hud:setBaleLoaderAIDriverContent(vehicle)
	self:debug(vehicle,"setBaleLoaderAIDriverContent")
	self:addRowButton(vehicle,'toggleAutomaticUnloadingOnField', 3, 6, 1 )
	
	self:setReloadPageOrder(vehicle, -1, true)
end

function courseplay.hud:setFillableFieldworkAIDriverContent(vehicle)
	self:debug(vehicle,"setFillableFieldworkAIDriverContent")
	
	
	self:addSettingsRow(vehicle,'changeRefillUntilPct', 3, 5, 1 )
	self:addSettingsRow(vehicle,'changeSiloFillType', 3, 6, 1 )
	self:addRowButton(vehicle,'toggleFertilizeOption', 3, 7, 1 )
	
	self:setReloadPageOrder(vehicle, -1, true)
end





--different buttons to set
function courseplay.hud:addRowButton(vehicle,funct, hudPage, line, column )
	self:debug(vehicle,"  addRowButton: "..tostring(funct))
	local width = {
					[1] = self.buttonPosX[2] - self.col1posX;
					}
  
  --courseplay.button:new(vehicle, hudPage, img, functionToCall, parameter, x, y, width, height, hudRow, modifiedParameter, hoverText, isMouseWheelArea, isToggleButton, toolTip)
	courseplay.button:new(vehicle, hudPage, nil, funct, parameter, self.col1posX, self.linesPosY[line], width[1], self.lineHeight, line, nil, true);
	vehicle.cp.hud.content.pages[hudPage][line][column].functionToCall = funct
end

function courseplay.hud:addSettingsRow(vehicle,funct, hudPage, line, column )
	self:debug(vehicle,"  addSettingsRow: "..tostring(funct))
	courseplay.button:new(vehicle, hudPage, { 'iconSprite.png', 'navMinus' }, funct,   -1, self.buttonPosX[2], self.linesButtonPosY[line], self.buttonSize.small.w, self.buttonSize.small.h, line, -5, false);
	courseplay.button:new(vehicle, hudPage, { 'iconSprite.png', 'navPlus' },  funct,    1, self.buttonPosX[1], self.linesButtonPosY[line], self.buttonSize.small.w, self.buttonSize.small.h, line,  5, false);
	courseplay.button:new(vehicle, hudPage, nil, funct, 1, self.contentMinX, self.linesButtonPosY[line], self.contentMaxWidth, self.lineHeight, line, 5, true, true);
	vehicle.cp.hud.content.pages[hudPage][line][column].functionToCall = funct
end

function courseplay.hud:addSettingsRowWithArrows(vehicle,funct, hudPage, line, column )
	self:debug(vehicle,"  addSettingsRowWithArrows: "..tostring(funct))
	courseplay.button:new(vehicle, hudPage, { 'iconSprite.png', 'navLeft' }, funct,   -1, self.buttonPosX[2], self.linesButtonPosY[line], self.buttonSize.small.w, self.buttonSize.small.h, line, -5, false);
	courseplay.button:new(vehicle, hudPage, { 'iconSprite.png', 'navRight' },  funct,    1, self.buttonPosX[1], self.linesButtonPosY[line], self.buttonSize.small.w, self.buttonSize.small.h, line,  5, false);
	courseplay.button:new(vehicle, hudPage, nil, funct, 1, self.contentMinX, self.linesButtonPosY[line], self.contentMaxWidth, self.lineHeight, line, 5, true, true);
	vehicle.cp.hud.content.pages[hudPage][line][column].functionToCall = funct
end
		
function courseplay.hud:debug(vehicle,...)
	courseplay.debugVehicle(18, vehicle, ...)
end	
	
-- do not remove this comment
-- vim: set noexpandtab:
