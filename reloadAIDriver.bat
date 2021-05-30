@echo off
set outfile=reload.xml
echo ^<code^> > %outfile%
echo ^<![CDATA[ >> %outfile%
type AIDriver.lua >> %outfile%
type FieldworkAIDriver.lua >> %outfile%
type FillableFieldworkAIDriver.lua >> %outfile%
type PlowAIDriver.lua >> %outfile%
type UnloadableFieldworkAIDriver.lua >> %outfile%
type GrainTransportAIDriver.lua >> %outfile%
type BaleLoaderAIDriver.lua >> %outfile%
type BaleCollectorAIDriver.lua >> %outfile%
type BaleWrapperAIDriver.lua >> %outfile%
type BalerAIDriver.lua >> %outfile%
type CombineAIDriver.lua >> %outfile%
type CombineUnloadAIDriver.lua >> %outfile%
type OverloaderAIDriver.lua >> %outfile%
type BunkerSiloAIDriver.lua >> %outfile%
type CompactingAIDriver.lua >> %outfile%
type ShieldAIDriver.lua >> %outfile%
type BunkerSiloLoaderAIDriver.lua >> %outfile%
type MixerWagonAIDriver.lua >> %outfile%
echo ]]^> >> %outfile%
echo ^</code^> >> %outfile%