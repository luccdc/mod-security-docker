<#
.Synopsis
   Hardens a Windows domain
.DESCRIPTION
   Uses a series of predefined GPO and programs to secure core aspects of the Windows operating system across a domain
.EXAMPLE
   & driver.ps1
.EXAMPLE
   start.bat
.INPUTS
   None
.OUTPUTS
   C:\incred.csv with plaintext usernames and passwords for domain and local users
.NOTES
   File	Name	: driver.ps1
   Author	    : Msfv3n0m
   Requires	    : GroupPolicy, ActiveDirectory, Microsoft.PowerShell.Utility, Microsoft.PowerShell.Management, Microsoft.PowerShell.Security, Microsoft.PowerShell.LocalAccounts PowerShell modules   
.LINK
   https://github.com/Msfv3n0m/SteamRoller3
#>
function Resume () {
	$input = ""
	While ($input -ne "cont") {
	Write-Host "Type 'cont' to continue `n" -ForegroundColor Yellow
	$input = Read-Host "input"
	}
	Write-Host "`n"
}

function GetTools ($cd, $downloads) {
    gci -file $downloads | ?{$_.name -like "*hollows_hunter*"} | %{Copy-Item $_.fullname $cd\SharingIsCaring\tools}
    gci -file $downloads | ?{$_.name -like "*processhacker*"} | %{Copy-Item $_.fullname $cd\SharingIsCaring\tools}
    gci -file $downloads | ?{$_.name -like "*bluespawn*"} | %{Copy-Item $_.fullname $cd\SharingIsCaring\tools}
    gci -file $downloads | ?{$_.name -like "*cutter*"} | %{Copy-Item $_.fullname $cd\SharingIsCaring\tools}
    gci -file $downloads\7z*.msi | %{Move-Item $_.FullName $cd\SharingIsCaring\7z.msi}
    if (Test-Path $downloads\Sysinternals\) {
        Copy-Item $downloads\Sysinternals\sdelete.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\TCPVCon.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\PSExec.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\sdelete.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\Autoruns.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\strings.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\TCPView.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\procexp.exe $cd\SharingIsCaring\tools
        Copy-Item $downloads\Sysinternals\Sysmon.exe $cd\SharingIsCaring
    }
	Write-Host "`nEnsure that the appropriate tools are in the .\SharingIsCaring\tools folder" -ForegroundColor Yellow
	Resume
}


function CreateOUAndDistribute () {
    Write-Host "Creating OUs and Distributing Computers" -ForegroundColor Green
    $root = (Get-ADRootDSE | Select -ExpandProperty RootDomainNamingContext)
    Get-ADComputer -Filter {OperatingSystem -like "*Windows*"} -SearchBase "CN=Computers,$root" | %{
        $input1 = "CN=" + $_.Name + ",CN=Computers," + $root
        $input2 = "OU=" + $_.Name + "," + $root
        New-ADOrganizationalUnit -Name $_.Name -Path $root 
        Move-ADObject -Identity $input1 -TargetPath $input2
        New-GPLink -Name "Tools" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "WinRM (http)" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "General" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "Events" -Target $input2 -LinkEnabled Yes -Enforced No
        New-GPLink -Name "RDP" -Target $input2 -LinkEnabled Yes -Enforced Yes
    }
    Get-ADComputer -Filter {OperatingSystem -like "*Windows*"} -SearchBase "OU=Domain Controllers,$root" | %{
        $input1 = "CN=" + $_.Name + ",OU=Domain Controllers," + $root
        $input2 = "OU=" + $_.Name + "," + $root
        New-ADOrganizationalUnit -Name $_.Name -Path $root 
        Move-ADObject -Identity $input1 -TargetPath $input2
        New-GPLink -Name "Tools" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "WinRM (http)" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "General" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "Events" -Target $input2 -LinkEnabled Yes -Enforced No
        New-GPLink -Name "RDP" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "SMB" -Target $input2 -LinkEnabled Yes -Enforced Yes
        New-GPLink -Name "ADDS (LDAP)" -Target $input2 -LinkEnabled Yes -Enforced Yes
    }
}

function StartSMBShare ($cd) {
    Write-Host "Starting SMB Share" -ForegroundColor Green
    net share SharingIsCaring="$cd\SharingIsCaring"
    icacls.exe "$cd\SharingIsCaring" /inheritancelevel:e /grant "*S-1-5-11:(OI)(CI)(R)" #grant acess to authenticated users
}

$passFuncs = {
function ChangeLocalPasswords ($ServersList, $cd, $admin) {
  Write-Host "Changing local passwords" -ForegroundColor Green
  $ServersList | %{
    Write-Host "Attempting to change passwords on $_" -ForegroundColor Green 
    Try {
        Invoke-Command -ComputerName $_ -ArgumentList $cmdCommand, $admin -ScriptBlock {
            Param($cmdCommand, $admin)
            Try {
                Add-Type -AssemblyName System.Web
                Get-LocalUser | ?{$_.Name -ne 'bone' -and $_.Name -ne 'bwo' -and $_.Name -ne 'bee'} | %{                           
                    $pass=[System.Web.Security.Membership]::GeneratePassword(17,2)
                    $pass = $pass.replace(',','!')
                    $pass = $pass.replace(';','?')
                    Set-LocalUser -Name $_.Name -Password (ConvertTo-SecureString -AsPlainText $pass -Force)
                    Write-Output "$(hostname)\$_,$pass"
                    $pass = $Null
                }
                Write-Host "Passwords randomized on $(hostname)" -ForegroundColor Green         
            }
            Catch {
                Add-Type -AssemblyName System.Web
                Get-WMIObject -Class Win32_UserAccount | ?{$_.Name -ne 'bone' -and $_.Name -ne 'bwo' -and $_.Name -ne 'bee'} | %{
                    $name = $_.Name
                    $pass=[System.Web.Security.Membership]::GeneratePassword(17,2)
                    $pass = $pass.replace(',','!')
                    $pass = $pass.replace(';','?')
                    net user $_.Name $pass > $Null
                    Write-Output "$(hostname)\$name,$pass"
                    $pass = $Null
                }
                wevtutil cl Microsoft-Windows-Powershell/Operational
                Write-Host "Passwords randomized on $(hostname) with wmi" -ForegroundColor Green   
            }
        } # >> C:\incred.csv 
		# & $cd\PsExec.exe \\$_ -nobanner -accepteula powershell -command "Add-Type -AssemblyName System.Web;`$c = ','; `$h=`$(hostname); Get-LocalUser | ?{`$_.Name -ne 'Administrator'} | %{`$pass=[System.Web.Security.Membership]::GeneratePassword(20,2); Set-LocalUser -Name `$_.Name -Password (ConvertTo-SecureString -AsPlainText `$pass -Force); Write-Output `$h\`$_`$c`$pass; `$pass = `$Null}" >> C:\incred.csv
	}
    Catch {
    	  Write-Output "Could not access " $_
    	}
    }
}

function ChangeADPass () {
        $domain = $(Get-ADDomain | Select -ExpandProperty NetBIOSName)
        Add-Type -AssemblyName System.Web
        # Write-Output "Username,Password" > C:\incred.csv
        Get-ADUser -Filter * | ?{$_.Name -ne $env:username -and $_.Name -ne 'bone' -and $_.Name -ne 'bwo' -and $_.Name -ne 'bee'} | %{
            $user = $_.SAMAccountName
            $pass = [System.Web.Security.Membership]::GeneratePassword(17,2)
            $pass = $pass.replace(',','!')
            $pass = $pass.replace(';','?')

            Write-Output "$domain\$user,$pass"
            Set-ADAccountPassword -Identity $_.SAMAccountName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $pass -Force) 
            $pass = $Null
        }
    }
}


function ImportGPO2 ([String]$rootdir,[switch]$formatOutput) {
    <#
    This function is a derivative of a script found in Microsoft's Security Compliance Toolkit 
    #>
    $results = New-Object System.Collections.SortedList
    Get-ChildItem -Recurse -Include backup.xml $rootdir | ForEach-Object {
        $guid = $_.Directory.Name
        $displayName = ([xml](gc $_)).GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
        $results.Add($displayName, $guid)
    }
    # if ($formatOutput)
    # {
    #     $results | Format-Table -AutoSize
    # }
    # else
    # {
    #     $results
    # }
}

function ImportGPO1 ($cd) {
<#
This function is a derivative of a script found in Microsoft's Security Compliance Toolkit 
#>
    $gpoDir = "$cd\GPO"
    Write-Host "Importing GPOs" -ForegroundColor Green
        $GpoMap = New-Object System.Collections.SortedList
    Get-ChildItem -Recurse -Include backup.xml $gpoDir | ForEach-Object {
        $guid = $_.Directory.Name
        $displayName = ([xml](gc $_)).GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
        $GpoMap.Add($displayName, $guid)
    }
    # $GpoMap = ImportGPO2("$cd\GPO")
    #Write-Host "Importing the following GPOs:"
    #Write-Host
    #$GpoMap.Keys | ForEach-Object { Write-Host $_ }
    #Write-Host
    #Write-Host
    $GpoMap.Keys | ForEach-Object {
        $key = $_
        $guid = $GpoMap[$key]
        #Write-Host ($guid + ": " + $key)
        Import-GPO -BackupId $guid -Path $gpoDir -TargetName "$key" -CreateIfNeeded | Out-Null
    }
}

function Replace ($cd) {
    Write-Host "Inserting DC Name into GPOs" -ForegroundColor Green
    Get-ChildItem "$cd\GPO\" | %{
        $path1 = $_.FullName + "\gpreport.xml"
        if (Test-Path -Path $path1 -PathType Leaf) {
                (Get-Content $path1) -replace "replaceme1", "$(hostname)" | Set-Content $path1
        }
            $path2 = $_.FullName + "\DomainSysvol\GPO\Machine\Preferences\Files\Files.xml"
        if (Test-Path -Path $path2 -PathType Leaf) {
            (Get-Content $path2) -replace "replaceme1", "$(hostname)" | Set-Content $path2
        }
    } 
}

function RemoveFirewallRules($ServersList, $DCList) {
    Write-Host "Blocking default inbound and outbound traffic" -ForegroundColor Green
    if ($ServersList -ne $Null)
    {
        $ServersList| %{
            Invoke-Command -ComputerName $_ -ScriptBlock {
                Try {
                    netsh advfirewall firewall set rule all new enable=no 
                }
                Catch {
                    Write-Host "Could not block default inbound and outbound traffic on $_" -ForegroundColor Red
                }
            }
        }
    }
    if ($ServersList -ne $Null)
    {
    $DCList| %{
            Invoke-Command -ComputerName $_ -ScriptBlock {
                Try {
                    netsh advfirewall firewall set rule all new enable=no 
                }
                Catch {
                    Write-Host "Could not block default inbound and outbound traffic on $_" -ForegroundColor Red
                }
            }
        }
    }
}

function RemoveLinks ($ServersList, $DCList) {
    Write-Host "Removing GPO links" -ForegroundColor Green
    $root = (Get-ADRootDSE | Select -ExpandProperty RootDomainNamingContext)
    if ($ServersList -ne $Null)
    {
        $ServersList| %{
            $input2 = "OU=" + $_.Name + "," + $root
            Remove-GPLink -Name "Tools" -Target $input2 > $Null
            Remove-GPLink -Name "RDP" -Target $input2 > $Null
            Remove-GPLink -Name "WinRM (http)" -Target $input2 > $Null
            Remove-GPLink -Name "Events" -Target $input2 > $Null
        }
    }
    $DCList | %{
        $input2 = "OU=" + $_.Name + "," + $root
        Remove-GPLink -Name "Tools" -Target $input2 > $Null
        Remove-GPLink -Name "RDP" -Target $input2 > $Null
        Remove-GPLink -Name "WinRM (http)" -Target $input2 > $Null
        Remove-GPLink -Name "Events" -Target $input2 > $Null
    }
}

function ChangeAdminPass () {
    Write-Host "Setting a new administrator password" -ForegroundColor Yellow
    net user $env:username *
    # $newPass = Read-Host "Please set a new password for $(whoami)" -AsSecureString
    # Set-ADAccountPassword -Identity $env:username -NewPassword $newPass -Reset
    # netdom resetpwd /s:localhost /ud: $env:username /pd:*
}

function StopSMBShare () {
    Write-Host "Deleting SMB Share" -ForegroundColor Green
  net share SharingIsCaring /del /yes
}

function DeleteDriver ($cd) {
    Write-Host "Deleting driver.ps1" -ForegroundColor Green
	& "$cd\sdelete.exe" -accepteula -p 3 "$(pwd)\driver.ps1" > $Null
}


# Main
# Variables
$root = (Get-ADRootDSE | Select -ExpandProperty RootDomainNamingContext)    # used in removelinks and createouanddistribute
$cd = $(pwd)                                                                # used in changelocalpasswords, gettools, importgpo1, deletedriver, startsmbshare, replace
$gpoDir = "$(pwd)\GPO"                                                      # used in importgpo1
$domain = $(Get-ADDomain | Select -ExpandProperty NetBIOSName)              # used in changeadpass
$downloads = "$home\Downloads"                                              # used in gettools

$root = (Get-ADRootDSE | Select -ExpandProperty RootDomainNamingContext)
$ServersList = $(Get-ADComputer -Filter {OperatingSystem -like "*Windows*"} -SearchBase "CN=Computers,$root")     # used in createouanddistribute, removelinks, changelocalpasswords
$DCList = $(Get-ADComputer -Filter {OperatingSystem -like "*Windows*"} -SearchBase "OU=Domain Controllers,$root")     # used in createouanddistribute, removelinks, changelocalpasswords

$ServersList | Select -ExpandProperty Name >> servers.txt
$ServersList | Select -ExpandProperty Name >> all.txt
$DCList | Select -ExpandProperty Name >> all.txt
$DCList | Select -ExpandProperty Name >> dc.txt
$AllServers = gc all.txt

$replace_job = Start-Job -name 'replace hostname' -ScriptBlock ${Function:Replace} -ArgumentList $cd

$extract_sysinternals_job = Start-Job -name 'extract sysinternals'-ScriptBlock {
    param($downloads)
    gci -file $downloads | ?{$_.name -like "*Sysinternals*"} | %{Expand-Archive $_.Fullname $downloads\Sysinternals -Force}
} -ArgumentList $downloads

Write-Host "Waiting to import GPOs" -ForegroundColor Green
$replace_job | Wait-Job
Write-Host "Importing GPOs" -ForegroundColor Green
$ou_gpo_job = Start-Job -name 'import gpos' -ScriptBlock ${Function:ImportGPO1} -ArgumentList $cd



$extract_sysinternals_job | Wait-Job
Write-Host "Copying tools to SharingIsCaring folder" -ForegroundColor Green
GetTools $cd $downloads
Write-Host "Compressing tools folder" -ForegroundColor Green
$compress_tools_job = Start-Job -name 'compress tools' -ScriptBlock {
    param($cd)
    Compress-Archive $cd\SharingIsCaring\tools $cd\SharingIsCaring\tools.zip
} -ArgumentList $cd
$ou_gpo_job | Wait-Job
Write-Host "Creating OUs and distributing computers" -ForegroundColor Green
$distribute_ou_job = Start-Job -name 'create ous and distribute hosts' -ScriptBlock ${Function:CreateOUAndDistribute}
Write-Host "Starting smb share" -ForegroundColor Green
$start_share_job = Start-Job -name 'start smb share' -ScriptBlock ${Function:StartSMBShare} -ArgumentList $cd
$compress_tools_job | Wait-Job
$distribute_ou_job | Wait-Job 
$start_share_job | Wait-Job 

Write-Host "`nManually upate the group policy configuration on each member in the domain" -ForegroundColor Yellow
gpupdate /force
Resume

RemoveLinks $ServersList $DCList

New-GPLink -Name "PSLogging" -Target "$root" -LinkEnabled Yes -Enforced Yes > $Null

Write-Host "The program has completed successfully. Now, Manually update the group policy configuration on all computers in the domain" -ForegroundColor Green
gpmc.msc
# DeleteDriver $cd
gpupdate /force 
powershell
