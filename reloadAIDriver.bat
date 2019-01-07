@echo off
set outfile=reload.xml
echo ^<code^> > %outfile%
echo ^<![CDATA[ >> %outfile%
type AIDriver.lua >> %outfile%
type FieldworkAIDriver.lua >> %outfile%
type FillableFieldworkAIDriver.lua >> %outfile%
type UnloadableFieldworkAIDriver.lua >> %outfile%
type GrainTransportAIDriver.lua >> %outfile%
echo ]]^> >> %outfile%
echo ^</code^> >> %outfile%