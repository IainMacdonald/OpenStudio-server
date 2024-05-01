REM Setup supported bundler on windows 
set PATH=C:\Ruby32-x64\bin;C:\Program Files\Git\mingw64\bin;%PATH%
set BUNDLE_VERSION=2.4.10

REM  uninstall versions of bundler that cause problems 
call gem uninstall -s --force bundler
REM  ruby won't let you uninstall default gems but you can delete the specfile
del C:\Ruby32-x64\lib\ruby\gems\3.2.3\specifications\bundler*
del C:\Ruby32-x64\lib\ruby\gems\3.2.3\specifications\default\bundler*
call gem install bundler -v %BUNDLE_VERSION%
call bundle --version