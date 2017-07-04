--- Setting up packages
courseGenerator = {}

--- Debug print, will either just call print when running standalone
--  or use the CP debug channel when running in the game.

function courseGenerator.debug( text )
  if courseGenerator.isRunningInGame() then
	  courseplay:debug( text, 7 );
  else
    print( text )
  end
end

--- Return true when running in the game
-- used by file and log functions to determine how exactly to do things,
-- for example, io.flush is not available from within the game.
--
function courseGenerator.isRunningInGame()
  return courseplay ~= nil;
end
