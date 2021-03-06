function Register-PseudoService
{
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({((Test-PseudoService -Name $_) -eq $false) -and (Test-PseudoServiceRegistrantIsAdministrator)})]
		[string]$PseudoServiceName,

		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({Test-Path -Path $_ -PathType Leaf})]
		[string]$ExecutableFile,

		[ValidateNotNullOrEmpty()]
		[string[]]$Arguments=$null,

		[ValidateNotNullOrEmpty()]
		[string]$Description
	)

	Write-Verbose -Message ("Script confirmed at location: ${ExecutableFile}")

	$taskName = "${PseudoServiceName}${pseudoServiceSuffix}"

	$taskAction = $null
	if ($Arguments)
	{
		$parsedArguments = $Arguments -join " "
		$taskAction = New-ScheduledTaskAction -Execute $ExecutableFile -Argument "${parsedArguments}"
	}
	else
	{
		$taskAction = New-ScheduledTaskAction -Execute $ExecutableFile
	}

	if (!$taskAction)
	{
		return Get-PseudoServiceInfo -PseudoServiceName $PseudoServiceName
	}

	$creationDate = Get-Date
	
	$taskTrigger = New-ScheduledTaskTrigger -Once:$false -At $creationDate -RepetitionDuration ([TimeSpan]::MaxValue) -RepetitionInterval (New-TimeSpan -Minutes 5)
	$taskSettings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -WakeToRun

	if (!$taskSettings)
	{
		return Get-PseudoServiceInfo -PseudoServiceName $PseudoServiceName
	}
	$taskSettings.ExecutionTimeLimit = "PT0S" #this disables the stop the task checkbox

	
	$taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

	if (!$taskPrincipal)
	{
		return Get-PseudoServiceInfo -PseudoServiceName $PseudoServiceName
	}

	$dom = $env:userdomain
	$usr = $env:username
	
	$creationDate = Get-Date
	$Description = "This task was created by the Register-PseudoService PowerShell cmdlet on [${creationDate}].`n`n${Description}"

	$scheduledTask = New-ScheduledTask -Action $taskAction -Principal $taskPrincipal -Trigger $taskTrigger -Settings $taskSettings
	if (!$scheduledTask)
	{
		return Get-PseudoServiceInfo -PseudoServiceName $PseudoServiceName
	}

	$scheduledTask.Author = ([adsi]"WinNT://$dom/$usr,user").FullName
	$scheduledTask.Description = $Description
	$scheduledTask.Date = $creationDate

	Register-ScheduledTask -TaskName $taskName -InputObject $scheduledTask | Out-Null
	Get-PseudoServiceInfo -PseudoServiceName $PseudoServiceName
}