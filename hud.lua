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

	self.pagesPerMode = {						 --  Pg 0		  Pg 1		  Pg 2		  Pg 3		   Pg 4		    Pg 5		Pg 6		Pg 7		Pg 8		 Pg 9			Pg10
		[courseplay.MODE_GRAIN_TRANSPORT]		 = { [0] = true,  [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false,  [10] = false}; -- mode 1
		[courseplay.MODE_COMBI]					 = { [0] = true,  [1] = true, [2] = true, [3] = true,  [4] = true,  [5] = true, [6] = true, [7] = true, [8] = false, [9] = false,  [10] = false }; -- mode 2
		[courseplay.MODE_OVERLOADER]			 = { [0] = true,  [1] = true, [2] = true, [3] = true,  [4] = true,  [5] = true, [6] = true, [7] = true, [8] = false, [9] = false,  [10] = false }; -- mode 3
		[courseplay.MODE_SEED_FERTILIZE]		 = { [0] = true,  [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = true,  [9] = false,  [10] = false }; -- mode 4
		[courseplay.MODE_TRANSPORT]				 = { [0] = true,  [1] = true, [2] = true, [3] = false, [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false,  [10] = false }; -- mode 5
		[courseplay.MODE_FIELDWORK]				 = { [0] = true,  [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = true,  [9] = false,  [10] = false }; -- mode 6
		[courseplay.MODE_COMBINE_SELF_UNLOADING] = { [0] = false, [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false,  [10] = false }; -- mode 7
		[courseplay.MODE_LIQUIDMANURE_TRANSPORT] = { [0] = true,  [1] = true, [2] = true, [3] = true,  [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false,  [10] = false }; -- mode 8
		[courseplay.MODE_SHOVEL_FILL_AND_EMPTY]	 = { [0] = true,  [1] = true, [2] = true, [3] = false, [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = true,  [10] = false  }; -- mode 9
		[courseplay.MODE_BUNKERSILO_COMPACTER]	 = { [0] = true,  [1] = true, [2] = true, [3] = false, [4] = false, [5] = true, [6] = true, [7] = true, [8] = false, [9] = false,  [10] = true  }; -- mode 10
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
	self.suc.visibleArea.overlayWidth = g_currentMission.hudTipperOverlay.width * 2.75;
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
		[self.PAGE_COMBINE_CONTROLS]  = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_CP_CONTROL] 		  = self.basePosX + self:pxToNormal(368, 'x'),
		[self.PAGE_MANAGE_COURSES] 	  = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_COMBI_MODE] 		  = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_MANAGE_COMBINES]   = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_SPEEDS] 			  = self.basePosX + self:pxToNormal(234, 'x'),
		[self.PAGE_GENERAL_SETTINGS]  = self.basePosX + self:pxToNormal(350, 'x'),
		[self.PAGE_DRIVING_SETTINGS]  = self.basePosX + self:pxToNormal(368, 'x'),
		[self.PAGE_COURSE_GENERATION] = self.basePosX + self:pxToNormal(272, 'x'),
		[self.PAGE_SHOVEL_POSITIONS]  = self.basePosX + self:pxToNormal(390, 'x'),
		[self.PAGE_BUNKERSILO_SETTINGS]  = self.basePosX + self:pxToNormal(390, 'x'),
	};
	self.col2posXforce = {
		[self.PAGE_COMBINE_CONTROLS] = {
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
		};
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
		[self.PAGE_COURSE_GENERATION] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COURSE_GENERATION"), -- course generation
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
	self.bottomInfo.timeRemainingX = self.bottomInfo.waypointIconX - self.bottomInfo.iconWidth
	
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

	-- SOUND
	self.clickSound = createSample('clickSound');
	loadSample(self.clickSound, Utils.getFilename('sounds/cpClickSound.wav', courseplay.path), false);
end;


-- ####################################################################################################
-- EXECUTION
function courseplay.hud:setContent(vehicle)
	-- self = courseplay.hud

	if vehicle.cp.hud.firstTimeSetContent then
		--- Reset tools
		-- This is to show the silo filltype line on first time opening the hud and the mode is Grain Transport.
		if vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT then
			courseplay:resetTools(vehicle);
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

	if vehicle.cp.timeRemaining ~= nil then
		local timeRemaining = courseplay:sekToTimeFormat(vehicle.cp.timeRemaining)
		vehicle.cp.hud.content.bottomInfo.timeRemainingText = ('%02.f:%02.f:%02.f'):format(timeRemaining.nHours,timeRemaining.nMins,timeRemaining.nSecs)
	else
		vehicle.cp.hud.content.bottomInfo.timeRemainingText = nil
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

	-- CURRENT PAGE
	if vehicle.cp.hud.currentPage == 1 and vehicle.cp.convoyActive then
		self:setReloadPageOrder(vehicle, 1, true);
	elseif vehicle.cp.hud.currentPage == 3 and vehicle:getIsCourseplayDriving() and (vehicle.cp.mode == 2 or vehicle.cp.mode == 3) then
		for i,varName in pairs({ 'combineOffset', 'turnDiameter' }) do
			if courseplay.utils:hasVarChanged(vehicle, varName) then
				self:setReloadPageOrder(vehicle, 3, true);
				break;
			end;
		end;
	elseif vehicle.cp.hud.currentPage == 4 then
		if vehicle.cp.savedCombine ~= nil then -- Force page 4 reload when combine distance is displayed
			self:setReloadPageOrder(vehicle, 4, true);
		end;

	elseif vehicle.cp.hud.currentPage == 7 then
		if vehicle.cp.copyCourseFromDriver ~= nil or courseplay.utils:hasVarChanged(vehicle, 'totalOffsetX') then -- Force page 7 reload when vehicle distance is displayed
			self:setReloadPageOrder(vehicle, 7, true);
		end;
	end;

	-- RELOAD PAGE
	if vehicle.cp.hud.reloadPage[vehicle.cp.hud.currentPage] then
		for line=1,self.numLines do
			for column=1,3 do
				vehicle.cp.hud.content.pages[vehicle.cp.hud.currentPage][line][column].text = nil;
			end;
		end;
		self:loadPage(vehicle, vehicle.cp.hud.currentPage);
	end;
end; --END setHudContent()


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

	-- BOTTOM GLOBAL INFO
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

	if vehicle.cp.hud.content.bottomInfo.waitPointsText ~= nil and vehicle.cp.hud.content.bottomInfo.crossingPointsText ~= nil then
		courseplay:setFontSettings('white', false, 'center');

		renderText(self.bottomInfo.waitPointsTextX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.waitPointsText);
		vehicle.cp.hud.waitPointsIcon:render();

		renderText(self.bottomInfo.crossingPointsTextX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.crossingPointsText);
		vehicle.cp.hud.crossingPointsIcon:render();
	end;

	if vehicle.cp.hud.content.bottomInfo.timeRemainingText ~= nil  then
		courseplay:setFontSettings('white', false, 'right');
		renderText(self.bottomInfo.timeRemainingX, self.bottomInfo.textPosY, self.fontSizes.bottomInfo, vehicle.cp.hud.content.bottomInfo.timeRemainingText);
	end		

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
		end;
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
		renderText(vehicle.cp.changeDrawCourseModeButton.x + vehicle.cp.changeDrawCourseModeButton.width * 0.5, self.topIconsY + self.fontSizes.version * 1.25, self.fontSizes.version, txt);
		courseplay:setFontSettings('white', false);
	end;
end;

function courseplay:setMinHudPage(vehicle)
	vehicle.cp.minHudPage = courseplay.hud.PAGE_CP_CONTROL;
	if vehicle.cp.isCombine or vehicle.cp.isChopper or vehicle.cp.isHarvesterSteerable or vehicle.cp.isSugarBeetLoader or vehicle.cp.attachedCombine ~= nil then
		vehicle.cp.minHudPage = courseplay.hud.PAGE_COMBINE_CONTROLS;
	end;

	courseplay:setHudPage(vehicle, max(vehicle.cp.hud.currentPage, vehicle.cp.minHudPage));
	courseplay:debug(('%s: setMinHudPage(): minHudPage=%d, currentPage=%d'):format(nameNum(vehicle), vehicle.cp.minHudPage, vehicle.cp.hud.currentPage), 18);
	courseplay.buttons:setActiveEnabled(vehicle, 'pageNav');
end;

function courseplay.hud:loadPage(vehicle, page)
	-- self = courseplay.hud

	courseplay:debug(string.format('%s: loadPage(..., %d), set content', nameNum(vehicle), page), 18);
		
	--PAGE 0: COMBINE SETTINGS
	if page == self.PAGE_COMBINE_CONTROLS then
		local combine = vehicle;
		if vehicle.cp.attachedCombine ~= nil then
			combine = vehicle.cp.attachedCombine;
		end;

		if not combine.cp.isChopper then
			--Driver priority
			vehicle.cp.hud.content.pages[0][4][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_PRIORITY');
			vehicle.cp.hud.content.pages[0][4][2].text = combine.cp.driverPriorityUseFillLevel and courseplay:loc('COURSEPLAY_FILLEVEL') or courseplay:loc('COURSEPLAY_DISTANCE');

			if vehicle.cp.mode == 6 then
				vehicle.cp.hud.content.pages[0][5][1].text = courseplay:loc('COURSEPLAY_STOP_DURING_UNLOADING');
				vehicle.cp.hud.content.pages[0][5][2].text = combine.cp.stopWhenUnloading and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
			end;
			vehicle.cp.hud.content.pages[0][7][1].text = courseplay:loc('COURSEPLAY_HEADLAND_REVERSE_MANEUVER_TYPE')
			vehicle.cp.hud.content.pages[0][7][2].text = courseplay:loc( courseplay.headlandReverseManeuverTypeText[ vehicle.cp.headland.reverseManeuverType ])
		end;

		-- no courseplayer!
		if vehicle.cp.HUD0noCourseplayer then
			if vehicle.cp.HUD0wantsCourseplayer then
				vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_REQUESTED');
			else
				vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc('COURSEPLAY_REQUEST_UNLOADING_DRIVER');
			end
		else
			vehicle.cp.hud.content.pages[0][1][1].text = courseplay:loc('COURSEPLAY_DRIVER');
			vehicle.cp.hud.content.pages[0][1][2].text = vehicle.cp.HUD0tractorName;

			if vehicle.cp.HUD0tractorForcedToStop then
				vehicle.cp.hud.content.pages[0][2][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_START');
			else
				vehicle.cp.hud.content.pages[0][2][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_STOP');
			end
			vehicle.cp.hud.content.pages[0][3][1].text = courseplay:loc('COURSEPLAY_UNLOADING_DRIVER_SEND_HOME');

			--chopper
			if combine.cp.isChopper then
				if vehicle.cp.HUD0tractor then
					vehicle.cp.hud.content.pages[0][4][1].text = courseplay:loc('COURSEPLAY_UNLOADING_SIDE');
					if vehicle.cp.HUD0combineForcedSide == 'left' then
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc('COURSEPLAY_LEFT');
					elseif vehicle.cp.HUD0combineForcedSide == 'right' then
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc('COURSEPLAY_RIGHT');
					else
						vehicle.cp.hud.content.pages[0][4][2].text = courseplay:loc('COURSEPLAY_UNLOADING_SIDE_NONE');
					end;

					--manual chopping: initiate/end turning maneuver
					if vehicle.cp.HUD0isManual then
						vehicle.cp.hud.content.pages[0][5][1].text = courseplay:loc('COURSEPLAY_TURN_MANEUVER');
						if vehicle.cp.HUD0turnStage == 0 then
							vehicle.cp.hud.content.pages[0][5][2].text = courseplay:loc('COURSEPLAY_START');
						elseif vehicle.cp.HUD0turnStage == 1 then
							vehicle.cp.hud.content.pages[0][5][2].text = courseplay:loc('COURSEPLAY_FINISH');
						end;
					end;
				end;
			end;
		end;


	--PAGE 1: COURSEPLAY CONTROL
	elseif page == self.PAGE_CP_CONTROL then
		if vehicle.cp.canDrive then
			if not vehicle:getIsCourseplayDriving() then -- only 6 lines available, as the mode buttons are in lines 7 and 8!
				vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc('COURSEPLAY_START_COURSE')

				if vehicle.cp.mode ~= courseplay.MODE_SHOVEL_FILL_AND_EMPTY then
					vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc('COURSEPLAY_START_AT_POINT');
					if vehicle.cp.startAtPoint == courseplay.START_AT_NEAREST_POINT then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc('COURSEPLAY_NEAREST_POINT');
					elseif vehicle.cp.startAtPoint == courseplay.START_AT_FIRST_POINT then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc('COURSEPLAY_FIRST_POINT');
					elseif vehicle.cp.startAtPoint == courseplay.START_AT_CURRENT_POINT then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc('COURSEPLAY_CURRENT_POINT');
					elseif vehicle.cp.startAtPoint == courseplay.START_AT_NEXT_POINT then
						vehicle.cp.hud.content.pages[1][3][2].text = courseplay:loc('COURSEPLAY_NEXT_POINT');
					end;
				end;

				if vehicle.cp.hasAugerWagon and not vehicle.cp.hasSugarCaneAugerWagon and (vehicle.cp.mode == courseplay.MODE_OVERLOADER or vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT) then
					vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc('COURSEPLAY_SAVE_PIPE_POSITION');
					if vehicle.cp.pipeWorkToolIndex ~= nil then
						vehicle.cp.hud.content.pages[1][4][2].text = 'OK';
					else
						vehicle.cp.hud.content.pages[1][4][2].text = courseplay:loc('UNKNOWN');
					end
				end

				if vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT and #vehicle.cp.easyFillTypeList > 0 then
					vehicle.cp.hud.content.pages[1][6][1].text = courseplay:loc('COURSEPLAY_FARM_SILO_FILL_TYPE');
					vehicle.cp.hud.content.pages[1][6][2].text = FillUtil.fillTypeIndexToDesc[vehicle.cp.siloSelectedFillType].nameI18N;
				end
				
				if vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE and vehicle.cp.hasFertilizerSowingMachine then
					vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc('COURSEPLAY_FERTILIZERFUNCTION');
					vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.fertilizerOption and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
				end;

			else
				vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc('COURSEPLAY_STOP_COURSE')

				if vehicle.cp.HUD1wait then
					vehicle.cp.hud.content.pages[1][2][1].text = courseplay:loc('COURSEPLAY_CONTINUE')
				end

				if vehicle.cp.HUD1noWaitforFill then
					vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc('COURSEPLAY_DRIVE_NOW')
				end

				vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc('COURSEPLAY_STOP_AT_LAST_POINT');
				vehicle.cp.hud.content.pages[1][4][2].text = vehicle.cp.stopAtEnd and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

				if vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE and vehicle.cp.hasSowingMachine then
					vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc('COURSEPLAY_RIDGEMARKERS');
					vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.ridgeMarkersAutomatic and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_DEACTIVATED');

				elseif vehicle.cp.mode == courseplay.MODE_FIELDWORK and vehicle.cp.hasBaleLoader and not vehicle.cp.hasUnloadingRefillingCourse then
					vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc('COURSEPLAY_UNLOADING_ON_FIELD');
					vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.automaticUnloadingOnField and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_MANUAL');
				end;

				if vehicle.cp.tipperHasCover and (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_TRANSPORT or vehicle.cp.mode == courseplay.MODE_FIELDWORK) then
					vehicle.cp.hud.content.pages[1][6][1].text = courseplay:loc('COURSEPLAY_COVER_HANDLING');
					vehicle.cp.hud.content.pages[1][6][2].text = vehicle.cp.automaticCoverHandling and courseplay:loc('COURSEPLAY_AUTOMATIC') or courseplay:loc('COURSEPLAY_DEACTIVATED');
				end;
			end

			if (vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT) and #vehicle.cp.easyFillTypeList > 0 then
 				vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc('COURSEPLAY_NUMBER_OF_RUNS');
 				vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.runNumber < 11 and string.format("%d / %d",vehicle.cp.runCounter, vehicle.cp.runNumber) or courseplay:loc('COURSEPLAY_UNLIMITED');
 			elseif vehicle.cp.mode == courseplay.MODE_FIELDWORK and (vehicle.cp.isCombine or vehicle.cp.isChopper) then
				vehicle.cp.hud.content.pages[1][5][1].text = courseplay:loc('COURSEPLAY_COMBINE_CONVOY');
				vehicle.cp.hud.content.pages[1][5][2].text = vehicle.cp.convoyActive and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED')
				if vehicle.cp.convoyActive then
					--[[ TODO find a description or new entry in translations for the currently loaded course
					local currentLoadedCourse = courseplay:loc('COURSEPLAY_CURRENTLY_LOADED_COURSE')
					if Utils.startsWith(currentLoadedCourse, "(") then
						local split = Utils.splitString("(", currentLoadedCourse);
						local split2 = Utils.splitString(")", split[2]);
						currentLoadedCourse = split2[1]
					end
					if vehicle.cp.currentCourseName ~= nil then
						vehicle.cp.hud.content.pages[1][6][1].text =  string.format("%s: %s",currentLoadedCourse,vehicle.cp.currentCourseName);
					elseif vehicle.Waypoints[1] ~= nil then
						vehicle.cp.hud.content.pages[1][6][1].text = string.format("%s: %s",currentLoadedCourse,courseplay:loc('COURSEPLAY_TEMP_COURSE'));
					end]]
					if vehicle.cp.currentCourseName ~= nil then
						vehicle.cp.hud.content.pages[1][6][1].text =  string.format("%s",vehicle.cp.currentCourseName);
					elseif vehicle.Waypoints[1] ~= nil then
						vehicle.cp.hud.content.pages[1][6][1].text = string.format("%s",courseplay:loc('COURSEPLAY_TEMP_COURSE'));
					end
					vehicle.cp.hud.content.pages[1][6][2].text = string.format("<--%s--> %d/%d",(vehicle.cp.convoy.distance == 0 and "--" or string.format("%d%s",vehicle.cp.convoy.distance,courseplay:loc('COURSEPLAY_UNIT_METER'))),vehicle.cp.convoy.number,vehicle.cp.convoy.members)
				end
			end;

		elseif not vehicle:getIsCourseplayDriving() then -- only 6 lines available, as the mode buttons are in lines 7 and 8!
			if (not vehicle.cp.isRecording and not vehicle.cp.recordingIsPaused) and not vehicle.cp.canDrive then
				if vehicle.cp.numWaypoints == 0 then
					vehicle.cp.hud.content.pages[1][1][1].text = courseplay:loc('COURSEPLAY_RECORDING_START');
				end;

				--Custom field edge path
				vehicle.cp.hud.content.pages[1][3][1].text = courseplay:loc('COURSEPLAY_SCAN_CURRENT_FIELD_EDGES');
				if vehicle.cp.fieldEdge.customField.isCreated then
					vehicle.cp.hud.content.pages[1][4][1].text = courseplay:loc('COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER');
					if vehicle.cp.fieldEdge.customField.fieldNum > 0 then
						vehicle.cp.hud.content.pages[1][4][2].text = tostring(vehicle.cp.fieldEdge.customField.fieldNum);
						if vehicle.cp.fieldEdge.customField.selectedFieldNumExists then
							vehicle.cp.hud.content.pages[1][5][1].text = string.format(courseplay:loc('COURSEPLAY_OVERWRITE_CUSTOM_FIELD_EDGE_PATH_IN_LIST'), vehicle.cp.fieldEdge.customField.fieldNum);
						else
							vehicle.cp.hud.content.pages[1][5][1].text = string.format(courseplay:loc('COURSEPLAY_ADD_CUSTOM_FIELD_EDGE_PATH_TO_LIST'), vehicle.cp.fieldEdge.customField.fieldNum);
						end;
					else
						vehicle.cp.hud.content.pages[1][4][2].text = '---';
					end;
				end;
			end;
		end;

	--PAGE 2: COURSE LIST
	elseif page == self.PAGE_MANAGE_COURSES then
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
			vehicle.cp.hud.content.pages[2][line][1].text = courseName;
			if vehicle.cp.hud.courses[line].type == 'course' then
				vehicle.cp.hud.content.pages[2][line][1].indention = vehicle.cp.hud.courses[line].level * self.indent;
			else
				vehicle.cp.hud.content.pages[2][line][1].indention = (vehicle.cp.hud.courses[line].level + 1) * self.indent;
			end
		end;
		for line = numCourses+1, self.numLines do
			vehicle.cp.hud.content.pages[2][line][1].text = nil;
		end

		-- enable and disable buttons:
		courseplay.buttons:setActiveEnabled(vehicle, 'page2');


	--PAGE 3: MODE 2 SETTINGS
	elseif page == self.PAGE_COMBI_MODE then
		if vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_OVERLOADER then
			vehicle.cp.hud.content.pages[3][1][1].text = courseplay:loc('COURSEPLAY_COMBINE_OFFSET_HORIZONTAL');
			vehicle.cp.hud.content.pages[3][2][1].text = courseplay:loc('COURSEPLAY_COMBINE_OFFSET_VERTICAL');

			if vehicle.cp.modeState ~= nil then
				if vehicle.cp.combineOffset ~= 0 then
					vehicle.cp.hud.content.pages[3][1][2].text = ('%s %.1fm'):format(vehicle.cp.combineOffsetAutoMode and '(auto)' or '(mnl)', vehicle.cp.combineOffset);
				else
					vehicle.cp.hud.content.pages[3][1][2].text = 'auto';
				end;
			else
				vehicle.cp.hud.content.pages[3][1][2].text = '---';
			end;

			if vehicle.cp.tipperOffset ~= nil then
				if vehicle.cp.tipperOffset ~= 0 then
					vehicle.cp.hud.content.pages[3][2][2].text = ('auto%+.1fm'):format(vehicle.cp.tipperOffset);
				else
					vehicle.cp.hud.content.pages[3][2][2].text = 'auto';
				end;
			else
				vehicle.cp.hud.content.pages[3][2][2].text = '---';
			end;

		elseif vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK then
			vehicle.cp.hud.content.pages[3][1][1].text = courseplay:loc('COURSEPLAY_TURN_ON_FIELD');
			vehicle.cp.hud.content.pages[3][1][2].text = vehicle.cp.turnOnField and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
			vehicle.cp.hud.content.pages[3][2][1].text = courseplay:loc('COURSEPLAY_OPPOSITE_TURN_DIRECTION');
			vehicle.cp.hud.content.pages[3][2][2].text = vehicle.cp.oppositeTurnMode and courseplay:loc('COURSEPLAY_OPPOSITE_TURN_WHEN_POSSIBLE') or courseplay:loc('COURSEPLAY_OPPOSITE_TURN_AT_END');
		end;

		vehicle.cp.hud.content.pages[3][3][1].text = courseplay:loc('COURSEPLAY_TURN_RADIUS');
		if vehicle.cp.turnDiameterAuto ~= nil or vehicle.cp.turnDiameter ~= nil then
			vehicle.cp.hud.content.pages[3][3][2].text = ('%s %d%s'):format(vehicle.cp.turnDiameterAutoMode and '(auto)' or '(mnl)', vehicle.cp.turnDiameter, courseplay:loc('COURSEPLAY_UNIT_METER'));
		else
			vehicle.cp.hud.content.pages[3][3][2].text = '---';
		end;

		vehicle.cp.hud.content.pages[3][4][1].text = courseplay:loc('COURSEPLAY_START_AT');
		vehicle.cp.hud.content.pages[3][4][2].text = vehicle.cp.followAtFillLevel ~= nil and ('%d%%'):format(vehicle.cp.followAtFillLevel) or '---';

		vehicle.cp.hud.content.pages[3][5][1].text = courseplay:loc('COURSEPLAY_DRIVE_ON_AT');
		vehicle.cp.hud.content.pages[3][5][2].text = vehicle.cp.driveOnAtFillLevel ~= nil and ('%d%%'):format(vehicle.cp.driveOnAtFillLevel) or '---';

		if vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT then
			vehicle.cp.hud.content.pages[3][6][1].text = courseplay:loc('COURSEPLAY_REFILL_UNTIL_PCT');
			vehicle.cp.hud.content.pages[3][6][2].text = ('%d%%'):format(vehicle.cp.refillUntilPct);
		elseif vehicle.cp.lastValidTipDistance ~= nil then
			vehicle.cp.hud.content.pages[3][6][1].text = courseplay:loc('COURSEPLAY_LAST_VAILD_TIP_DIST');
			vehicle.cp.hud.content.pages[3][6][2].text = ('%.1fm'):format(vehicle.cp.lastValidTipDistance);
		end;

		if vehicle.cp.mode == courseplay.MODE_FIELDWORK and vehicle.cp.hasPlough then
			vehicle.cp.hud.content.pages[3][7][1].text = courseplay:loc('COURSEPLAY_PLOUGH_FIELD_EDGE');
			vehicle.cp.hud.content.pages[3][7][2].text = vehicle.cp.ploughFieldEdge and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
		end;
		
		vehicle.cp.hud.content.pages[3][8][1].text = courseplay:loc('COURSEPLAY_ALIGNMENT_WAYPOINT');
		vehicle.cp.hud.content.pages[3][8][2].text = vehicle.cp.alignment.enabled and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

	--PAGE 4: COMBINE ASSIGNMENT
	elseif page == self.PAGE_MANAGE_COMBINES then
		--Line 1: combine search mode (automatic vs manual)
		vehicle.cp.hud.content.pages[4][1][1].text = courseplay:loc('COURSEPLAY_COMBINE_SEARCH_MODE'); --always
		vehicle.cp.hud.content.pages[4][1][2].text = vehicle.cp.searchCombineAutomatically and courseplay:loc('COURSEPLAY_AUTOMATIC_SEARCH') or courseplay:loc('COURSEPLAY_MANUAL_SEARCH');

		--Line 2: select combine manually
		if not vehicle.cp.searchCombineAutomatically then
			vehicle.cp.hud.content.pages[4][2][1].text = courseplay:loc('COURSEPLAY_CHOOSE_COMBINE'); --only if manual
			if vehicle.cp.HUD4savedCombine then
				if vehicle.cp.HUD4savedCombineName == nil then
					vehicle:setCpVar('HUD4savedCombineName',courseplay:loc('COURSEPLAY_COMBINE'),courseplay.isClient);
				end;
				if vehicle.cp.savedCombine ~= nil then
					local dist = courseplay:distanceToObject(vehicle, vehicle.cp.savedCombine);
					if dist >= 1000 then
						vehicle.cp.hud.content.pages[4][2][2].text = ('%s (%.1f%s)'):format(vehicle.cp.HUD4savedCombineName, dist * 0.001, courseplay:getMeasuringUnit());
					else
						vehicle.cp.hud.content.pages[4][2][2].text = ('%s (%d%s)'):format(vehicle.cp.HUD4savedCombineName, dist, courseplay:loc('COURSEPLAY_UNIT_METER'));
					end;
				end
			else
				vehicle.cp.hud.content.pages[4][2][2].text = courseplay:loc('COURSEPLAY_NONE');
			end;
		end;

		--Line 3: choose field for automatic search --only if automatic
		if vehicle.cp.searchCombineAutomatically and courseplay.fields.numAvailableFields > 0 then
			vehicle.cp.hud.content.pages[4][3][1].text = courseplay:loc('COURSEPLAY_SEARCH_COMBINE_ON_FIELD'):format(vehicle.cp.searchCombineOnField > 0 and tostring(vehicle.cp.searchCombineOnField) or '---');
		end;
		

		--Line 4: current assigned combine
		vehicle.cp.hud.content.pages[4][4][1].text = courseplay:loc('COURSEPLAY_CURRENT'); --always
		vehicle.cp.hud.content.pages[4][4][2].text = vehicle.cp.HUD4hasActiveCombine and vehicle.cp.HUD4combineName or courseplay:loc('COURSEPLAY_NONE');

		--Line 5: remove active combine from tractor
		if vehicle.cp.activeCombine ~= nil then --only if activeCombine
			vehicle.cp.hud.content.pages[4][5][1].text = courseplay:loc('COURSEPLAY_REMOVEACTIVECOMBINEFROMTRACTOR');
		end;


	--PAGE 5: SPEEDS
	elseif page == self.PAGE_SPEEDS then
		vehicle.cp.hud.content.pages[5][1][1].text = courseplay:loc('COURSEPLAY_SPEED_TURN');
		vehicle.cp.hud.content.pages[5][2][1].text = courseplay:loc('COURSEPLAY_SPEED_FIELD');
		vehicle.cp.hud.content.pages[5][3][1].text = courseplay:loc('COURSEPLAY_SPEED_MAX');
		vehicle.cp.hud.content.pages[5][4][1].text = courseplay:loc('COURSEPLAY_SPEED_REVERSING');
		vehicle.cp.hud.content.pages[5][5][1].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE');

		vehicle.cp.hud.content.pages[5][1][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.turn), courseplay:getSpeedMeasuringUnit());
		vehicle.cp.hud.content.pages[5][2][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.field), courseplay:getSpeedMeasuringUnit());
		vehicle.cp.hud.content.pages[5][4][2].text = string.format('%d %s', g_i18n:getSpeed(vehicle.cp.speeds.reverse), courseplay:getSpeedMeasuringUnit());

		local streetSpeedStr = ('%d %s'):format(g_i18n:getSpeed(vehicle.cp.speeds.street), courseplay:getSpeedMeasuringUnit());
		if vehicle.cp.speeds.useRecordingSpeed then
			vehicle.cp.hud.content.pages[5][3][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_AUTOMATIC'):format(streetSpeedStr);
			vehicle.cp.hud.content.pages[5][5][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_RECORDING');
		else
			vehicle.cp.hud.content.pages[5][3][2].text = streetSpeedStr;
			vehicle.cp.hud.content.pages[5][5][2].text = courseplay:loc('COURSEPLAY_MAX_SPEED_MODE_MAX');
		end;

		-- Always use 4WD
		if vehicle.cp.hasDriveControl and vehicle.cp.driveControl.hasFourWD then
			vehicle.cp.hud.content.pages[5][7][1].text = courseplay:loc('COURSEPLAY_DRIVECONTROL');
			vehicle.cp.hud.content.pages[5][7][2].text =  courseplay:loc('COURSEPLAY_DRIVECONTROL_MODE_' .. vehicle.cp.driveControl.mode);
		end;
		
		--FuelSaveOption
			vehicle.cp.hud.content.pages[5][8][1].text = courseplay:loc('COURSEPLAY_FUELSAVEOPTION');
			vehicle.cp.hud.content.pages[5][8][2].text = vehicle.cp.saveFuelOptionActive and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');

	--PAGE 6: GENERAL SETTINGS
	elseif page == self.PAGE_GENERAL_SETTINGS then
		-- pathfinding
		vehicle.cp.hud.content.pages[6][1][1].text = nil;
		vehicle.cp.hud.content.pages[6][1][2].text = nil;
		if vehicle.cp.mode == courseplay.MODE_COMBI or vehicle.cp.mode == courseplay.MODE_OVERLOADER then
			vehicle.cp.hud.content.pages[6][1][1].text = courseplay:loc('COURSEPLAY_PATHFINDING');
			vehicle.cp.hud.content.pages[6][1][2].text = vehicle.cp.realisticDriving and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
		end;

		-- Open hud key
		vehicle.cp.hud.content.pages[6][2][1].text = courseplay:loc('COURSEPLAY_OPEN_HUD_MODE');
		vehicle.cp.hud.content.pages[6][2][2].text = vehicle.cp.hud.openWithMouse and courseplay.inputBindings.mouse.secondaryTextI18n or courseplay.inputBindings.keyboard.openCloseHudTextI18n;

		-- Waypoint mode
		vehicle.cp.hud.content.pages[6][3][1].text = courseplay:loc('COURSEPLAY_WAYPOINT_MODE');

		-- Warning lights
		vehicle.cp.hud.content.pages[6][4][1].text = courseplay:loc('COURSEPLAY_WARNING_LIGHTS');
		vehicle.cp.hud.content.pages[6][4][2].text = courseplay:loc('COURSEPLAY_WARNING_LIGHTS_MODE_' .. vehicle.cp.warningLightsMode);

		-- Waiting point: wait time
		if courseplay:getCanHaveWaitTime(vehicle) then
			vehicle.cp.hud.content.pages[6][5][1].text = courseplay:loc('COURSEPLAY_WAITING_TIME');
			local str;
			if vehicle.cp.waitTime < 60 then
				str = courseplay:loc('COURSEPLAY_SECONDS'):format(vehicle.cp.waitTime);
			else
				local minutes, seconds = floor(vehicle.cp.waitTime/60), vehicle.cp.waitTime % 60;
				str = courseplay:loc('COURSEPLAY_MINUTES'):format(minutes);
				if seconds > 0 then
					str = str .. ', ' .. courseplay:loc('COURSEPLAY_SECONDS'):format(seconds);
				end;
			end;
			vehicle.cp.hud.content.pages[6][5][2].text = str;
		end;

		-- Ingame map icon text
		if CpManager.ingameMapIconActive and CpManager.ingameMapIconShowTextLoaded then
			vehicle.cp.hud.content.pages[6][6][1].text = courseplay:loc('COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT');
			if CpManager.ingameMapIconShowName and not CpManager.ingameMapIconShowCourse then
				vehicle.cp.hud.content.pages[6][6][2].text = courseplay:loc('COURSEPLAY_NAME_ONLY');
			elseif CpManager.ingameMapIconShowName and CpManager.ingameMapIconShowCourse then
				vehicle.cp.hud.content.pages[6][6][2].text = courseplay:loc('COURSEPLAY_NAME_AND_COURSE');
			else
				vehicle.cp.hud.content.pages[6][6][2].text = courseplay:loc('COURSEPLAY_DEACTIVATED');
			end;			
		end;

		vehicle.cp.hud.content.pages[6][7][1].text = courseplay:loc('COURSEPLAY_FUEL_SEARCH_FOR');
		if vehicle.cp.allwaysSearchFuel then
			vehicle.cp.hud.content.pages[6][7][2].text = courseplay:loc('COURSEPLAY_FUEL_ALWAYS');
		else
			vehicle.cp.hud.content.pages[6][7][2].text = courseplay:loc('COURSEPLAY_FUEL_BELOW_20PCT');
		end
		
		
		-- Debug channels
		if courseplay.isDevVersion then
			vehicle.cp.hud.content.pages[6][8][1].text = courseplay:loc('COURSEPLAY_DEBUG_CHANNELS');
		end

	--PAGE 7: DRIVING SETTINGS
	elseif page == self.PAGE_DRIVING_SETTINGS then
		if vehicle.cp.mode == courseplay.MODE_OVERLOADER or vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK or vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT then
			--Lane offset
			if vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK then
				vehicle.cp.hud.content.pages[7][1][1].text = courseplay:loc('COURSEPLAY_LANE_OFFSET');
				if vehicle.cp.laneOffset and vehicle.cp.laneOffset ~= 0 and vehicle.cp.multiTools == 1 then
					vehicle.cp.hud.content.pages[7][1][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.laneOffset), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.laneOffset > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
				elseif vehicle.cp.multiTools > 1 then
					if vehicle.cp.laneNumber == 0 then
						vehicle.cp.hud.content.pages[7][1][2].text = ('%s'):format(courseplay:loc('COURSEPLAY_CENTER'));
					else
						vehicle.cp.hud.content.pages[7][1][2].text = ('%d %s'):format(abs(vehicle.cp.laneNumber), courseplay:loc(vehicle.cp.laneNumber > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
					end
				else
					vehicle.cp.hud.content.pages[7][1][2].text = '---';
				end;
			end;

			--Symmetrical lane change
			if (vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK) and vehicle.cp.laneOffset ~= 0 then
				vehicle.cp.hud.content.pages[7][2][1].text = courseplay:loc('COURSEPLAY_SYMMETRIC_LANE_CHANGE');
				vehicle.cp.hud.content.pages[7][2][2].text = vehicle.cp.symmetricLaneChange and courseplay:loc('COURSEPLAY_ACTIVATED') or courseplay:loc('COURSEPLAY_DEACTIVATED');
			end;

			--Tool horizontal offset
			vehicle.cp.hud.content.pages[7][3][1].text = courseplay:loc('COURSEPLAY_TOOL_OFFSET_X');
			if vehicle.cp.toolOffsetX and vehicle.cp.toolOffsetX ~= 0 then
				vehicle.cp.hud.content.pages[7][3][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.toolOffsetX), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.toolOffsetX > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
			else
				vehicle.cp.hud.content.pages[7][3][2].text = '---';
			end;

			--Tool vertical offset
			vehicle.cp.hud.content.pages[7][4][1].text = courseplay:loc('COURSEPLAY_TOOL_OFFSET_Z');
			if vehicle.cp.toolOffsetZ and vehicle.cp.toolOffsetZ ~= 0 then
				vehicle.cp.hud.content.pages[7][4][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.toolOffsetZ), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.toolOffsetZ > 0 and 'COURSEPLAY_FRONT' or 'COURSEPLAY_BACK'));
			else
				vehicle.cp.hud.content.pages[7][4][2].text = '---';
			end;
		end;

		if vehicle.cp.mode == courseplay.MODE_GRAIN_TRANSPORT or vehicle.cp.mode == courseplay.MODE_OVERLOADER or vehicle.cp.mode == courseplay.MODE_SEED_FERTILIZE or vehicle.cp.mode == courseplay.MODE_FIELDWORK or vehicle.cp.mode == courseplay.MODE_COMBINE_SELF_UNLOADING or vehicle.cp.mode == courseplay.MODE_LIQUIDMANURE_TRANSPORT then
			--load/Unload horizontal offset
			vehicle.cp.hud.content.pages[7][5][1].text = courseplay:loc('COURSEPLAY_LOAD_UNLOAD_OFFSET_X');
			if vehicle.cp.loadUnloadOffsetX and vehicle.cp.loadUnloadOffsetX ~= 0 then
				vehicle.cp.hud.content.pages[7][5][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.loadUnloadOffsetX), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.loadUnloadOffsetX > 0 and 'COURSEPLAY_RIGHT' or 'COURSEPLAY_LEFT'));
			else
				vehicle.cp.hud.content.pages[7][5][2].text = '---';
			end;

			--load/Unload vertical offset
			vehicle.cp.hud.content.pages[7][6][1].text = courseplay:loc('COURSEPLAY_LOAD_UNLOAD_OFFSET_Z');
			if vehicle.cp.loadUnloadOffsetZ and vehicle.cp.loadUnloadOffsetZ ~= 0 then
				vehicle.cp.hud.content.pages[7][6][2].text = ('%.1f%s (%s)'):format(abs(vehicle.cp.loadUnloadOffsetZ), courseplay:loc('COURSEPLAY_UNIT_METER'), courseplay:loc(vehicle.cp.loadUnloadOffsetZ > 0 and 'COURSEPLAY_FRONT' or 'COURSEPLAY_BACK'));
			else
				vehicle.cp.hud.content.pages[7][6][2].text = '---';
			end;
		end;

		--Copy course from driver
		vehicle.cp.hud.content.pages[7][7][1].text = courseplay:loc('COURSEPLAY_COPY_COURSE');
		if vehicle.cp.copyCourseFromDriver ~= nil then
			local driverName = vehicle.cp.copyCourseFromDriver.name or courseplay:loc('COURSEPLAY_VEHICLE');
			local dist = courseplay:distanceToObject(vehicle, vehicle.cp.copyCourseFromDriver);
			if dist >= 1000 then
				vehicle.cp.hud.content.pages[7][7][2].text = ('%s (%.1f%s)'):format(driverName, dist * 0.001, courseplay:getMeasuringUnit());
			else
				vehicle.cp.hud.content.pages[7][7][2].text = ('%s (%d%s)'):format(driverName, dist, courseplay:loc('COURSEPLAY_UNIT_METER'));
			end;
			vehicle.cp.hud.content.pages[7][8][2].text = '(' .. (vehicle.cp.copyCourseFromDriver.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE')) .. ')';
		else
			vehicle.cp.hud.content.pages[7][7][2].text = courseplay:loc('COURSEPLAY_NONE');
		end;

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
			if vehicle.cp.startingCorner == 6 then
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
		vehicle.cp.hud.content.pages[8][6][3].text = vehicle.cp.headland.numLanes ~= 0 and tostring(vehicle.cp.headland.numLanes) or '-';
		-- only allow for the new course generator
		if vehicle.cp.headland.numLanes > 0 and vehicle.cp.isNewCourseGenSelected() then
			vehicle.cp.hud.content.pages[8][6][2].text = courseplay:loc( courseplay.turnTypeText[ vehicle.cp.headland.turnType ])
		else
			vehicle.cp.hud.content.pages[8][6][2].text = '---'
		end

		-- line 7 = bypass islands
		vehicle.cp.hud.content.pages[8][7][1].text = courseplay:loc('COURSEPLAY_BYPASS_ISLANDS');
		-- only allow for the new course generator
		if vehicle.cp.isNewCourseGenSelected() then
			vehicle.cp.hud.content.pages[8][7][2].text = courseplay:loc( Island.bypassModeText[ vehicle.cp.islandBypassMode ]);
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

	self:setReloadPageOrder(vehicle, page, false);
end;

function courseplay.hud:setReloadPageOrder(vehicle, page, bool)
	-- self = courseplay.hud

	if vehicle.cp.hud.reloadPage[page] ~= bool then
		vehicle.cp.hud.reloadPage[page] = bool;
		if courseplay.debugChannels[18] and bool == true then
			courseplay:debug(string.format('%s: set reloadPage[%d] to %s (called from %s)', nameNum(vehicle), page, tostring(bool), courseplay.utils:getFnCallPath(4)), 18);
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
		bg				  = Overlay:new('cpHud1', gfxPath, self.basePosX, self.basePosY, self.baseWidth, self.baseHeight);
		bgWithModeButtons = Overlay:new('cpHud2', gfxPath, self.basePosX, self.basePosY, self.baseWidth, self.baseHeight);
		suc				  = Overlay:new('cpHud3', gfxPath, self.suc.x1,	  self.suc.y1,	 self.suc.width, self.suc.height);
		currentPage = 1;
		show = false;
		openWithMouse = true;
		firstTimeSetContent = true;
		content = {
			bottomInfo = {};
			pages = {};
		};
		mouseWheel = {
			icon = Overlay:new('cpMouseWheelIcon', courseplay.path .. 'img/mouseIcons/mouseMMB.png', 0, 0, w32pxConstant, h32pxConstant); -- FS15
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
	vehicle.cp.directionArrowOverlay = Overlay:new('cpDistArrow_' .. tostring(self.rootNode), Utils.getFilename('img/arrow.png', courseplay.path), self.directionArrowPosX, self.directionArrowPosY, self.directionArrowWidth, self.directionArrowHeight);

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
	vehicle.cp.hud.courseListPrev = false;
	vehicle.cp.hud.courseListNext = false; -- will be updated after loading courses into the hud

	--Camera backups: allowTranslation
	vehicle.cp.camerasBackup = {};
	for camIndex, camera in pairs(vehicle.cameras) do
		if camera.allowTranslation then
			vehicle.cp.camerasBackup[camIndex] = camera.allowTranslation;
		end;
	end;

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

	vehicle.cp.attachedCombine = nil;
	courseplay:setMinHudPage(vehicle);

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
	local posY = self.basePosY + self:pxToNormal(300, 'y');
	local totalWidth = ((self.numPages + 1) * wBig) + (self.numPages * marginBig); --numPages=9, real numPages=10
	local baseX = self.baseCenterPosX - totalWidth/2;
	for p=0, self.numPages do
		local posX = baseX + (p * (wBig + marginBig));
		local toolTip = self.pageTitles[p];
		if p == 2 then
			toolTip = self.pageTitles[p][1];
		end;
		courseplay.button:new(vehicle, 'global', 'iconSprite.png', 'setHudPage', p, posX, posY, wBig, hBig, nil, nil, false, false, false, toolTip);
	end;

	local closeX = self.visibleArea.x2 - marginMiddle - wMiddle;
	local closeY = self.basePosY + self:pxToNormal(280, 'y');
	courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'close' }, 'openCloseHud', false, closeX, closeY, wMiddle, hMiddle);

	courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'save' }, 'showSaveCourseForm', 'course', topIconsX[3], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_SAVE_CURRENT_COURSE'));

	vehicle.cp.changeDrawCourseModeButton = courseplay.button:new(vehicle, 'global', { 'iconSprite.png', 'eye' }, 'changeDrawCourseMode', 1, self.col1posX, self.topIconsY, wMiddle, hMiddle, nil, -1, false, false, true);


	-- ##################################################
	-- Page 0: Combine controls
	for i=1, self.numLines do
		if ( i == 7 ) then
			courseplay.button:new(vehicle, 0, nil, 'changeHeadlandReverseManeuverType', nil, self.col1posX, self.linesPosY[i], self.contentMaxWidth, self.lineHeight, i, nil, true);
		else
			courseplay.button:new(vehicle, 0, nil, "rowButton", i, self.basePosX, self.linesPosY[i], self.contentMaxWidth, self.lineHeight, i, nil, true);
		end
	end;


	-- ##################################################
	-- Page 1
	-- setCpMode buttons
	local totalWidth = (courseplay.NUM_MODES * wBig) + ((courseplay.NUM_MODES - 1) * marginBig);
	local baseX = self.baseCenterPosX - totalWidth/2;
	local y = self.linesButtonPosY[8] + self:pxToNormal(2, 'y');
	for i=1, courseplay.NUM_MODES do
		local posX = baseX + ((i - 1) * (wBig + marginBig));
		local toolTip = courseplay:loc(('COURSEPLAY_MODE_%d'):format(i));

		courseplay.button:new(vehicle, 1, 'iconSprite.png', 'setCpMode', i, posX, y, wBig, hBig, nil, nil, false, false, false, toolTip);
	end;

	-- recording
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
	local totalWidth = (#recordingData - 1) * (wBig + marginBig) + wBig;
	local baseX = self.baseCenterPosX - totalWidth * 0.5;
	for i,data in pairs(recordingData) do
		local posX = baseX + ((wBig + marginBig) * (i-1));
		local fn = data[2];
		local isToggleButton = data[3];
		local toolTip = courseplay:loc(data[4]);
		local button = courseplay.button:new(vehicle, 1, { 'iconSprite.png', data[1] }, fn, nil, posX, self.linesButtonPosY[2], wBig, hBig, nil, nil, false, false, isToggleButton, toolTip);
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

	-- row buttons
	local w = self.buttonPosX[2] - self.col1posX;
	for i=1, self.numLines do
		courseplay.button:new(vehicle, 1, nil, 'rowButton', i, self.col1posX, self.linesPosY[i], w, self.lineHeight, i, nil, true);
	end;

	--Number of Runs For Mode1
 	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navMinus' }, 'changeRunNumber', -1, self.buttonPosX[2], self.linesButtonPosY[5], wSmall, hSmall, 5, -5, false);
 	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navPlus' },  'changeRunNumber',  1, self.buttonPosX[1], self.linesButtonPosY[5], wSmall, hSmall, 5,  5, false);
 	courseplay.button:new(vehicle, 1, nil, 'changeRunNumber', 1, mouseWheelArea.x, self.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, nil, true, true);

	-- Silo Fill Type Selector
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navLeft' },  'changeSiloFillType', -1, self.buttonPosX[2], self.linesButtonPosY[6], wSmall, hSmall, 6, -1, false);
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navRight' }, 'changeSiloFillType',  1, self.buttonPosX[1], self.linesButtonPosY[6], wSmall, hSmall, 6,  1, false);
	courseplay.button:new(vehicle, 1, nil, 'changeSiloFillType', 1, mouseWheelArea.x, self.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, nil, true, true);

	-- Custom field edge path
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'cancel' }, 'clearCustomFieldEdge', nil, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'eye' }, 'toggleCustomFieldEdgePathShow', nil, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);

	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navMinus' }, 'setCustomFieldEdgePathNumber', -1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, -5, false);
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'navPlus' },  'setCustomFieldEdgePathNumber',  1, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4,  5, false);
	courseplay.button:new(vehicle, 1, nil, 'setCustomFieldEdgePathNumber', 1, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	-- Find first waypoint
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'search' }, 'toggleFindFirstWaypoint', nil, topIconsX[1], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, true, courseplay:loc('COURSEPLAY_SEARCH_FOR_FIRST_WAYPOINT'));

	-- Clear current course
	vehicle.cp.hud.clearCurrentCourseButton1 = courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'courseClear' }, 'clearCurrentLoadedCourse', nil, topIconsX[0], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_CLEAR_COURSE'));

	--go to pipe position in mode3
	courseplay.button:new(vehicle, 1, { 'iconSprite.png', 'recordingPlay' }, 'movePipeToPosition', 1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, nil, true, false, false, courseplay:loc('COURSEPLAY_MOVE_PIPE_TO_POSITION'));
					
	-- ##################################################
	-- Page 2: Course management
	--course navigation
	local arrowPosYTop = self.linesButtonPosY[1];
	local arrowPosYBottom = self.linesButtonPosY[1];
	courseplay.button:new(vehicle, 2, { 'iconSprite.png', 'navUp' },   'shiftHudCourses', -self.numLines, listArrowX, self.linesButtonPosY[1],			   wMiddle, hMiddle, nil, -self.numLines*2);
	courseplay.button:new(vehicle, 2, { 'iconSprite.png', 'navDown' }, 'shiftHudCourses',  self.numLines, listArrowX, self.linesButtonPosY[self.numLines], wMiddle, hMiddle, nil,  self.numLines*2);

	local courseListMouseWheelArea = {
		x = mouseWheelArea.x,
		y = self.linesPosY[self.numLines],
		width = mouseWheelArea.w,
		height = self.linesPosY[1] + self.lineHeight - self.linesPosY[self.numLines]
	};
	courseplay.button:new(vehicle, 2, nil, 'shiftHudCourses',  -1, courseListMouseWheelArea.x, courseListMouseWheelArea.y, courseListMouseWheelArea.width, courseListMouseWheelArea.height, nil, -self.numLines, nil, true);

	-- course actions
	local hoverAreaWidth = self.buttonCoursesPosX[2] + wSmall - self.buttonCoursesPosX[4];
	if g_server ~= nil then
		hoverAreaWidth = self.buttonCoursesPosX[1] + wSmall - self.buttonCoursesPosX[4];
	end;
	for i=1, self.numLines do
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'navPlus' }, 'expandFolder', i, self.buttonCoursesPosX[0], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false);
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'courseLoadAppend' }, 'loadSortedCourse', i, self.buttonCoursesPosX[4], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_LOAD_COURSE'));
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'courseAdd' }, 'addSortedCourse', i, self.buttonCoursesPosX[3], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_APPEND_COURSE'));
		courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'folderParentFrom' }, 'linkParent', i, self.buttonCoursesPosX[2], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_MOVE_TO_FOLDER'));
		--if g_server ~= nil then
			courseplay.button:new(vehicle, -2, { 'iconSprite.png', 'delete' }, 'deleteSortedItem', i, self.buttonCoursesPosX[1], self.linesButtonPosY[i], wSmall, hSmall, i, nil, false, false, false, courseplay:loc('COURSEPLAY_DELETE_COURSE'));
		--end;
		courseplay.button:new(vehicle, -2, nil, nil, nil, self.buttonCoursesPosX[4], self.linesButtonPosY[i], hoverAreaWidth, mouseWheelArea.h, i, nil, true, false);
	end;
	vehicle.cp.hud.clearCurrentCourseButton2 = courseplay.button:new(vehicle, 2, { 'iconSprite.png', 'courseClear' }, 'clearCurrentLoadedCourse', nil, topIconsX[0], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_CLEAR_COURSE'));
	vehicle.cp.hud.filterButton = courseplay.button:new(vehicle, 2, { 'iconSprite.png', 'search' }, 'showSaveCourseForm', 'filter', topIconsX[1], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_SEARCH_FOR_COURSES_AND_FOLDERS'));
	courseplay.button:new(vehicle, 2, { 'iconSprite.png', 'folderNew' }, 'showSaveCourseForm', 'folder', topIconsX[2], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_CREATE_FOLDER'));
	vehicle.cp.hud.reloadCourses = courseplay.button:new(vehicle, 2, { 'iconSprite.png', 'refresh' }, 'reloadCoursesFromXML', nil, topIconsX[0], self.topIconsY, wMiddle, hMiddle, nil, nil, false, false, false, courseplay:loc('COURSEPLAY_RELOAD_COURSE_LIST'));


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

	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navMinus' }, 'changeTurnDiameter', -1, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3, -5, false);
	courseplay.button:new(vehicle, 3, { 'iconSprite.png', 'navPlus' },  'changeTurnDiameter',  1, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3,  5, false);
	courseplay.button:new(vehicle, 3, nil, 'changeTurnDiameter', 1, mouseWheelArea.x, self.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

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

	-- Plough to Field Edge
	courseplay.button:new(vehicle, 3, nil, 'togglePloughFieldEdge', nil,  self.contentMinX, self.linesPosY[7], self.contentMaxWidth, self.lineHeight, 7, nil, true);
	courseplay.button:new(vehicle, 3, nil, 'toggleAlignmentWaypoint', nil,  self.contentMinX, self.linesPosY[8], self.contentMaxWidth, self.lineHeight, 8, nil, true);


	-- ##################################################
	-- Page 4: Combine management
	courseplay.button:new(vehicle, 4, nil, 'toggleSearchCombineMode', nil, self.col1posX, self.linesPosY[1], self.visibleArea.width, self.lineHeight, 1, nil, true);

	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navUp' },   'selectAssignedCombine', -1, self.buttonPosX[2], self.linesButtonPosY[2], wSmall, hSmall, 2, nil, false);
	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navDown' }, 'selectAssignedCombine',  1, self.buttonPosX[1], self.linesButtonPosY[2], wSmall, hSmall, 2, nil, false);
	courseplay.button:new(vehicle, 4, nil, 'selectAssignedCombine', -1, mouseWheelArea.x, self.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, -1, true, true);
	
	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navUp' },   'setSearchCombineOnField', -1, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);
	courseplay.button:new(vehicle, 4, { 'iconSprite.png', 'navDown' }, 'setSearchCombineOnField',  1, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3, nil, false);
	courseplay.button:new(vehicle, 4, nil, 'setSearchCombineOnField', -1, mouseWheelArea.x, self.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, -5, true, true);
	

	courseplay.button:new(vehicle, 4, nil, 'removeActiveCombineFromTractor', nil, self.col1posX, self.linesPosY[5], self.contentMaxWidth, self.lineHeight, 5, nil, true);


	-- ##################################################
	-- Page 5: Speeds
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navMinus' }, 'changeTurnSpeed',   -1, self.buttonPosX[2], self.linesButtonPosY[1], wSmall, hSmall, 1, -5, false);
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navPlus' },  'changeTurnSpeed',    1, self.buttonPosX[1], self.linesButtonPosY[1], wSmall, hSmall, 1,  5, false);
	courseplay.button:new(vehicle, 5, nil, 'changeTurnSpeed', 1, mouseWheelArea.x, self.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 5, true, true);

	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navMinus' }, 'changeFieldSpeed',  -1, self.buttonPosX[2], self.linesButtonPosY[2], wSmall, hSmall, 2, -5, false);
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navPlus' },  'changeFieldSpeed',   1, self.buttonPosX[1], self.linesButtonPosY[2], wSmall, hSmall, 2,  5, false);
	courseplay.button:new(vehicle, 5, nil, 'changeFieldSpeed', 1, mouseWheelArea.x, self.linesButtonPosY[2], mouseWheelArea.w, mouseWheelArea.h, 2, 5, true, true);

	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navMinus' }, 'changeMaxSpeed',    -1, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3, -5, false);
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navPlus' },  'changeMaxSpeed',     1, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3,  5, false);
	courseplay.button:new(vehicle, 5, nil, 'changeMaxSpeed', 1, mouseWheelArea.x, self.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 5, true, true);

	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navMinus' }, 'changeReverseSpeed', -1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, -5, false);
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navPlus' },  'changeReverseSpeed',  1, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4,  5, false);
	courseplay.button:new(vehicle, 5, nil, 'changeReverseSpeed', 1, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 5, true, true);

	courseplay.button:new(vehicle, 5, nil, 'toggleUseRecordingSpeed', nil, self.contentMinX, self.linesPosY[5], self.contentMaxWidth, self.lineHeight, 5, nil, true);
	
	courseplay.button:new(vehicle, 5, nil, 'toggleFuelSaveOption', nil, self.contentMinX, self.linesPosY[8], self.contentMaxWidth, self.lineHeight, 8, nil, true);

	-- 4WD button in line 5: only added if driveControl and 4WD exist
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navLeft' },  'changeDriveControlMode', -1, self.buttonPosX[2], self.linesButtonPosY[7], wSmall, hSmall, 7, -1, false);
	courseplay.button:new(vehicle, 5, { 'iconSprite.png', 'navRight' }, 'changeDriveControlMode',  1, self.buttonPosX[1], self.linesButtonPosY[7], wSmall, hSmall, 7, -1, false);


	-- ##################################################
	-- Page 6: General settings
	local pg = self.PAGE_GENERAL_SETTINGS;

	-- realistic driving
	courseplay.button:new(vehicle, pg, nil, 'toggleRealisticDriving', nil,  self.contentMinX, self.linesPosY[1], self.contentMaxWidth, self.lineHeight, 1, nil, true);

	-- open hud with mouse/keyboard
	courseplay.button:new(vehicle, pg, nil, 'toggleOpenHudWithMouse', nil,  self.contentMinX, self.linesPosY[2], self.contentMaxWidth, self.lineHeight, 2, nil, true);

	-- visual waypoint signs
	local btnW = wSmall * 2 + wSmall/8;
	vehicle.cp.visualWaypointsStartEndButton1 = courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'waypointSignsStart' }, 'toggleShowVisualWaypointsStartEnd', nil, self.col2posX[pg], self.linesButtonPosY[3], btnW, hSmall, 3, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_STARTEND'));
	vehicle.cp.visualWaypointsAllEndButton = courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'waypointSignsAll' }, 'toggleShowVisualWaypointsAll', nil, self.col2posX[pg] + btnW * 1.5, self.linesButtonPosY[3], btnW, hSmall, 3, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_ALL'));
	vehicle.cp.visualWaypointsStartEndButton2 = courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'waypointSignsEnd' }, 'toggleShowVisualWaypointsStartEnd', nil, self.col2posX[pg] + btnW * 3, self.linesButtonPosY[3], btnW, hSmall, 3, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_STARTEND'));
	vehicle.cp.visualWaypointsCrossingButton = courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'recordingCross' }, 'toggleShowVisualWaypointsCrossing', nil, self.col2posX[pg] + btnW * 4.5, self.linesButtonPosY[3], wSmall, hSmall, 3, nil, true, false, true, courseplay:loc('COURSEPLAY_VISUALWAYPOINTS_CROSSING'));

	-- warning lights
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'navLeft' },  'changeWarningLightsMode', -1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4, -1, false);
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'navRight' }, 'changeWarningLightsMode',  1, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4,  1, false);

	-- wait time
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'navMinus' }, 'changeWaitTime', -1, self.buttonPosX[2], self.linesButtonPosY[5], wSmall, hSmall, 5, -5, false);
	courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'navPlus' },  'changeWaitTime',  1, self.buttonPosX[1], self.linesButtonPosY[5], wSmall, hSmall, 5,  5, false);
	courseplay.button:new(vehicle, pg, nil, 'changeWaitTime', 1, mouseWheelArea.x, self.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 5, true, true);

	-- ingame map show text
	if CpManager.ingameMapIconActive and CpManager.ingameMapIconShowTextLoaded then
		courseplay.button:new(vehicle, pg, nil, 'toggleIngameMapIconShowText', nil, self.contentMinX, self.linesPosY[6], self.contentMaxWidth, self.lineHeight, 6, nil, true);
	end;
	
	courseplay.button:new(vehicle, pg, nil, 'toggleAutoRefuel', nil,  self.contentMinX, self.linesPosY[7], self.contentMaxWidth, self.lineHeight, 7, nil, true);

	-- debug channels
	if courseplay.isDevVersion then 
		vehicle.cp.hud.debugChannelButtons = {};
		for dbg=1, courseplay.numDebugChannelButtonsPerLine do
			local data = courseplay.debugButtonPosData[dbg];
			local toolTip = courseplay.debugChannelsDesc[dbg];
			vehicle.cp.hud.debugChannelButtons[dbg] = courseplay.button:new(vehicle, pg, 'iconSprite.png', 'toggleDebugChannel', dbg, data.posX, data.posY, data.width, data.height, nil, nil, nil, false, false, toolTip);
		end;
		courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'navUp' },   'changeDebugChannelSection', -1, self.buttonPosX[2], self.linesButtonPosY[8], wSmall, hSmall, 8, -1, true, false);
		courseplay.button:new(vehicle, pg, { 'iconSprite.png', 'navDown' }, 'changeDebugChannelSection',  1, self.buttonPosX[1], self.linesButtonPosY[8], wSmall, hSmall, 8,  1, true, false);
		courseplay.button:new(vehicle, pg, nil, 'changeDebugChannelSection', -1, mouseWheelArea.x, self.linesButtonPosY[8], mouseWheelArea.w, mouseWheelArea.h, 8, -1, true, true);
	end

	-- ##################################################
	-- Page 7: Driving settings
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navLeft' },  'changeLaneOffset', -0.1, self.buttonPosX[2], self.linesButtonPosY[1], wSmall, hSmall, 1, -0.5, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navRight' }, 'changeLaneOffset',  0.1, self.buttonPosX[1], self.linesButtonPosY[1], wSmall, hSmall, 1,  0.5, false);
	courseplay.button:new(vehicle, 7, nil, 'changeLaneOffset', 0.1, mouseWheelArea.x, self.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, 0.5, true, true);
	
	--Lane Number
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navLeft' },  'changeLaneNumber', -1, self.buttonPosX[2], self.linesButtonPosY[1], wSmall, hSmall, 1, nil, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navRight' }, 'changeLaneNumber',  1, self.buttonPosX[1], self.linesButtonPosY[1], wSmall, hSmall, 1,  nil, false);
	courseplay.button:new(vehicle, 7, nil, 'changeLaneNumber', 1, mouseWheelArea.x, self.linesButtonPosY[1], mouseWheelArea.w, mouseWheelArea.h, 1, nil, true, true);

	courseplay.button:new(vehicle, 7, nil, 'toggleSymmetricLaneChange', nil, self.contentMinX, self.linesPosY[2], self.contentMaxWidth, self.lineHeight, 2, nil, true);

	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navLeft' },  'changeToolOffsetX', -0.1, self.buttonPosX[2], self.linesButtonPosY[3], wSmall, hSmall, 3,  -0.5, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navRight' }, 'changeToolOffsetX',  0.1, self.buttonPosX[1], self.linesButtonPosY[3], wSmall, hSmall, 3,   0.5, false);
	courseplay.button:new(vehicle, 7, nil, 'changeToolOffsetX', 0.1, mouseWheelArea.x, self.linesButtonPosY[3], mouseWheelArea.w, mouseWheelArea.h, 3, 0.5, true, true);

	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navDown' }, 'changeToolOffsetZ', -0.1, self.buttonPosX[2], self.linesButtonPosY[4], wSmall, hSmall, 4,  -0.5, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navUp' },   'changeToolOffsetZ',  0.1, self.buttonPosX[1], self.linesButtonPosY[4], wSmall, hSmall, 4,   0.5, false);
	courseplay.button:new(vehicle, 7, nil, 'changeToolOffsetZ', 0.1, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 4, 0.5, true, true);

	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navLeft' },  'changeLoadUnloadOffsetX', -0.1, self.buttonPosX[2], self.linesButtonPosY[5], wSmall, hSmall, 5,  -0.5, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navRight' }, 'changeLoadUnloadOffsetX',  0.1, self.buttonPosX[1], self.linesButtonPosY[5], wSmall, hSmall, 5,   0.5, false);
	courseplay.button:new(vehicle, 7, nil, 'changeLoadUnloadOffsetX', 0.1, mouseWheelArea.x, self.linesButtonPosY[5], mouseWheelArea.w, mouseWheelArea.h, 5, 0.5, true, true);

	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navDown' }, 'changeLoadUnloadOffsetZ', -0.1, self.buttonPosX[2], self.linesButtonPosY[6], wSmall, hSmall, 6,  -0.5, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navUp' },   'changeLoadUnloadOffsetZ',  0.1, self.buttonPosX[1], self.linesButtonPosY[6], wSmall, hSmall, 6,   0.5, false);
	courseplay.button:new(vehicle, 7, nil, 'changeLoadUnloadOffsetZ', 0.1, mouseWheelArea.x, self.linesButtonPosY[6], mouseWheelArea.w, mouseWheelArea.h, 6, 0.5, true, true);

	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navDown' },   'switchDriverCopy', -1, self.buttonPosX[2], self.linesButtonPosY[7], wSmall, hSmall, 7, nil, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'navUp' }, 'switchDriverCopy',  1, self.buttonPosX[1], self.linesButtonPosY[7], wSmall, hSmall, 7, nil, false);
	courseplay.button:new(vehicle, 7, nil, nil, nil, self.buttonPosX[2], self.linesButtonPosY[7], wSmall * 2 + self.buttonSize.small.margin, mouseWheelArea.h, 7, nil, true, false);
	courseplay.button:new(vehicle, 7, { 'iconSprite.png', 'copy' }, 'copyCourse', nil, self.buttonPosX[1], self.linesButtonPosY[8], wSmall, hSmall);


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
	courseplay.button:new(vehicle, 8, nil, 'changeRowAngle', 1, mouseWheelArea.x, self.linesButtonPosY[4], mouseWheelArea.w, mouseWheelArea.h, 2, 0.5, true, true);
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
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navDown' }, 'changeMultiTools', -1, self.buttonPosX[2], self.linesButtonPosY[8], wSmall, hSmall, 8,  nil, false);
	courseplay.button:new(vehicle, 8, { 'iconSprite.png', 'navUp' },   'changeMultiTools',  1, self.buttonPosX[1], self.linesButtonPosY[8], wSmall, hSmall, 8,  nil, false);
	courseplay.button:new(vehicle, 8, nil, 'changeMultiTools',1, mouseWheelArea.x, self.linesButtonPosY[8], mouseWheelArea.w, mouseWheelArea.h, 8, nil, true, true);

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
	
	-- ##################################################
	-- Status icons
	local bi = self.bottomInfo;
	local w = bi.iconWidth;
	local h = bi.iconHeight;
	local sizeX,sizeY = self.iconSpriteSize.x, self.iconSpriteSize.y;
	-- current mode icon
	vehicle.cp.hud.currentModeIcon = Overlay:new('cpCurrentModeIcon', self.iconSpritePath, bi.modeIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.currentModeIcon, bi.modeUVsPx[vehicle.cp.mode], sizeX, sizeY);

	-- waypoint icon
	vehicle.cp.hud.currentWaypointIcon = Overlay:new('cpCurrentWaypointIcon', self.iconSpritePath, bi.waypointIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.currentWaypointIcon, { 4, 180, 36, 148 }, sizeX, sizeY);

	-- waitPoints icon
	vehicle.cp.hud.waitPointsIcon = Overlay:new('cpWaitPointsIcon', self.iconSpritePath, bi.waitPointsIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.waitPointsIcon, self.buttonUVsPx['recordingWait'], sizeX, sizeY);

	-- crossingPoints icon
	vehicle.cp.hud.crossingPointsIcon = Overlay:new('cpCrossingPointsIcon', self.iconSpritePath, bi.crossingPointsIconX, bi.iconPosY, w, h);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.crossingPointsIcon, self.buttonUVsPx['recordingCross'], sizeX, sizeY);

	-- toolTip icon
	vehicle.cp.hud.toolTipIcon = Overlay:new('cpToolTipIcon', self.iconSpritePath, self.toolTipIconPosX, self.toolTipIconPosY, self.toolTipIconWidth, self.toolTipIconHeight);
	courseplay.utils:setOverlayUVsPx(vehicle.cp.hud.toolTipIcon, { 112, 180, 144, 148 }, sizeX, sizeY);
end;
-- do not remove this comment
-- vim: set noexpandtab:
