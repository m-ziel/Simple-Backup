# TODO:
# check if invoked with admin privileges
# not hardcode paths

Set-Variable vshadowPath -Value "cmd.exe" -Option Constant
# Set-Variable backupTempDirPath -Value 

Function Main {
	# Set-Variable vshadowPath -Value "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\vshadow.exe" -Option Constant 
	
	$vshadowOutScriptPath = "C:\Users\Michal\Stuff\backup-script\misc\$Get-Vshadow-Output-Script-Name"
	$snapshotId = $null
	try {
		Create-Vss-Snapshot($vshadowOutScriptPath)
		$snapshotId = Get-Snapshot-Id($vshadowOutScriptPath)
		Mount-Vss-Snapshot($snapshotId, "S")
	}
	finally {
		# Remove-Item -Path $vshadowOutScriptPath
		Delete-Vss-Snapshot($snapshotId)
	}
}

# creates the snapshot, snapshot ID will be at $scriptFilePath
Function Create-Vss-Snapshot {
	param([String]$scriptFilePath)
	Run-Vshadow("-p -script='$scriptFilePath' C:")
}

Function Get-Vshadow-Output-Script-Name { 
	return Get-Date -Format "'vshadow_out_script_'yyyy-MM-dd_HH-mm-ss-fff'.cmd'"
}

# retrieve snapshot ID from VShadow output script file at $scriptPath
Function Get-Snapshot-Id {
	param([String]$scriptPath)
	$uuidRegex = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
	$pattern = "^SET +SHADOW_ID_1 *= *{($uuidRegex)}$"
	$matchInfo = Select-String -Pattern $pattern -Path $scriptPath
	$groups = $matchInfo.Matches.Groups
	If($groups.length -lt 2) {
		throw "Snapshot ID not found in VShadow output script."
	}
	return $groups[1].Value
}

Function Mount-Vss-Snapshot {
	param([String]$snapshotId, [String]$driveLetter)
	If($driveLetter.length -ne 1) {
		throw "Drive letter must be a single character."
	}
	$vshadowExitCode = Run-Vshadow("-el={$snapshotId},$driveLetter:")
}

Function Run-Vshadow {
	param([String]$args)
	$vshadowProcess = Start-Process -Wait -PassThru -FilePath $vshadowPath -ArgumentList $args
	$exitCode = $vshadowProcess.ExitCode
	
	# possible values for exit code from VShadow source code:
	# Return values:
	#     0 - Success
	#     1 - Object not found
	#     2 - Runtime Error 
	#     3 - Memory allocation error
	
	if($exitCode -ne 0) {
		throw "VShadow failed with code $exitCode."
	}
}

Function Delete-Vss-Snapshot {
	param([String]$snapshotId)
	Run-Vshadow("-ds={$snapshotId}")
}

# === invoke Main ===
Main
