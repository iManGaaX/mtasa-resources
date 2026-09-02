local interiors = {}
local interiorMarkers = {}
--format interior = { [resource] = { [id] = { return= { [element],[element] }, entry=[element] } }

addEvent ( "doTriggerServerEvents", true )
addEvent ( "onPlayerInteriorHit" )
addEvent ( "onPlayerInteriorWarped", true )
addEvent ( "onInteriorHit" )
addEvent ( "onInteriorWarped", true )

addEventHandler ( "onResourceStart", root,
function ( resource )
	interiorLoadElements ( getResourceRootElement(resource), resource )
	interiorCreateMarkers ( resource )
end )

addEventHandler ( "onResourceStop", root,
function ( resource )
	if not interiors[resource] then return end
	for id,interiorTable in pairs(interiors[resource]) do
		local interior1 = interiorTable["entry"]
		local interior2 = interiorTable["return"]
		if interiorMarkers[interior1] and isElement(interiorMarkers[interior1]) then
			destroyElement ( interiorMarkers[interior1] )
		end
		if interiorMarkers[interior2] and isElement(interiorMarkers[interior2]) then
			destroyElement ( interiorMarkers[interior2] )
		end
	end
	interiors[resource] = nil
end )

function interiorLoadElements ( rootElement, resource )
	---Load the exterior markers
	local entryInteriors = getElementsByType ( "interiorEntry", rootElement )
	for key, interior in pairs (entryInteriors) do
		local id = getElementData ( interior, "id" )
		if not interiors[resource] then interiors[resource] = {} end
		if not id then outputDebugString ( "Interiors: Error, no ID specified on entryInterior. Trying to load anyway.", 2 )
		end
		interiors[resource][id] = {}
		interiors[resource][id]["entry"] = interior
	end
	--Load the interior markers
	local returnInteriors = getElementsByType ( "interiorReturn", rootElement )
	for key, interior in pairs (returnInteriors) do
		local id = getElementData ( interior, "refid" )
		if not interiors[resource] or not interiors[resource][id] then 
			outputDebugString ( "Interiors: Error, no refid specified to returnInterior.", 1 )
		else
			interiors[resource][id]["return"] = interior
		end
	end
end

function interiorCreateMarkers ( resource )
	if not interiors[resource] then return end
	for interiorID, interiorTypeTable in pairs(interiors[resource]) do
		local entryInterior = interiorTypeTable["entry"]
		if entryInterior then
			local entX,entY,entZ = getElementData ( entryInterior, "posX" ),getElementData ( entryInterior, "posY" ),getElementData ( entryInterior, "posZ" )
			entX,entY,entZ = tonumber(entX),tonumber(entY),tonumber(entZ)
			
			if entX and entY and entZ then
				local marker = createMarker ( entX, entY, entZ + 2.2, "arrow", 2, 255, 255, 0, 200 )
				setElementParent ( marker, entryInterior )
				interiorMarkers[entryInterior] = marker
				--
				local dimension = tonumber(getElementData ( entryInterior, "dimension" )) or 0
				local interior = tonumber(getElementData ( entryInterior, "interior" )) or 0
				--
				setElementInterior ( marker, interior )
				setElementDimension ( marker, dimension )
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
					local marker1 = createMarker ( retX, retY, retZ + 2.2, "arrow", 2, 255, 255, 0, 200 )
					interiorMarkers[returnInterior] = marker1
					setElementParent ( marker1, returnInterior )
					--
					local dimension1 = tonumber(getElementData ( returnInterior, "dimension" )) or 0
					local interior1 = tonumber(getElementData ( returnInterior, "interior" )) or 0
					--
					setElementInterior ( marker1, interior1 )
					setElementDimension ( marker1, dimension1 )
				end
			end
		end
	end
end

function getInteriorMarker ( elementInterior )
	if not isElement ( elementInterior ) then outputDebugString("getInteriorName: Invalid variable specified as interior. Element expected, got "..type(elementInterior)..".",0,255,128,0) return false end
	local elemType = getElementType ( elementInterior )
	if elemType == "interiorEntry" or elemType == "interiorReturn" then
		return interiorMarkers[elementInterior] or false
	end
	outputDebugString("getInteriorName: Bad element specified. Interior expected, got "..elemType..".",0,255,128,0)
	return false
end

local idLoc = { ["interiorReturn"] = "refid",["interiorEntry"] = "id" }
addEventHandler ( "doTriggerServerEvents", root,
	function( interior, resourceName, id )
		if not isElement(client) then return end
		local eventCanceled1 = triggerEvent ( "onPlayerInteriorHit", client, interior, resourceName, id )
		local eventCanceled2 = triggerEvent ( "onInteriorHit", interior, client )
		if ( eventCanceled2 ) and ( eventCanceled1 ) then
			triggerClientEvent ( client, "doWarpPlayerToInterior", client, interior, resourceName, id )
			setTimer ( setPlayerInsideInterior, 1000, 1, client, interior, resourceName, id )
		end
	end
)

local opposite = { ["interiorReturn"] = "entry",["interiorEntry"] = "return" }
function setPlayerInsideInterior ( player, interior, resourceName, id )
	if not isElement(player) then return end
	local res = getResourceFromName(resourceName) or getThisResource()
	if not interiors[res] or not interiors[res][id] then return end
	local oppositeType = opposite[getElementType(interior)]
	local targetInterior = interiors[res][id][oppositeType]
	if not targetInterior then return end

	local dim = tonumber(getElementData ( targetInterior, "dimension" )) or 0
	local int = tonumber(getElementData ( targetInterior, "interior" )) or 0
	setElementInterior ( player, int )
	setElementDimension ( player, dim )
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


