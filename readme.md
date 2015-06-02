# boxstarter-config

<b>My dev machine repave scripts using boxstarter and chocolatey</b>

# Installation
Just run the following from powershell command line
<code>START http://boxstarter.org/package/url?https://raw.github.com/flimble/boxstarter-config/master/devmachine.txt</code>

<b>To use local packages - do the following: </b>
$cachePath = C:\ChocolateyCachedInstallers
if(!(Test-Path -Path $cachePath)){
   New-Item -ItemType directory -Path $cachePath
}
$env:ChocolateyLocalCachePath = $cachePath
