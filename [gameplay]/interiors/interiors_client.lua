local interiorAnims = {}
local setInteriorMarkerZ = {
	interiorEntry = function(marker,z)
		local interiorElement = getElementParent(marker)
		local vx = getElementData ( interiorElement,"posX" )
		local vy = getElementData ( interiorElement,"posY" )
		local vz = getElementData ( interiorElement,"posZ" )
		--
		setElementPosition(marker, vx, vy, vz + z/2 + 2.4)
	end,
	interiorReturn = function(marker,z)
		local interiorElement = getElementParent(marker)
		local vx = getElementData ( interiorElement,"posX" )
		local vy = getElementData ( interiorElement,"posY" )
		local vz = getElementData ( interiorElement,"posZ" )
		--
		setElementPosition(marker, vx, vy, vz + z/2 + 2.4)
	end
}

----Main
local interiors = {}
local interiorCols = {}
local interiorFromCol = {}
local resourceFromInterior = {}
local blockPlayer

-- Forward declarations
local colshapeHit
local setPlayerInsideInterior

addEvent ( "doWarpPlayerToInterior", true )
addEvent ( "onClientInteriorHit" )
addEvent ( "onClientInteriorWarped" )

addEventHandler ( "onClientResourceStart", root,
function ( resource )
	interiorLoadElements ( getResourceRootElement(resource), resource )
	interiorCreateMarkers ( resource )
end )

addEventHandler ( "onClientResourceStop", root,
function ( resource )
	if not interiors[resource] then return end
	for _, interiorTable in pairs(interiors[resource]) do
		local interior1 = interiorTable["entry"]
		local interior2 = interiorTable["return"]
		if interiorCols[interior1] and isElement(interiorCols[interior1]) then
			destroyElement ( interiorCols[interior1] )
		end
		if interiorCols[interior2] and isElement(interiorCols[interior2]) then
			destroyElement ( interiorCols[interior2] )
		end
	end
	interiors[resource] = nil
end )

local function interiorLoadElements ( rootElement, resource )
	---Load the exterior markers
	local entryInteriors = getElementsByType ( "interiorEntry", rootElement )
	for _, interior in pairs (entryInteriors) do
		local id = getElementData ( interior, "id" )
		if not interiors[resource] then interiors[resource] = {} end
		if not id then outputDebugString ( "Interiors: Error, no ID specified on entryInterior. Trying to load anyway.", 2 )
		end
		interiors[resource][id] = {}
		interiors[resource][id]["entry"] = interior
		resourceFromInterior[interior] = resource
	end
	--Load the interior markers
	local returnInteriors = getElementsByType ( "interiorReturn", rootElement )
	for _, interior in pairs (returnInteriors) do
		local id = getElementData ( interior, "refid" )
		if not interiors[resource] or not interiors[resource][id] then 
			outputDebugString ( "Interiors: Error, no refid specified to returnInterior.", 1 )
		else
			interiors[resource][id]["return"] = interior
			resourceFromInterior[interior] = resource
		end
	end
end

local function interiorCreateMarkers ( resource )
	if not interiors[resource] then return end
	for _, interiorTypeTable in pairs(interiors[resource]) do
		local entryInterior = interiorTypeTable["entry"]
		if entryInterior then
			local entX,entY,entZ = getElementData ( entryInterior, "posX" ),getElementData ( entryInterior, "posY" ),getElementData ( entryInterior, "posZ" )
			entX,entY,entZ = tonumber(entX),tonumber(entY),tonumber(entZ)
			
			if entX and entY and entZ then
				local col = createColSphere ( entX, entY, entZ, 1.5 )
				setElementParent ( col, entryInterior )
				interiorCols[entryInterior] = col
				interiorFromCol[col] = entryInterior
				addEventHandler ( "onClientColShapeHit", col, colshapeHit )
				--
				local dimension = tonumber(getElementData ( entryInterior, "dimension" )) or 0
				local interior = tonumber(getElementData ( entryInterior, "interior" )) or 0
				--
				setElementInterior ( col, interior )
				setElementDimension ( col, dimension )
			end
		end

		---create return markers
		local returnInterior = interiorTypeTable["return"]
		if returnInterior then
			local oneway = getElementData ( entryInterior, "oneway" )
			if oneway ~= "true" then
				local retX,retY,retZ = getElementData ( returnInterior, "posX" ),getElementData ( returnInterior, "posY" ),getElementData ( returnInterior, "posZ" )
				retX,retY,retZ = tonumber(retX),tonumber(retY),tonumber(retZ)
				
				if retX and retY and retZ then
					local col1 = createColSphere ( retX, retY, retZ, 1.5 )
					interiorFromCol[col1] = returnInterior
					interiorCols[returnInterior] = col1
					setElementParent ( col1, returnInterior )
					addEventHandler ( "onClientColShapeHit", col1, colshapeHit )
					--
					local dimension1 = tonumber(getElementData ( returnInterior, "dimension" )) or 0
					local interior1 = tonumber(getElementData ( returnInterior, "interior" )) or 0
					--
					setElementInterior ( col1, interior1 )
					setElementDimension ( col1, dimension1 )
				end
			end
		end
	end
end

function getInteriorMarker ( elementInterior )
	if not isElement ( elementInterior ) then outputDebugString("getInteriorName: Invalid variable specified as interior. Element expected, got "..type(elementInterior)..".",0,255,128,0) return false end
	local elemType = getElementType ( elementInterior )
	if elemType == "interiorEntry" or elemType == "interiorReturn" then
		return interiorCols[elementInterior] or false
	end
	outputDebugString("getInteriorName: Bad element specified. Interior expected, got "..elemType..".",0,255,128,0)
	return false
end

local opposite = { ["interiorReturn"] = "entry",["interiorEntry"] = "return" }
local idLoc = { ["interiorReturn"] = "refid",["interiorEntry"] = "id" }
colshapeHit = function( player, matchingDimension )
	if not isElement ( player ) or getElementType ( player ) ~= "player" then return end
	if player ~= localPlayer then return end
	if ( not matchingDimension ) or ( getPedOccupiedVehicle ( player ) ) or
	( isPedWearingJetpack ( player ) ) or ( not isPedOnGround ( player ) ) or
	( getPedControlState ( player, "aim_weapon" ) ) or ( blockPlayer ) or
	( isPedDoingTask ( player, "TASK_COMPLEX_ENTER_CAR_AS_DRIVER") ) or
	( isPedDoingTask ( player, "TASK_COMPLEX_ENTER_CAR_AS_PASSENGER") )
	then return end
	local interior = interiorFromCol[source]
	if not interior then return end
	local id = getElementData ( interior, idLoc[getElementType(interior)] )
	local resource = resourceFromInterior[interior]
	local eventCanceled = triggerEvent ( "onClientInteriorHit", interior )
	if ( eventCanceled ) then
		triggerServerEvent ( "doTriggerServerEvents", localPlayer, interior, getResourceName(resource), id )
	end
end

addEventHandler ( "doWarpPlayerToInterior", root,
	function ( interior, resourceName, id )
		local res = getResourceFromName(resourceName)
		if not res or not interiors[res] or not interiors[res][id] then return end
		local oppositeType = opposite[getElementType(interior)]
		local targetInterior = interiors[res][id][oppositeType]
		if not targetInterior then return end

		local x = tonumber(getElementData ( targetInterior, "posX" )) or 0
		local y = tonumber(getElementData ( targetInterior, "posY" )) or 0
		local z = (tonumber(getElementData ( targetInterior, "posZ" )) or 0) + 1
		local dim = tonumber(getElementData ( targetInterior, "dimension" )) or 0
		local int = tonumber(getElementData ( targetInterior, "interior" )) or 0
		local rot = tonumber(getElementData ( targetInterior, "rotation" )) or 0
		toggleAllControls ( false, true, false )
		fadeCamera ( false, 1.0 )
		setTimer ( setPlayerInsideInterior, 1000, 1, localPlayer, int, dim, rot, x, y, z, interior )
		blockPlayer = true
		setTimer ( function() blockPlayer = nil end, 3500, 1 )
	end
)

setPlayerInsideInterior = function ( player, int, dim, rot, x, y, z, interior )
	if not isElement(player) then return end
	setElementInterior ( player, int )
	setCameraInterior ( int )
	setElementDimension ( player, dim )
	setPedRotation ( player, rot % 360 )
	setTimer ( function(p) if isElement(p) then setCameraTarget(p) end end, 200, 1, player )
	setElementPosition ( player, x, y, z )
	toggleAllControls ( true, true, false )
	setTimer ( fadeCamera, 500, 1, true, 1.0 )
	triggerEvent ( "onClientInteriorWarped", interior )
	triggerServerEvent ( "onInteriorWarped", interior, player )
	triggerServerEvent ( "onPlayerInteriorWarped", player, interior )
end

function getInteriorName ( interior )
	if not isElement ( interior ) then outputDebugString("getInteriorName: Invalid variable specified as interior. Element expected, got "..type(interior)..".",0,255,128,0) return false end
	local elemType = getElementType ( interior )
	if elemType == "interiorEntry" then
		return getElementData ( interior, "id" )
	elseif elemType == "interiorReturn" then
		return getElementData ( interior, "refid" )
	else
		outputDebugString("getInteriorName: Bad element specified. Interior expected, got "..elemType..".",0,255,128,0)
		return false
	end
end
