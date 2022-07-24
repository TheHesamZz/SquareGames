min, max, cos, sin, rad, deg, atan2 = math.min, math.max, math.cos, math.sin, math.rad, math.deg, math.atan2
sqrt, abs, floor, ceil, random = math.sqrt, math.abs, math.floor, math.ceil, math.random
gsub = string.gsub

local Display = {}
Display.Width, Display.Height = guiGetScreenSize()

local Minimap = {}
Minimap.Width = 275
Minimap.Height = 160
Minimap.PosX = 3
Minimap.PosY = (Display.Height - 3) - Minimap.Height

Minimap.IsVisible = true
Minimap.TextureSize = 3072
Minimap.NormalTargetSize, Minimap.BiggerTargetSize = Minimap.Width, Minimap.Width * 2
Minimap.MapTarget = dxCreateRenderTarget(Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, true)
Minimap.RenderTarget = dxCreateRenderTarget(Minimap.NormalTargetSize * 3, Minimap.NormalTargetSize * 3, true)
Minimap.MapTexture = dxCreateTexture('files/images/radar.jpg')
Minimap.MapTextureHd = dxCreateTexture('files/images/radarhd.jpg')

Minimap.CurrentZoom = 3
Minimap.MaximumZoom = 10
Minimap.MinimumZoom = 2

Minimap.WaterColor = {0,120,210}
Minimap.WaterColorHd = {65,71,87}
Minimap.Alpha = 255
Minimap.PlayerInVehicle = false
Minimap.LostRotation = 0
Minimap.MapUnit = Minimap.TextureSize / 6000

local Bigmap = {}
Bigmap.Width, Bigmap.Height = Display.Width - 40, Display.Height - 40
Bigmap.PosX, Bigmap.PosY = 20, 20
Bigmap.IsVisible = false
Bigmap.CurrentZoom = 1.5
Bigmap.MinimumZoom = 0.5
Bigmap.MaximumZoom = 3
Bigmap.CenterX = Bigmap.PosX + Bigmap.Width / 2
Bigmap.CenterY = Bigmap.PosY + Bigmap.Height / 2

local Fonts = {}
Fonts.Loc = dxCreateFont('files/fonts/roboto.ttf', 25, false, 'antialiased')
Fonts.Roboto = dxCreateFont('files/fonts/roboto.ttf', 10, false, 'antialiased')
Fonts.Icons = dxCreateFont('files/fonts/icons.ttf', 25, false, 'antialiased')

local Stats = {}
Stats.Bar = {}
Stats.Bar.Width = Minimap.Width
Stats.Bar.Height = 10

occupiedVehicle = false
local playerX, playerY, playerZ = 0, 0, 0
local mapOffsetX, mapOffsetY, mapIsMoving = 0, 0, false

reMap = function(value, low1, high1, low2, high2)
	return low2 + (value - low1) * (high2 - low2) / (high1 - low1)
end

responsiveMultiplier = math.min(1, reMap(Display.Width, 1024, 1920, 0.75, 1))

resp = function(value)
	return value * responsiveMultiplier
end

respc = function(value)
	return ceil(value * responsiveMultiplier)
end

local zoneLineHeight = respc(30)
local screenSource = dxCreateScreenSource(Display.Width, Display.Height)

local gpsLineWidth = respc(60)
local gpsLineIconSize = respc(40)
local gpsLineIconHalfSize = gpsLineIconSize / 2
local createdTextures = {}

local gpsLines = {}
local gpsRouteImage = false
local gpsRouteImageData = {}

local minimapRenderSize = 550

addEventHandler('onClientResourceStart', resourceRoot,
function()
	setPlayerHudComponentVisible ( "all", false )
	setPlayerHudComponentVisible ( "crosshair", true )
	occupiedVehicle = getPedOccupiedVehicle(localPlayer)
end
)

addEventHandler("onClientElementDataChange", getRootElement(),
function (dataName, oldValue)
	if source == occupiedVehicle then
		if dataName == "gpsDestination" then
			local dataValue = getElementData(source, dataName) or false
			if dataValue then
				gpsThread = coroutine.create(makeRoute)
				coroutine.resume(gpsThread, unpack(dataValue))
				waypointInterpolation = false
			else
				endRoute()
			end
		end
	end
end
)

addEventHandler('onClientKey', root,
	function(key, state) 
		if (state) then
			if (key == 'F11') then
				cancelEvent()
				if getElementData(localPlayer,"character:login") == 0 then return end
				Bigmap.IsVisible = not Bigmap.IsVisible
				showCursor(false)
				if (Bigmap.IsVisible) then
					setPlayerHudComponentVisible('all', false)
					playSound("files/f11radaropen.mp3")
					showCursor(true)
                    setElementData(localPlayer, "showradar", true)					
                    showChat(false)
					Minimap.IsVisible = false
				    executeCommandHandler ( "showkilometer" )
				else
					setPlayerHudComponentVisible('all', false)
					setPlayerHudComponentVisible('crosshair', true)
					playSound("files/f11radarclose.mp3")
					showCursor(false)
					setElementData(localPlayer, "showradar", nil)	
					showChat(true)
					Minimap.IsVisible = true
					executeCommandHandler ( "showkilometer" )
					mapOffsetX, mapOffsetY, mapIsMoving = 0, 0, false
				end
			elseif (key == 'mouse_wheel_down' and Bigmap.IsVisible) then
				Bigmap.CurrentZoom = math.min(Bigmap.CurrentZoom + 0.5, Bigmap.MaximumZoom)
			elseif (key == 'mouse_wheel_up' and Bigmap.IsVisible) then
				Bigmap.CurrentZoom = math.max(Bigmap.CurrentZoom - 0.5, Bigmap.MinimumZoom)
			elseif (key == 'lctrl' and Bigmap.IsVisible) then
				showCursor(not isCursorShowing())
			end
		end
	end
)

addCommandHandler("showradar", function()
	if (Minimap.IsVisible) then
		playSoundFrontEnd(1)
		Minimap.IsVisible = false
	else
		playSoundFrontEnd(2)
		Minimap.IsVisible = true
		mapOffsetX, mapOffsetY, mapIsMoving = 0, 0, false
	end
end )


addEventHandler("onClientClick", root,
function(button, state, cursorX, cursorY)
	if (not Bigmap.IsVisible) then return end
	
	if (button == "left" and state == "down") then
		if (cursorX >= Bigmap.PosX and cursorX <= Bigmap.PosX + Bigmap.Width) then
			if (cursorY >= Bigmap.PosY and cursorY <= Bigmap.PosY + Bigmap.Height) then
				mapOffsetX = cursorX * Bigmap.CurrentZoom + playerX
				mapOffsetY = cursorY * Bigmap.CurrentZoom - playerY
				mapIsMoving = true
			end
		end
	end
			
	if state == "up" and mapIsMoving then
		mapIsMoving = false
		--return
	end
end
)

addEventHandler("onClientRender", getRootElement(),
function ()
	if getElementData(localPlayer, "character:login") == 1 then
		renderMinimap()
		renderTheBigmap()
	end
end
)

function renderTheBigmap()
	if (not Bigmap.IsVisible) then
		return 
	end
	
	dxDrawBorder(Bigmap.PosX, Bigmap.PosY, Bigmap.Width, Bigmap.Height, 2, tocolor(0, 0, 0, 200))
			
	local absoluteX, absoluteY = 0, 0
			local zoneName = 'Unknown'
			
			if (getElementInterior(localPlayer) == 0 and getElementDimension(localPlayer) == 0) then
				if (isCursorShowing()) then
					local cursorX, cursorY = getCursorPosition()
					local mapX, mapY = getWorldFromMapPosition(cursorX, cursorY)
					
					absoluteX = cursorX * Display.Width
					absoluteY = cursorY * Display.Height
					
					if (getKeyState('mouse1') and mapIsMoving) then
						playerX = -(absoluteX * Bigmap.CurrentZoom - mapOffsetX)
						playerY = absoluteY * Bigmap.CurrentZoom - mapOffsetY
						
						playerX = math.max(-3000, math.min(3000, playerX))
						playerY = math.max(-3000, math.min(3000, playerY))
					end
					
					if (not mapIsMoving) then
						if (Bigmap.PosX <= absoluteX and Bigmap.PosY <= absoluteY and Bigmap.PosX + Bigmap.Width >= absoluteX and Bigmap.PosY + Bigmap.Height >= absoluteY) then
							zoneName = getZoneName(mapX, mapY, 0)
						else
							zoneName = 'Unknown'
						end
					else
						zoneName = 'Unknown'
					end
				else
					playerX, playerY, playerZ = getElementPosition(localPlayer)
					zoneName = getZoneName(playerX, playerY, playerZ)
				end
				
				local playerRotation = getPedRotation(localPlayer)
				local mapX = (((3000 + playerX) * Minimap.MapUnit) - (Bigmap.Width / 2) * Bigmap.CurrentZoom)
				local mapY = (((3000 - playerY) * Minimap.MapUnit) - (Bigmap.Height / 2) * Bigmap.CurrentZoom)
				local mapWidth, mapHeight = Bigmap.Width * Bigmap.CurrentZoom, Bigmap.Height * Bigmap.CurrentZoom
                if getElementData(localPlayer,"HDMAP") then
				dxDrawImageSection(Bigmap.PosX, Bigmap.PosY, Bigmap.Width, Bigmap.Height, mapX, mapY, mapWidth, mapHeight, Minimap.MapTextureHd, 0, 0, 0, tocolor(255, 255, 255, Minimap.Alpha))
				dxSetTextureEdge(Minimap.MapTextureHd, 'border', tocolor(Minimap.WaterColorHd[1], Minimap.WaterColorHd[2], Minimap.WaterColorHd[3], 255))
				else
				dxDrawImageSection(Bigmap.PosX, Bigmap.PosY, Bigmap.Width, Bigmap.Height, mapX, mapY, mapWidth, mapHeight, Minimap.MapTexture, 0, 0, 0, tocolor(255, 255, 255, Minimap.Alpha))
				dxSetTextureEdge(Minimap.MapTexture, 'border', tocolor(Minimap.WaterColor[1], Minimap.WaterColor[2], Minimap.WaterColor[3], 255))
				end
				
			
				if gpsRouteImage then
					dxUpdateScreenSource(screenSource, true)
					dxDrawImage(Bigmap.CenterX + (remapTheFirstWay(playerX) - (gpsRouteImageData[1] + gpsRouteImageData[3] / 2)) / Bigmap.CurrentZoom - gpsRouteImageData[3] / Bigmap.CurrentZoom / 2, Bigmap.CenterY - (remapTheFirstWay(playerY) - (gpsRouteImageData[2] + gpsRouteImageData[4] / 2)) / Bigmap.CurrentZoom + gpsRouteImageData[4] / Bigmap.CurrentZoom / 2, gpsRouteImageData[3] / Bigmap.CurrentZoom, -(gpsRouteImageData[4] / Bigmap.CurrentZoom), gpsRouteImage, 180, 0, 0, tocolor(220, 163, 30))
					dxDrawImageSection(0, 0, Bigmap.PosX, Display.Height, 0, 0, Bigmap.PosX, Display.Height, screenSource)
					dxDrawImageSection(Display.Width - Bigmap.PosX, 0, Bigmap.PosX, Display.Height, Display.Width - Bigmap.PosX, 0, Bigmap.PosX, Display.Height, screenSource)
					dxDrawImageSection(Bigmap.PosX, 0, Display.Width - 2 * Bigmap.PosX, Bigmap.PosY, Bigmap.PosX, 0, Display.Width - 2 * Bigmap.PosX, Bigmap.PosY, screenSource)
					dxDrawImageSection(Bigmap.PosX, Display.Height - Bigmap.PosY, Display.Width - 2 * Bigmap.PosX, Bigmap.PosY, Bigmap.PosX, Display.Height - Bigmap.PosY, Display.Width - 2 * Bigmap.PosX, Bigmap.PosY, screenSource)
				end
			
				--> Radar area
				for _, area in ipairs(getElementsByType('radararea')) do
					local areaX, areaY = getElementPosition(area)
					local areaWidth, areaHeight = getRadarAreaSize(area)
					local areaR, areaG, areaB, areaA = getRadarAreaColor(area)
						
					if (isRadarAreaFlashing(area)) then
						areaA = areaA * math.abs(getTickCount() % 1000 - 500) / 500
					end
					
					local areaX, areaY = getMapFromWorldPosition(areaX, areaY + areaHeight)
					local areaWidth, areaHeight = areaWidth / Bigmap.CurrentZoom * Minimap.MapUnit, areaHeight / Bigmap.CurrentZoom * Minimap.MapUnit

					--** Width
					if (areaX < Bigmap.PosX) then
						areaWidth = areaWidth - math.abs((Bigmap.PosX) - (areaX))
						areaX = areaX + math.abs((Bigmap.PosX) - (areaX))
					end
					
					if (areaX + areaWidth > Bigmap.PosX + Bigmap.Width) then
						areaWidth = areaWidth - math.abs((Bigmap.PosX + Bigmap.Width) - (areaX + areaWidth))
					end
					
					if (areaX > Bigmap.PosX + Bigmap.Width) then
						areaWidth = areaWidth + math.abs((Bigmap.PosX + Bigmap.Width) - (areaX))
						areaX = areaX - math.abs((Bigmap.PosX + Bigmap.Width) - (areaX))
					end
					
					if (areaX + areaWidth < Bigmap.PosX) then
						areaWidth = areaWidth + math.abs((Bigmap.PosX) - (areaX + areaWidth))
						areaX = areaX - math.abs((Bigmap.PosX) - (areaX + areaWidth))
					end
					
					--** Height
					if (areaY < Bigmap.PosY) then
						areaHeight = areaHeight - math.abs((Bigmap.PosY) - (areaY))
						areaY = areaY + math.abs((Bigmap.PosY) - (areaY))
					end
					
					if (areaY + areaHeight > Bigmap.PosY + Bigmap.Height) then
						areaHeight = areaHeight - math.abs((Bigmap.PosY + Bigmap.Height) - (areaY + areaHeight))
					end
					
					if (areaY + areaHeight < Bigmap.PosY) then
						areaHeight = areaHeight + math.abs((Bigmap.PosY) - (areaY + areaHeight))
						areaY = areaY - math.abs((Bigmap.PosY) - (areaY + areaHeight))
					end
					
					if (areaY > Bigmap.PosY + Bigmap.Height) then
						areaHeight = areaHeight + math.abs((Bigmap.PosY + Bigmap.Height) - (areaY))
						areaY = areaY - math.abs((Bigmap.PosY + Bigmap.Height) - (areaY))
					end
					
					--** Draw
					dxDrawRectangle(areaX, areaY, areaWidth, areaHeight, tocolor(areaR, areaG, areaB, areaA), false)
				end
				
				--> Blips
				for _, blip in ipairs(getElementsByType('blip')) do
					local blipX, blipY, blipZ = getElementPosition(blip)

					if (localPlayer ~= getElementAttachedTo(blip)) then
						local blipSettings = {
							['color'] = {255, 255, 255, 255},
							['size'] = getElementData(blip, 'blipSize') or 20,
							['icon'] = getElementData(blip, 'blipIcon') or 'target',
							['exclusive'] = getElementData(blip, 'exclusiveBlip') or false
						}
						
						if (blipSettings['icon'] == 'target' or blipSettings['icon'] == 'waypoint') then
							blipSettings['color'] = {getBlipColor(blip)}
						end
						
						local centerX, centerY = (Bigmap.PosX + (Bigmap.Width / 2)), (Bigmap.PosY + (Bigmap.Height / 2))
						local leftFrame = (centerX - Bigmap.Width / 2) + (blipSettings['size'] / 2)
						local rightFrame = (centerX + Bigmap.Width / 2) - (blipSettings['size'] / 2)
						local topFrame = (centerY - Bigmap.Height / 2) + (blipSettings['size'] / 2)
						local bottomFrame = (centerY + Bigmap.Height / 2) - (blipSettings['size'] / 2)
						local blipX, blipY = getMapFromWorldPosition(blipX, blipY)
						
						centerX = math.max(leftFrame, math.min(rightFrame, blipX))
						centerY = math.max(topFrame, math.min(bottomFrame, blipY))
						local r,g,b = 255,255,255
						local __,__,__,alpha = getBlipColor(blip)
						if getBlipIcon (blip) == 0 then r,g,b,_ = getBlipColor ( blip ) end
						dxDrawImage(centerX - (blipSettings['size'] / 2), centerY - (blipSettings['size'] / 2), blipSettings['size'], blipSettings['size'], 'files/images/blips/' .. getBlipIcon (blip) .. '.png', 0, 0, 0, tocolor(r,g,b,alpha))
					end
				end
				
				--> Local player
				local localX, localY, localZ = getElementPosition(localPlayer)
				local blipX, blipY = getMapFromWorldPosition(localX, localY)
						
				if (blipX >= Bigmap.PosX and blipX <= Bigmap.PosX + Bigmap.Width) then
					if (blipY >= Bigmap.PosY and blipY <= Bigmap.PosY + Bigmap.Height) then
						dxDrawImage(blipX - 10, blipY - 10, 20, 20, 'files/images/arrow.png', 360 - playerRotation)
					end
				end
				
				--> GPS Location
				dxDrawRectangle(Bigmap.PosX, (Bigmap.PosY + Bigmap.Height) - 25, Bigmap.Width, 25, tocolor(0, 0, 0, 200))
				--dxDrawText(zoneName, Bigmap.PosX + 10, (Bigmap.PosY + Bigmap.Height) - 25, Bigmap.PosX + 10 + Bigmap.Width - 20, (Bigmap.PosY + Bigmap.Height), tocolor(255, 255, 255, 255), 0.50, Fonts.Loc, 'left', 'center')
			else
				dxDrawRectangle(Bigmap.PosX, Bigmap.PosY, Bigmap.Width, Bigmap.Height, tocolor(0, 0, 0, 150))
				dxDrawText('GPS lost connection...', Bigmap.PosX, Bigmap.PosY + 20, Bigmap.PosX + Bigmap.Width, Bigmap.PosY + 20 + Bigmap.Height, tocolor(255, 255, 255, 255 * math.abs(getTickCount() % 2000 - 1000) / 1000), 0.40, Fonts.Loc, 'center', 'center', false, false, false, true, true)
				dxDrawText('', Bigmap.PosX, Bigmap.PosY - 20, Bigmap.PosX + Bigmap.Width, Bigmap.PosY - 20 + Bigmap.Height, tocolor(255, 255, 255, 255 * math.abs(getTickCount() % 2000 - 1000) / 1000), 1.00, Fonts.Icons, 'center', 'center', false, false, false, true, true)
				
				if (Minimap.LostRotation > 360) then
					Minimap.LostRotation = 0
				end
				
				dxDrawText('', (Bigmap.PosX + Bigmap.Width - 25), Bigmap.PosY, (Bigmap.PosX + Bigmap.Width - 25) + 25, Bigmap.PosY + 25, tocolor(255, 255, 255, 100), 0.50, Fonts.Icons, 'center', 'center', false, false, false, true, true, Minimap.LostRotation)
				Minimap.LostRotation = Minimap.LostRotation + 1
			end
	
end

function renderMinimap()
	if Bigmap.IsVisible or not Minimap.IsVisible then
		return
	end
	if getElementData(getLocalPlayer(),"character:login") ==0 then return end
	dxDrawBorder(Minimap.PosX, Minimap.PosY, Minimap.Width, Minimap.Height, 2, tocolor(0, 0, 0, 200))
			
	if (getElementInterior(localPlayer) == 0 and getElementDimension(localPlayer) == 0) then
		Minimap.PlayerInVehicle = getPedOccupiedVehicle(localPlayer)
		playerX, playerY, playerZ = getElementPosition(localPlayer)
				
		--> Calculate positions
		local playerRotation = getPedRotation(localPlayer)
		local playerMapX, playerMapY = (3000 + playerX) / 6000 * Minimap.TextureSize, (3000 - playerY) / 6000 * Minimap.TextureSize
		local streamDistance, pRotation = getRadarRadius(), getRotation()
		local mapRadius = streamDistance / 6000 * Minimap.TextureSize * Minimap.CurrentZoom
		local mapX, mapY, mapWidth, mapHeight = playerMapX - mapRadius, playerMapY - mapRadius, mapRadius * 2, mapRadius * 2
				
		--> Set world
		dxSetRenderTarget(Minimap.MapTarget, true)
		if getElementData(localPlayer,"HDMAP") then
		dxDrawImageSection(0, 0, Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, mapX, mapY, mapWidth, mapHeight, Minimap.MapTextureHd, 0, 0, 0, tocolor(255, 255, 255, Minimap.Alpha), false) 
		dxSetTextureEdge(Minimap.MapTextureHd, "border", tocolor(Minimap.WaterColorHd[1], Minimap.WaterColorHd[2], Minimap.WaterColorHd[3], Minimap.Alpha)) else
		dxDrawImageSection(0, 0, Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, mapX, mapY, mapWidth, mapHeight, Minimap.MapTexture, 0, 0, 0, tocolor(255, 255, 255, Minimap.Alpha), false)
		dxSetTextureEdge(Minimap.MapTexture, "border", tocolor(Minimap.WaterColor[1], Minimap.WaterColor[2], Minimap.WaterColor[3], Minimap.Alpha)) end
				
		if gpsRouteImage then
			dxDrawImage(minimapRenderSize / 2 + (remapTheFirstWay(playerX) - (gpsRouteImageData[1] + gpsRouteImageData[3] / 2)) / (Minimap.CurrentZoom / 3) - gpsRouteImageData[3] / (Minimap.CurrentZoom / 3) / 2, minimapRenderSize / 2 - (remapTheFirstWay(playerY) - (gpsRouteImageData[2] + gpsRouteImageData[4] / 2)) / (Minimap.CurrentZoom / 3) + gpsRouteImageData[4] / (Minimap.CurrentZoom / 3) / 2, gpsRouteImageData[3] / (Minimap.CurrentZoom / 3), -(gpsRouteImageData[4] / (Minimap.CurrentZoom / 3)), gpsRouteImage, 180, 0, 0, tocolor(220, 163, 30))
		end
				
		--> Draw radar areas
		for _, area in ipairs(getElementsByType('radararea')) do
			local areaX, areaY = getElementPosition(area)
			local areaWidth, areaHeight = getRadarAreaSize(area)
			local areaMapX, areaMapY, areaMapWidth, areaMapHeight = (3000 + areaX) / 6000 * Minimap.TextureSize, (3000 - areaY) / 6000 * Minimap.TextureSize, areaWidth / 6000 * Minimap.TextureSize, -(areaHeight / 6000 * Minimap.TextureSize)
					
			if (doesCollide(playerMapX - mapRadius, playerMapY - mapRadius, mapRadius * 2, mapRadius * 2, areaMapX, areaMapY, areaMapWidth, areaMapHeight)) then
				local areaR, areaG, areaB, areaA = getRadarAreaColor(area)
						
				if (isRadarAreaFlashing(area)) then
					areaA = areaA * math.abs(getTickCount() % 1000 - 500) / 500
				end
						
				local mapRatio = Minimap.BiggerTargetSize / (mapRadius * 2)
				local areaMapX, areaMapY, areaMapWidth, areaMapHeight = (areaMapX - (playerMapX - mapRadius)) * mapRatio, (areaMapY - (playerMapY - mapRadius)) * mapRatio, areaMapWidth * mapRatio, areaMapHeight * mapRatio
						
				dxSetBlendMode('modulate_add')
				dxDrawRectangle(areaMapX, areaMapY, areaMapWidth, areaMapHeight, tocolor(areaR, areaG, areaB, areaA), false)
				dxSetBlendMode('blend')
			end
		end
				
		--> Draw blip
		dxSetRenderTarget(Minimap.RenderTarget, true)
		dxDrawImage(Minimap.NormalTargetSize / 2, Minimap.NormalTargetSize / 2, Minimap.BiggerTargetSize, Minimap.BiggerTargetSize, Minimap.MapTarget, math.deg(-pRotation), 0, 0, tocolor(255, 255, 255, 255), false)
				
		local serverBlips = getElementsByType('blip')
				
		for _, blip in ipairs(serverBlips) do
			local blipX, blipY, blipZ = getElementPosition(blip)
					
			if (localPlayer ~= getElementAttachedTo(blip) and getElementInterior(localPlayer) == getElementInterior(blip) and getElementDimension(localPlayer) == getElementDimension(blip)) then
				local blipDistance = getDistanceBetweenPoints2D(blipX, blipY, playerX, playerY)
				local blipRotation = math.deg(-getVectorRotation(playerX, playerY, blipX, blipY) - (-pRotation)) - 180
				local blipRadius = math.min((blipDistance / (streamDistance * Minimap.CurrentZoom)) * Minimap.NormalTargetSize, Minimap.NormalTargetSize)
				local distanceX, distanceY = getPointFromDistanceRotation(0, 0, blipRadius, blipRotation)
						
				local blipSettings = {
					['color'] = {255, 255, 255, 255},
					['size'] = getElementData(blip, 'blipSize') or 20,
					['exclusive'] = getElementData(blip, 'exclusiveBlip') or false,
					['icon'] = getElementData(blip, 'blipIcon') or 'target'
				}
						
				local blipX, blipY = Minimap.NormalTargetSize * 1.5 + (distanceX - (blipSettings['size'] / 2)), Minimap.NormalTargetSize * 1.5 + (distanceY - (blipSettings['size'] / 2))
				local calculatedX, calculatedY = ((Minimap.PosX + (Minimap.Width / 2)) - (blipSettings['size'] / 2)) + (blipX - (Minimap.NormalTargetSize * 1.5) + (blipSettings['size'] / 2)), (((Minimap.PosY + (Minimap.Height / 2)) - (blipSettings['size'] / 2)) + (blipY - (Minimap.NormalTargetSize * 1.5) + (blipSettings['size'] / 2)))
						
				if (blipSettings['icon'] == 'target' or blipSettings['icon'] == 'waypoint') then
					blipSettings['color'] = {getBlipColor(blip)}
				end
						
				if (blipSettings['exclusive'] == true) then
					blipX = math.max(blipX + (Minimap.PosX - calculatedX), math.min(blipX + (Minimap.PosX + Minimap.Width - blipSettings['size'] - calculatedX), blipX))
					blipY = math.max(blipY + (Minimap.PosY - calculatedY), math.min(blipY + (Minimap.PosY + Minimap.Height - blipSettings['size'] - 25 - calculatedY), blipY))
				end
						
				dxSetBlendMode('modulate_add')
				local r,g,b = 255,255,255
				local __,__,__,alpha = getBlipColor(blip)
				if getBlipIcon (blip) == 0 then r,g,b,_ = getBlipColor ( blip ) end
				dxDrawImage(blipX, blipY, blipSettings['size'], blipSettings['size'], 'files/images/blips/' .. getBlipIcon (blip) .. '.png', 0, 0, 0, tocolor(r,g,b,alpha), false)
				dxSetBlendMode('blend')
			end
		end
				
		--> Draw fully minimap
		dxSetRenderTarget()
		dxDrawImageSection(Minimap.PosX, Minimap.PosY, Minimap.Width, Minimap.Height, Minimap.NormalTargetSize / 2 + (Minimap.BiggerTargetSize / 2) - (Minimap.Width / 2), Minimap.NormalTargetSize / 2 + (Minimap.BiggerTargetSize / 2) - (Minimap.Height / 2), Minimap.Width, Minimap.Height, Minimap.RenderTarget, 0, -90, 0, tocolor(255, 255, 255, 255))
				
		--> Local player
		dxDrawImage((Minimap.PosX + (Minimap.Width / 2)) - 10, (Minimap.PosY + (Minimap.Height / 2)) - 10, 20, 20, 'files/images/arrow.png', math.deg(-pRotation) - playerRotation)
			
		--> GPS IRC
		if gpsRoute or (not gpsRoute and waypointEndInterpolation) then
			local naviX = Minimap.PosX + Minimap.Width - gpsLineWidth
			local naviCenterY = Minimap.PosY + (Minimap.Height - zoneLineHeight) / 2
			if waypointEndInterpolation then
				local interpolationProgress = (getTickCount() - waypointEndInterpolation) / 500
				local interpolateAlpha = interpolateBetween(1, 0, 0, 0, 0, 0, interpolationProgress, "Linear")
				dxDrawRectangle(Minimap.PosX + Minimap.Width - 50, Minimap.PosY, 50, Minimap.Height - 20, tocolor(0, 0, 0, 150 * interpolateAlpha))
				dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), naviCenterY - gpsLineIconHalfSize, gpsLineIconSize, gpsLineIconSize, "gps/images/end.png", 0, 0, 0, tocolor(0, 255, 255, 255 * interpolateAlpha))
				dxDrawText("0 m", naviX, naviCenterY + gpsLineIconHalfSize, Minimap.PosX + Minimap.Width, naviCenterY + gpsLineIconHalfSize + respc(16), tocolor(0, 255, 255, 255 * interpolateAlpha), 0.9, Fonts.Roboto, "center", "center")
				if interpolationProgress > 1 then
					waypointEndInterpolation = false
				end
			end

			if nextWp then
				dxDrawRectangle(Minimap.PosX + Minimap.Width - 50, Minimap.PosY, 50, Minimap.Height - 20, tocolor(0, 0, 0, 150))
				if currentWaypoint ~= nextWp and not tonumber(reRouting) then
					if nextWp > 1 then
						waypointInterpolation = {getTickCount(), currentWaypoint}
					end
					currentWaypoint = nextWp
				end

				if tonumber(reRouting) then
					currentWaypoint = nextWp
					local reRouteProgress = (getTickCount() - reRouting) / 1250
					local refreshAngle, refreshDots = interpolateBetween(360, 0, 0, 0, 3, 0, reRouteProgress, "Linear")
					dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), naviCenterY - gpsLineIconHalfSize, gpsLineIconSize, gpsLineIconSize, "gps/images/refresh.png", refreshAngle, 0, 0, tocolor(0, 255, 255))
					if refreshDots > 2 then
						dxDrawText("•••", naviX, naviCenterY + gpsLineIconHalfSize, Minimap.PosX + Minimap.Width, naviCenterY + gpsLineIconHalfSize + respc(16), tocolor(0, 255, 255), 0.9, Fonts.Roboto, "center", "center")
					elseif refreshDots > 1 then
						dxDrawText("••", naviX, naviCenterY + gpsLineIconHalfSize, Minimap.PosX + Minimap.Width, naviCenterY + gpsLineIconHalfSize + respc(16), tocolor(0, 255, 255), 0.9, Fonts.Roboto, "center", "center")
					elseif refreshDots > 0 then
						dxDrawText("•", naviX, naviCenterY + gpsLineIconHalfSize, Minimap.PosX + Minimap.Width, naviCenterY + gpsLineIconHalfSize + respc(16), tocolor(0, 255, 255), 0.9, Fonts.Roboto, "center", "center")
					end
					if reRouteProgress > 1 then
						reRouting = getTickCount()
					end
				elseif turnAround then
					currentWaypoint = nextWp
					dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), naviCenterY - gpsLineIconHalfSize, gpsLineIconSize, gpsLineIconSize, "gps/images/around.png", 0, 0, 0, tocolor(0, 255, 255))
					dxDrawText("Dor\nBezanid", naviX, naviCenterY + gpsLineIconHalfSize + respc(8), Minimap.PosX + Minimap.Width, naviCenterY + gpsLineIconHalfSize + respc(8) + respc(16), tocolor(0, 255, 255), 0.9, Fonts.Roboto, "center", "center")
				elseif not waypointInterpolation then
					dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), naviCenterY - gpsLineIconHalfSize, gpsLineIconSize, gpsLineIconSize, "gps/images/" .. gpsWaypoints[nextWp][2] .. ".png", 0, 0, 0, tocolor(0, 255, 255))
					dxDrawText(floor((gpsWaypoints[nextWp][3] or 0) / 10) * 10 .. " m", naviX, naviCenterY + gpsLineIconHalfSize, Minimap.PosX + Minimap.Width, naviCenterY + gpsLineIconHalfSize + respc(16), tocolor(0, 255, 255, 255), 0.9, Fonts.Roboto, "center", "center")
					if gpsWaypoints[nextWp + 1] then
						dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), Minimap.PosY + Minimap.Height - zoneLineHeight - gpsLineIconSize - respc(8), gpsLineIconSize, gpsLineIconSize, "gps/images/" .. gpsWaypoints[nextWp + 1][2] .. ".png", 0, 0, 0, tocolor(220, 163, 30))
					end
				else
					local startPolation, endPolation = (getTickCount() - waypointInterpolation[1]) / 750, 0
					local firstAlpha, firstOffset, secondOffset = interpolateBetween(255, (Minimap.Height - zoneLineHeight) / 2 - gpsLineIconHalfSize, Minimap.Height - zoneLineHeight - gpsLineIconSize - respc(8), 0, 0, (Minimap.Height - zoneLineHeight) / 2 - gpsLineIconHalfSize, startPolation, "Linear")
					dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), Minimap.PosY + firstOffset, gpsLineIconSize, gpsLineIconSize, "gps/images/" .. gpsWaypoints[waypointInterpolation[2]][2] .. ".png", 0, 0, 0, tocolor(0, 255, 255, firstAlpha))
					dxDrawText(floor((gpsWaypoints[waypointInterpolation[2]][3] or 0) / 10) * 10 .. " m", naviX, Minimap.PosY + firstOffset + gpsLineIconSize, Minimap.PosX + Minimap.Width, Minimap.PosY + firstOffset + gpsLineIconSize + respc(16), tocolor(0, 255, 255, firstAlpha), 0.9, Fonts.Roboto, "center", "center")
					if gpsWaypoints[waypointInterpolation[2] + 1] then
						local r, g, b = interpolateBetween(220, 163, 30, 0, 255, 255, startPolation, "Linear")
						local alpha = interpolateBetween(0, 0,0, 255, 0, 0, startPolation, "Linear")
						dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), Minimap.PosY + secondOffset, gpsLineIconSize, gpsLineIconSize, "gps/images/" .. gpsWaypoints[waypointInterpolation[2] + 1][2] .. ".png", 0, 0, 0, tocolor(r, g, b))
						dxDrawText(floor((gpsWaypoints[waypointInterpolation[2] + 1][3] or 0) / 10) * 10 .. " m", naviX, Minimap.PosY + secondOffset + gpsLineIconSize, Minimap.PosX + Minimap.Width, Minimap.PosY + secondOffset + gpsLineIconSize + respc(16), tocolor(r, g, b, alpha), 0.9, Fonts.Roboto, "center", "center")
					end
					if startPolation > 1 then
						endPolation = (getTickCount() - waypointInterpolation[1] - 750) / 500
					end
					if gpsWaypoints[waypointInterpolation[2] + 2] then
						local thirdAlpha = interpolateBetween(0, 0, 0, 255, 0, 0, endPolation, "Linear")
						dxDrawImage(naviX + ((gpsLineWidth - gpsLineIconSize) / 2), Minimap.PosY + Minimap.Height - zoneLineHeight - gpsLineIconSize - respc(8), gpsLineIconSize, gpsLineIconSize, "gps/images/" .. gpsWaypoints[waypointInterpolation[2] + 2][2] .. ".png", 0, 0, 0, tocolor(220, 163, 30, thirdAlpha))
					end
					if endPolation > 1 then
						waypointInterpolation = false
					end
				end
			end
		end
				
	--> GPS
	--dxDrawRectangle(Minimap.PosX, Minimap.PosY + Minimap.Height - 20, Minimap.Width, 20, tocolor(0, 0, 0, 200))
	--dxDrawText("PING: 1 FPS: 60", Minimap.PosX + 35, (Minimap.PosY + Minimap.Height - 20), Minimap.PosX + 5 + Minimap.Width - 10, Minimap.PosY + Minimap.Height, tocolor(255, 255, 255, 255), 0.40, Fonts.Loc, 'right', 'center', true, false, false, true, true)
			
	--> Zoom
	if (getKeyState('num_add') or getKeyState('num_sub')) then
		Minimap.CurrentZoom = math.max(Minimap.MinimumZoom, math.min(Minimap.MaximumZoom, Minimap.CurrentZoom + ((getKeyState('num_sub') and -1 or 1) * (getTickCount() - (getTickCount() + 50)) / 100)))
	end
	
	else
		dxDrawRectangle(Minimap.PosX, Minimap.PosY, Minimap.Width, Minimap.Height, tocolor(0, 0, 0, 200))
		dxDrawText('GPS lost connection...', Minimap.PosX, Minimap.PosY + 20, Minimap.PosX + Minimap.Width, Minimap.PosY + 20 + Minimap.Height, tocolor(255, 255, 255, 255 * math.abs(getTickCount() % 2000 - 1000) / 1000), 0.40, Fonts.Loc, 'center', 'center', false, false, false, true, true)
		dxDrawText('☹', Minimap.PosX, Minimap.PosY - 20, Minimap.PosX + Minimap.Width, Minimap.PosY - 20 + Minimap.Height, tocolor(255, 255, 255, 255 * math.abs(getTickCount() % 2000 - 1000) / 1000), 1.00, Fonts.Icons, 'center', 'center', false, false, false, true, true)
				
		if (Minimap.LostRotation > 360) then
			Minimap.LostRotation = 0
		end
				
		dxDrawText('', (Minimap.PosX + Minimap.Width - 25), Minimap.PosY, (Minimap.PosX + Minimap.Width - 25) + 25, Minimap.PosY + 25, tocolor(255, 255, 255, 100), 0.50, Fonts.Icons, 'center', 'center', false, false, false, true, true, Minimap.LostRotation)
		Minimap.LostRotation = Minimap.LostRotation + 1
	end
end

function remapTheFirstWay(coord)
	return (-coord + 3000) / (6000 / Minimap.TextureSize)
end

function remapTheSecondWay(coord)
	return (coord + 3000) / (6000 / Minimap.TextureSize)
end

function addGPSLine(x, y)
	table.insert(gpsLines, {remapTheFirstWay(x), remapTheFirstWay(y)})
end

function processGPSLines()
	local routeStartPosX, routeStartPosY = 99999, 99999
	local routeEndPosX, routeEndPosY = -99999, -99999

	for i = 1, #gpsLines do
		if gpsLines[i][1] < routeStartPosX then
			routeStartPosX = gpsLines[i][1]
		end

		if gpsLines[i][2] < routeStartPosY then
			routeStartPosY = gpsLines[i][2]
		end

		if gpsLines[i][1] > routeEndPosX then
			routeEndPosX = gpsLines[i][1]
		end

		if gpsLines[i][2] > routeEndPosY then
			routeEndPosY = gpsLines[i][2]
		end
	end

	local routeWidth = (routeEndPosX - routeStartPosX) + 16
	local routeHeight = (routeEndPosY - routeStartPosY) + 16

	if isElement(gpsRouteImage) then
		destroyElement(gpsRouteImage)
	end

	gpsRouteImage = dxCreateRenderTarget(routeWidth, routeHeight, true)
	gpsRouteImageData = {routeStartPosX - 8, routeStartPosY - 8, routeWidth, routeHeight}

	dxSetRenderTarget(gpsRouteImage)
	dxSetBlendMode("modulate_add")

	dxDrawImage(gpsLines[1][1] - routeStartPosX + 8 - 4, gpsLines[1][2] - routeStartPosY + 8 - 4, 8, 8, "gps/images/dot.png")

	for i = 2, #gpsLines do
		if gpsLines[i - 1] then
			local startX = gpsLines[i][1] - routeStartPosX + 8
			local startY = gpsLines[i][2] - routeStartPosY + 8
			local endX = gpsLines[i - 1][1] - routeStartPosX + 8
			local endY = gpsLines[i - 1][2] - routeStartPosY + 8

			dxDrawImage(startX - 4, startY - 4, 8, 8, "gps/images/dot.png")
			dxDrawLine(startX, startY, endX, endY, tocolor(255, 255, 255), 9)
		end
	end

	dxSetBlendMode("blend")
	dxSetRenderTarget()
end

function clearGPSRoute()
	gpsLines = {}

	if isElement(gpsRouteImage) then
		destroyElement(gpsRouteImage)
	end
	gpsRouteImage = false
end

function doesCollide(x1, y1, w1, h1, x2, y2, w2, h2)
	local horizontal = (x1 < x2) ~= (x1 + w1 < x2) or (x1 > x2) ~= (x1 > x2 + w2)
	local vertical = (y1 < y2) ~= (y1 + h1 < y2) or (y1 > y2) ~= (y1 > y2 + h2)
	
	return (horizontal and vertical)
end

function getRadarRadius()
	--if (not Minimap.PlayerInVehicle) then
		return 180
	-- else
		-- local vehicleX, vehicleY, vehicleZ = getElementVelocity(Minimap.PlayerInVehicle)
		-- local currentSpeed = (1 + (vehicleX ^ 2 + vehicleY ^ 2 + vehicleZ ^ 2) ^ (0.5)) / 2
	
		-- if (currentSpeed <= 0.5) then
			-- return 180
		-- elseif (currentSpeed >= 1) then
			-- return 360
		-- end
		
		-- local distance = currentSpeed - 0.5
		-- local ratio = 180 / 0.5
		
		-- return math.ceil((distance * ratio) + 180)
	-- end
end

function getPointFromDistanceRotation(x, y, dist, angle)
	local a = math.rad(90 - angle)
	local dx = math.cos(a) * dist
	local dy = math.sin(a) * dist
	
	return x + dx, y + dy
end

function getRotation()
	local cameraX, cameraY, _, rotateX, rotateY = getCameraMatrix()
	local camRotation = getVectorRotation(cameraX, cameraY, rotateX, rotateY)
	
	return camRotation
end

function getVectorRotation(X, Y, X2, Y2)
	local rotation = 6.2831853071796 - math.atan2(X2 - X, Y2 - Y) % 6.2831853071796
	
	return -rotation
end

function dxDrawBorder(x, y, w, h, size, color, postGUI)
	size = size or 2
	
	dxDrawRectangle(x - size, y, size, h, color or tocolor(0, 0, 0, 180), postGUI)
	dxDrawRectangle(x + w, y, size, h, color or tocolor(0, 0, 0, 180), postGUI)
	dxDrawRectangle(x - size, y - size, w + (size * 2), size, color or tocolor(0, 0, 0, 180), postGUI)
	dxDrawRectangle(x - size, y + h, w + (size * 2), size, color or tocolor(0, 0, 0, 180), postGUI)
end

function getMapFromWorldPosition(worldX, worldY)
	local centerX, centerY = (Bigmap.PosX + (Bigmap.Width / 2)), (Bigmap.PosY + (Bigmap.Height / 2))
	local mapLeftFrame = centerX - ((playerX - worldX) / Bigmap.CurrentZoom * Minimap.MapUnit)
	local mapRightFrame = centerX + ((worldX - playerX) / Bigmap.CurrentZoom * Minimap.MapUnit)
	local mapTopFrame = centerY - ((worldY - playerY) / Bigmap.CurrentZoom * Minimap.MapUnit)
	local mapBottomFrame = centerY + ((playerY - worldY) / Bigmap.CurrentZoom * Minimap.MapUnit)
	
	centerX = math.max(mapLeftFrame, math.min(mapRightFrame, centerX))
	centerY = math.max(mapTopFrame, math.min(mapBottomFrame, centerY))
	
	return centerX, centerY
end

function getWorldFromMapPosition(mapX, mapY)
	local worldX = playerX + ((mapX * ((Bigmap.Width * Bigmap.CurrentZoom) * 2)) - (Bigmap.Width * Bigmap.CurrentZoom))
	local worldY = playerY + ((mapY * ((Bigmap.Height * Bigmap.CurrentZoom) * 2)) - (Bigmap.Height * Bigmap.CurrentZoom)) * -1
	
	return worldX, worldY
end

function isVehicleEmpty( vehicle )
	if not isElement( vehicle ) or getElementType( vehicle ) ~= "vehicle" then
		return true
	end

	local passengers = getVehicleMaxPassengers( vehicle )
	if type( passengers ) == 'number' then
		for seat = 0, passengers do
			if getVehicleOccupant( vehicle, seat ) then
				return false
			end
		end
	end
	return true
end

local markedPlace = nil
addEventHandler("onClientDoubleClick", root, function()
	if (not Minimap.IsVisible and Bigmap.IsVisible) then
		if isPedInVehicle(localPlayer) then
			local gpsRouteProcess = false
			if occupiedVehicle and getElementInterior(localPlayer) == 0 and getElementDimension(localPlayer) == 0 then
				if getElementData(occupiedVehicle, "gpsDestination") then
					setElementData(occupiedVehicle, "gpsDestination", false)
				else
					local cursorX, cursorY = getCursorPosition()
					local mapX, mapY = getWorldFromMapPosition(cursorX, cursorY)
					setElementData(occupiedVehicle, "gpsDestination", {
					mapX,
					mapY
					})
				end
				gpsRouteProcess = true
			end
		else
			local cursorX, cursorY = getCursorPosition()
			local mapX, mapY = getWorldFromMapPosition(cursorX, cursorY)
			zoneName = getZoneName(mapX, mapY, 0)
			if markedPlace then destroyElement(markedPlace) 
			markedPlace = nil setElementData(getLocalPlayer(), "marktelposx", nil) 
			setElementData(getLocalPlayer(), "marktelposy", nil) return end
			markedPlace = createBlip(mapX, mapY, 0, 10)
			setElementData(markedPlace, "exclusiveBlip", true)
			setElementData(getLocalPlayer(), "marktelposx", mapX)
			setElementData(getLocalPlayer(), "marktelposy", mapY)
		end
	end
end )

addEventHandler("onClientVehicleEnter", getRootElement(),
	function (player)
		if player == localPlayer then
			if occupiedVehicle ~= source then
				occupiedVehicle = source
			end
		end
	end
)

addEventHandler("onClientVehicleExit", getRootElement(),
	function (player)
		if player == localPlayer then
			if occupiedVehicle == source then
				occupiedVehicle = false
			end
		end
	end
)

addEventHandler("onClientElementDestroy", getRootElement(),
	function ()
		if occupiedVehicle == source then
			occupiedVehicle = false
		end
	end
)

addEventHandler("onClientVehicleExplode", getRootElement(),
	function ()
		if occupiedVehicle == source then
			occupiedVehicle = false
		end
	end
)

addEventHandler("onClientRestore", getRootElement(),
	function ()
		if gpsRoute then
			processGPSLines()
		end
	end
)