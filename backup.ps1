# TODO:
# check if invoked with admin privileges
# not hardcode paths
# assert high enough powershell version
# maybe implement preserving links that do not go outside of the 'backup zone'
# caveats when source directory is volume root

Set-Variable vshadowPath -Value "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\vshadow.exe" -Option Constant

Function Main {
	# Set-Variable vshadowPath -Value "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\vshadow.exe" -Option Constant 
	
    echo "Executing as $($Env:UserName)."
	$vshadowOutScriptPath = "C:\Users\Michal\Stuff\backup-script\misc\$(Get-Vshadow-Output-Script-Name)"
	$snapshotId = $null
	try {
		Create-Vss-Snapshot $vshadowOutScriptPath "C"
		$snapshotId = Get-Snapshot-Id $vshadowOutScriptPath
		Mount-Vss-Snapshot $snapshotId "S"
		Copy-Data -sourceDir "S:\Users\Michal\" -excludeFilePattern "\b\B" -destinationDir "D:\Backup\ze-skryptu\"
	}
	finally {
		# Remove-Item -Path $vshadowOutScriptPath
		Delete-Vss-Snapshot $snapshotId
	}
}

# creates the snapshot, snapshot ID will be at $scriptFilePath
Function Create-Vss-Snapshot {
	param([String]$scriptFilePath, [String]$driveLetter)
	If($driveLetter.length -ne 1) {
		throw "Drive letter must be a single character."
	}
	Run-Vshadow "-p -script=$scriptFilePath $($driveLetter):"
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
	$vshadowExitCode = Run-Vshadow "-el={$snapshotId},$($driveLetter):"
}

Function Run-Vshadow {
	param([String]$arguments)
	$stdoutFile = Get-Date -Format "'vshadow_stdout_'yyyy-MM-dd_HH-mm-ss-fff'.txt'"
	$stderrFile = Get-Date -Format "'vshadow_stderr_'yyyy-MM-dd_HH-mm-ss-fff'.txt'"
	$vshadowProcess = Start-Process -Wait -PassThru -FilePath $vshadowPath -ArgumentList $arguments -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
	$exitCode = $vshadowProcess.ExitCode
	echo "VShadow called with arguments '$arguments'"
	
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
	Run-Vshadow "-ds={$snapshotId}"
}

# $sourceDir and $destinationDir must either both end with '\' or both not end, TODO: implement check against this or some other solution
Function Copy-Data {
	param([String]$sourceDir, [String]$excludeFilePattern, [String]$destinationDir)
	# TODO: assert that $sourceDir is in fact a directory
	
	# included file system entries (before excluding)
	$dirInfo = [System.IO.DirectoryInfo]::new($sourceDir)
	$enumOptions = [System.IO.EnumerationOptions]::new()
	$enumOptions.RecurseSubdirectories = $true
	$enumOptions.AttributesToSkip = [System.IO.FileAttributes]::ReparsePoint
	# this function does not support regex filtering, so using "*" filter pattern and checking each entry later
	$includedFsEntries = $dirInfo.EnumerateFileSystemInfos("*", $enumOptions)
	
	# escaping for later regex operations
	$escapedSource = [Regex]::Escape($sourceDir)
	
	foreach($entry in $includedFsEntries) {
		$path = $entry.FullName
		If($path -match $excludeFilePattern) {
			continue
		}
		
		$newPath = $path -replace "^$escapedSource","$destinationDir"
		
		try {
			$newEntry = Copy-Item -Force -PassThru -Path $path -Destination $newPath -ErrorAction Stop
			
			$newEntry.Attributes = $entry.Attributes
			# security descriptors
			Set-Acl $newPath $(Get-Acl $newEntry)
			# TODO: something is wrong with last access time and last write time
			$newEntry.CreationTime = $entry.CreationTime
			$newEntry.LastWriteTime = $entry.LastWriteTime
			$newEntry.LastAccessTime = $entry.LastAccessTime
			
			#Set-ItemProperty -Path $newPath -Name CreationTime -Value $entry.CreationTime
			#Set-ItemProperty -Path $newPath -Name LastAccessTime -Value $entry.LastAccessTime
			#Set-ItemProperty -Path $newPath -Name LastWriteTime -Value $entry.LastWriteTime
			
			#echo "Copied file to $newPath."
		}
		catch {
			echo "Failed to copy file '$path' - $($_.Exception.GetType().FullName): $($_.Exception.Message)"
		}
	}
	
	# for each directory
	#foreach ($dir in $includedFsEntries | Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::Directory) -eq [System.IO.FileAttributes]::Directory }) {
	#	$path = $entry.FullName
	#	$newPath = $path -replace "^$escapedSource","$destinationDir"
	#	Set-ItemProperty -Path $newPath -Name CreationTime -Value $dir.CreationTime
	#	Set-ItemProperty -Path $newPath -Name LastAccessTime -Value $dir.LastAccessTime
	#	Set-ItemProperty -Path $newPath -Name LastWriteTime -Value $dir.LastWriteTime
	#}
}

# === invoke Main ===
$time = Measure-Command { Main | Out-Default }
echo "Execution time: $($time.TotalSeconds) seconds"
# Main
