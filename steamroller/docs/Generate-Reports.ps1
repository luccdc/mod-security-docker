Get-Gpo -All -Domain Eprg.local | Select -ExpandProperty DisplayName | %{Get-GpoReport -Name $_ -ReportType HTML -path "$pwd\$_.html"}