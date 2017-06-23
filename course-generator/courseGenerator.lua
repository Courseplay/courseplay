--- Setting up packages
courseGenerator = {}

--- Debug print, will either just call print when running standalone
--  or use the CP debug channel when running in the game.

function courseGenerator.debug( text )
  if isRunningInGame then
	  courseplay:debug( text, 7 );
  else
    print( text )
  end
end
