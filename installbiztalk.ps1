<#
.SYNOPSIS
	Automates BizTalk Application deployment using BTDF 5.0

.DESCRIPTION
	Automates BizTalk Application deployment using BTDF 5.0
		Steps:
			1. It installs the MSI on the specified application path
			2. Calls EnvironmentSettingsExporter to generate the settings xml
			3. Updates Environment Variables
			4. Executes the MSBuild with parameters

.NOTES
	File Name: Install-BizTalkApplication.ps1
	Author: Randy Aldrich Paulo
	Prerequisite: Powershell 2.0, BizTalk Deployment Framework 5.0, BizTalk Server 2010

.PARAMETER MsiFile
	MSI File generated using BizTalk Deployment Framework 5.0

.PARAMETER ApplicationInstallPath
	Location wherein the resource files will be copied, it will be use by the BTDF during the deployment

.PARAMETER Environment
	Name of environment (Local,Dev,Test,Prod) to be used, this value will be passed to 
	EnvironmentSettingsExporter and willbe used to construct the environment variable: ENV_SETTINGS

.EXAMPLE
	Install-BizTalkApplication -MsiFile "E:\Installer\Application 1\Application1.msi" 
	-ApplicationInstallPath "E:\Program Files\Application 1"
	-Environment DEV

.EXAMPLE
	Install-BizTalkApplication -msi "E:\Installer\Application 1\Application1.msi" 
	-path "E:\Program Files\Application 1"
	-env TEST

.EXAMPLE
	Install-BizTalkApplication "E:\Installer\Application 1\Application1.msi" 
	"E:\Program Files\Application 1" TEST

.EXAMPLE
	Install-BizTalkApplication "E:\Installer\Application 1\Application1.msi" 
	"E:\Program Files\Application 1" TEST -SkipUndeploy $false

#>
function Install-BizTalkApplication
{
	param(
		[Parameter(Position=0,Mandatory=$true,HelpMessage="Msi file should be existing")]
		[ValidateScript({Test-Path $_})]
		[Alias("msi")]
		[string]$MsiFile,
		
		[Parameter(Position=1,HelpMessage="Path wherein the resource file will be installed")]
		[Alias("path")]
		[string]$ApplicationInstallPath,
		
		[Parameter(Position=2,Mandatory=$true,HelpMessage="Only valid parameters are Local,Dev,Test and Prod")]
		[Alias("env")]
		[ValidateSet("Local","Dev","Prod","Test")]
		[string]$Environment,

		[bool]$BTDeployMgmtDB=$true,
		[bool]$SkipUndeploy=$true
		)

	$ErrorActionPreference="Stop"

	#Step 1 : Run MSI	
		$script = 
		{
		    $args = "-i $MsiFile INSTALLDIR=`"$ApplicationInstallPath`" /qn /norestart"
			Write-Host " Installing MSI File.." -ForegroundColor Cyan
			Write-Host " 	MSI File: $MsiFile" -ForegroundColor DarkGray 
			Write-Host " 	    Args: $args" -ForegroundColor DarkGray 
			
			$exitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -Passthru).ExitCode
			Write-Host "	Exit Code: $exitCode" 
			
			if($exitCode -ne 0)
			{
				Write-Error "Installing $MsiFile failed!, Exit Code: $exitCode" 
			}
			Write-Host " Installed MSI success.." -ForegroundColor Green
			Write-Host ""
		}
		Invoke-Command -scriptblock $script
	
	#Step 2 : Run MSBuild & Deploy
	
		$script=
		{
			<# Start Step 2.2 Run EnvironmentSettingsExporter, this one generates the xml file 
			(Exported_DevSettings.xml, Exported_LocalSettings.xml etc..)
			#>
			$args = "`"" + (Join-Path $ApplicationInstallPath "Deployment\EnvironmentSettings\SettingsFileGenerator.xml") + "`"" + " Deployment\EnvironmentSettings"
			$exePath = ("`"" + (Join-Path $ApplicationInstallPath "\Deployment\Framework\DeployTools\EnvironmentSettingsExporter.exe") + "`"")
			Write-Host " Generating Environment Settings File.."  -ForegroundColor Cyan
			Write-Host "	Location: $exePath" -ForegroundColor DarkGray
			Write-Host " 	Args: $args" -ForegroundColor DarkGray

			$exitCode = (Start-Process -FilePath $exePath -ArgumentList $args -Wait -PassThru).ExitCode
			Write-Host "	Exit Code: $exitCode"
			
			if($exitCode -ne 0)
			{
				Write-Error " Generating Environment Settings File failed!, Exit Code: $exitCode"
			}
			Write-Host " Generated Environment Settings File. " -ForegroundColor Green
			Write-Host ""
			<# End Step 2.2 Run EnvironmentSettingsExporter, this one generates the xml file 
			(Exported_DevSettings.xml, Exported_LocalSettings.xml etc..)#>


			<# Start Step 2.3 Set the Environment Variables ENV_SETTINGS and BT_DEPLOY_MGMT_DB #>
			$settingsFile = "Deployment\EnvironmentSettings\Exported_{0}Settings.xml" -f $Environment
			$EnvSettings =Join-Path $ApplicationInstallPath $settingsFile

			Write-Host " Setting Environment Variables"  -ForegroundColor Cyan
			
			Write-Host "	     ENV_SETTINGS = $EnvSettings" -ForegroundColor DarkGray; 
			Set-Item Env:\ENV_SETTINGS -Value $EnvSettings
			
			Write-Host  "	BT_DEPLOY_MGMT_DB = $BTDeployMgmtDB"  -ForegroundColor DarkGray; 
			Set-Item Env:\BT_DEPLOY_MGMT_DB -Value $BTDeployMgmtDB
			
			Write-Host " Setted Environment Variables"  -ForegroundColor Green
			Write-Host ""
			<# End Step 2.3 Set the Environment Variables ENV_SETTINGS and BT_DEPLOY_MGMT_DB #>
			
			<# Start Step 2.4 Execute MS Build with parameters #>
			
			#Get .NET Version
			$dotNetVersion = gci 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' | sort pschildname -des | select -fi 1 -exp pschildname
			if($dotNetVersion = "v4.0") { $dotNetVersion = "v4.0.30319" } #Include other info if .NET 4.0
			
			if (Test-Path ( Join-Path $env:windir "Microsoft.NET\Framework\$dotNetVersion\MSBuild.exe" ))
			{
				$BTDFMSBuildPath = Join-Path $env:windir "Microsoft.NET\Framework\$dotNetVersion\MSBuild.exe" 
				Write-Host " Using MSBuild $dotNetVersion" -ForegroundColor DarkGray 
			}
			else
			{
				Write-Error " MSBuild not found."
			}
			
			#Assign MS Build Params
			$parms="DeployBizTalkMgmtDB=$BTDeployMgmtDB;Configuration=Server;SkipUndeploy=$SkipUndeploy"
			$logger="FileLogger,Microsoft.Build.Engine;logfile=`"" + ( Join-Path $ApplicationInstallPath "DeployResults\DeployResults.txt" ) + "`""
			$btdfFile="`"" +  (Join-Path $ApplicationInstallPath "Deployment\Deployment.btdfproj") + "`""
			$args = "/p:{1} /l:{2} {0}" -f $btdfFile,$parms,$logger
			
			Write-Host " Executing MSBuild from: $BTDFMSBuildPath"  -ForegroundColor Cyan 
			Write-Host "	ArgList: $args" -ForegroundColor DarkGray
			
			#Check MSBuild Return Code
			$exitCode = (Start-Process -FilePath $BTDFMSBuildPath -ArgumentList $args -Wait -Passthru).ExitCode
			Write-Host "	Exit Code: $exitCode" 
			Write-Host ""
			if($exitCode -ne 0)
			{
				Write-Error " Error while calling MSBuild, Exit Code: $exitCode"
			}
		
			#Copy Log File
			Write-Host "	Copying  Log file."
			$args =  "Deployment\Framework\CopyDeployResults.msbuild /nologo"
			Start-Process -FilePath $BTDFMSBuildPath -ArgumentList $args
			
			<# End Step 2.4 Execute MS Build with parameters #>
		}
	
		Write-Host " Running MS Build and deploying.." -ForegroundColor Cyan
		Invoke-Command -scriptblock $script
		Write-Host " Deployed application" -ForegroundColor Green

}
