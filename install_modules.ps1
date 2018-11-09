Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm

#Install AzureRM PowerShell Module
Install-Module AzureRM -allowclobber
Import-Module AzureRM

#Install PSSlack Powershell Module
Install-Module PSSlack -Force
Import-Module PSSlack

#Install Git
PowerShellGet\Install-Module posh-git -Scope CurrentUser
Invoke-WebRequest -Uri https://github.com/git-for-windows/git/releases/download/v2.14.3.windows.1/Git-2.14.3-64-bit.exe -OutFile .\git.exe
.\git.exe
start-sleep 60
import-module posh-git
Add-PoshGitToProfile

