# Usage: pixur [file(s)] [options]
# Summary: A PowerShell script to print full-color pictures in the terminal.
# Help: Print full-color RGB pictures in the terminal. Supports PNG, JPEG, and BMP formats.

param (
	[parameter(mandatory=$true,valuefrompipeline=$true)]
	$path,
	[alias('i')]
	[switch]$invert,
	[alias('h')]
	[switch]$help
)

############################################################ 

function usage($text) {
    $text | Select-String '(?m)^# Usage: ([^\n]*)$' | ForEach-Object { "Usage: " + $_.matches[0].groups[1].value }
}

function summary($text) {
    $text | Select-String '(?m)^# Summary: ([^\n]*)$' | ForEach-Object { $_.matches[0].groups[1].value }
}

function help_msg($text) {
    $help_lines = $text | Select-String '(?ms)^# Help:(.(?!^[^#]))*' | ForEach-Object { $_.matches[0].value; }
    $help_lines -replace '(?ms)^#\s?(Help: )?', ''
}

if ($help) {
	try {
		$text = (Get-Content $MyInvocation.PSCommandPath -raw)
	} catch {
		$text = (Get-Content $PSCOMMANDPATH -raw) 
	}
	$helpmsg = usage $text 
	$helpmsg += "`n"
	$helpmsg += summary $text 
	$helpmsg += "`n"
	$helpmsg += help_msg $text 
	$helpmsg
	break
}

#####################################################################

$E = [char]0x1B
$COLUMNS = $host.UI.RawUI.WindowSize.Width
$CURR_ROW = ""
$OUTPUT = ""
$CHAR = [text.encoding]::utf8.getstring((226,150,128)) # 226,150,136
[string[]]$global:upper = @()
[string[]]$global:lower = @()

foreach ($item in $path) {			
	[array]$pixels = (magick convert -thumbnail "${COLUMNS}x" -define txt:compliance=SVG $item txt:- ).Split("`n")

	foreach ($pixel in $pixels) {
		$coord = ((([regex]::match($pixel, "([0-9])+,([0-9])+:")).Value).TrimEnd(":")).Split(",")
		[int]$global:col = $coord[0]
		[int]$global:row = $coord[1]
		$rgba = ([regex]::match($pixel, "\(([0-9])+,([0-9])+,([0-9])+,([0-9])+\)")).Value
#write-host "rgba: $rgba"
		$rgba = (($rgba.TrimStart("(")).TrimEnd(")")).Split(",")
#write-host "rgba joined: $($rgba -join ' : ')"
		$r = $rgba[0]
		$g = $rgba[1]
		$b = $rgba[2]
#write "red: $r green: $g blue: $b" 
		if (($row % 2) -eq 0) {
			$upper += "${r};${g};${b}"
		} else {
			$lower += "${r};${g};${b}"
		}

		if (($row%2) -eq 1 -and ($col -eq ($COLUMNS-1))) {
			$i = 0
			while ($i -lt $COLUMNS) {
				$CURR_ROW += "${E}[38;2;$($upper[$i]);48;2;$($lower[$i])m${CHAR}"
				$i++
			}
			$OUTPUT += "${CURR_ROW}${E}[0m${E}[B${E}[0G`n"
			$CURR_ROW = ""
			$upper = @()
			$lower = @()
		}
	}

	write $OUTPUT
	$OUTPUT = ""
}
