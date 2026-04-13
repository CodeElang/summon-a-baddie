local FormatNumber = {}


local Suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}


function FormatNumber.Format(value)
	local number = tonumber(value)


	if not number then return "0" end


	if number < 1000 then
		return tostring(math.floor(number))
	end


	local suffixIndex = math.floor(math.log10(number) / 3)


	if suffixIndex > #Suffixes - 1 then
		suffixIndex = #Suffixes - 1 
	end

	
	local divisor = 10 ^ (suffixIndex * 3)
	local formattedNumber = number / divisor

	
	local result = string.format("%.2f", formattedNumber)

	
	result = result:gsub("%.?0+$", "")


	return result .. Suffixes[suffixIndex + 1]
end

function FormatNumber.AddCommas(value)
	local formatted = tostring(math.floor(tonumber(value) or 0))
	while true do  
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

return FormatNumber