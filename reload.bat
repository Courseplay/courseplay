@echo off
set sourcefile=%1
set outfile=reload.xml
echo ^<code^> > %outfile%
echo ^<![CDATA[ >> %outfile%
type %sourcefile% >> %outfile%
echo ]]^> >> %outfile%
echo ^</code^> >> %outfile%
