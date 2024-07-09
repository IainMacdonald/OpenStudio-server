# Path to the existing Ruby installation directory
$rubyInstallDir = "C:/Ruby32"
$rubyInstallDirx64 = "C:/Ruby32-x64"

# Path to the existing Ruby uninstaller
$uninstallerPath = "$rubyInstallDir/unins000.exe"

# Check if the uninstaller exists and run it
if (Test-Path $uninstallerPath) {
    Write-Host "Uninstalling existing Ruby installation..."
    Start-Process -FilePath $uninstallerPath -ArgumentList "/SILENT" -Wait
} else {
    Write-Host "No Ruby uninstaller found at $uninstallerPath"
}

# Delete the Ruby installation directory if it still exists
if (Test-Path $rubyInstallDir) {
    Write-Host "Deleting the Ruby installation directory..."
    Remove-Item -Path $rubyInstallDir -Recurse -Force
    Remove-Item -Path $rubyInstallDirx64 -Recurse -Force
} else {
    Write-Host "Ruby installation directory not found at $rubyInstallDir"
}

# Download and install 64-bit Ruby 3.2.2 from RubyInstaller website
$rubyInstallerUrl = "https://rubyinstaller.org/downloads/archives/rubyinstaller-3.2.2-1-x64.exe"
$installerPath = "C:\rubyinstaller-3.2.2-1-x64.exe"

Write-Host "Downloading 64-bit Ruby 3.2.2 installer..."
Invoke-WebRequest -Uri $rubyInstallerUrl -OutFile $installerPath

Write-Host "Installing 64-bit Ruby 3.2.2..."
Start-Process -FilePath $installerPath -ArgumentList "/verysilent /allusers /tasks=""assocfiles,modpath"" /dir=C:\Ruby32-x64" -Wait

# Clean up the installer
Remove-Item -Path $installerPath

# Update PATH environment variable
[System.Environment]::SetEnvironmentVariable("Path", "C:\Ruby32-x64\bin;" + [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine), [System.EnvironmentVariableTarget]::Machine)

# Verify installation
Write-Host "Verifying Ruby installation..."
$env:Path = "C:\Ruby32-x64\bin;" + $env:Path
ruby -v
gem -v
