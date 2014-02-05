START http://boxstarter.org/package/url?https://raw.github.com/flimble/boxstarter-config/master/devmachine.txt

To use local packages - do the following: 
$cachePath = C:\ChocolateyCachedInstallers
if(!(Test-Path -Path $cachePath)){
   New-Item -ItemType directory -Path $cachePath
}
$env:ChocolateyLocalCachePath = $cachePath