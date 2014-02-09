function Get-DropBox() {
  $hostFile = Join-Path (Split-Path (Get-ItemProperty HKCU:\Software\Dropbox).InstallPath) "host.db"
  $encodedPath = [System.Convert]::FromBase64String((Get-Content $hostFile)[1])
  [System.Text.Encoding]::UTF8.GetString($encodedPath)
}

$dropbox_dir = Get-DropBox
Move-LibraryDirectory "Downloads" "$dropbox_dir\Downloads"  -DoNotMoveOldContent
Move-LibraryDirectory "My Music" "$dropbox_dir\Music" -DoNotMoveOldContent
Move-LibraryDirectory "My Pictures" "$dropbox_dir\Pictures" -DoNotMoveOldContent
Move-LibraryDirectory "My Video" "$dropbox_dir\Media" -DoNotMoveOldContent

#get rid of upper case menu in Visual Studio. Only Available AFTER first time visual studio has been opened.
Set-ItemProperty -Path HKCU:\Software\Microsoft\VisualStudio\11.0\General -Name SuppressUppercaseConversion -Type DWord -Value 1 