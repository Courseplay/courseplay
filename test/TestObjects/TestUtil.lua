--- This file is only for functional tests outside of the game.
function debug(str,...)
	print(string.format(str,...))
end

function debugTable(table,inputIndent)
	inputIndent = inputIndent or "  "
	for i,j in pairs(table) do
        print(inputIndent..tostring(i).." :: "..tostring(j))
        if type(j) == "table" then
            debugTable(j, inputIndent.."    ")
        end
    end
end