REM set PATH=C:\projects\ruby\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set PATH=C:\Ruby32-x64\bin;C:\Program Files\Git\mingw64\bin;C:\projects\openstudio\bin;%PATH%
set BUNDLE_VERSION=2.4.10
set GEM_HOME=C:\projects\openstudio-server\gems
set GEM_PATH=C:\projects\openstudio-server\gems;C:\projects\openstudio-server\gems\gems\bundler\gems
set RUBYLIB=C:\projects\openstudio\Ruby
set OPENSTUDIO_TEST_EXE=C:\projects\openstudio\bin\openstudio

REM set mongo_dir??
cd c:\
mkdir export
echo installing json gem version 2.7.2
gem install json -v 2.7.2
echo openstudio_meta install_gems
ruby C:\projects\openstudio-server\bin\openstudio_meta install_gems --export="C:\export"
mv C:\export C:\projects\openstudio-server\export
dir C:\projects\openstudio-server\export
