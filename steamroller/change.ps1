notepad tmp | out-null 
add-type -AssemblyName system.web 
glu | ?{$_.name -notin (gc tmp.txt)} | %{
    $pass = [system.web.security.membership]::GeneratePassword(17,2)
    set-localuser -name $_.name -password (convertto-securestring -AsPlainText $pass -force)
    $pass = $Null
}
del tmp.txt