# SVG Map Renderer
# by Dan Jackson
# Cleaned up from original PowerShell prototype
# Can accept input from AardMapLayoutEngine.ps1 JSON exports

# import our area
$jsonfilename = "NOTAREALFILE"
while ($jsonfilename -ne $null -and $jsonfilename -ne "") {
	$jsonfilename = Read-Host "JSON file from AardMapLayoutEngine (or blank to exit)"
	if ($jsonfilename -ne $null -and $jsonfilename -ne "") {
		$jsonfilename = $jsonfilename.Replace('"',"")
		if (!(Test-Path $jsonfilename)) {
			Write-Host "Invalid filename, please try again."
			continue
		}
	} else {
		exit
	}

$jsonfile = Get-Content $jsonfilename | ConvertFrom-JSON
$area = $jsonfile.areas[0]
$arearooms = $jsonfile.rooms
$arearoomexits = $jsonfile.exits

# HTML boilerplate
$outputdocument = @"
<!DOCTYPE html>
<HTML>
<HEAD>
	<TITLE>
"@

# Area title
$outputdocument += $area.name

# HTML boilerplate
$outputdocument += @"
</TITLE>
<STYLE TYPE="text/css">
"@

# CSS boilerplate
$outputdocument += @"
:root,
:root.dark {
	--color-bg: rgb(32,32,32);
	--color-fg: lightgrey;
	--link-color: lightgreen;
	--stroke-color: grey;
	--customexit-color: lightblue;
}
:root.light {
	--color-bg: #ffffff;
	--color-fg: #000000;
	--link-color: #54785b;
	--stroke-color: #000000;
	--customexit-color: blue;
}

body {
	background-color: rgb(32,32,32);
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
	font-size: 12px;
	background-color: var(--color-bg);
	color: var(--color-fg);
}
.wrapper {
	left: 6vw;
	position: absolute;
}
.svgwrapper {
	width: fit-content;
	margin: auto;
}
.normal-room {
	fill: rgb(32,32,32);
	stroke-width:2;
	stroke: grey;
}
.area-start-room {
	fill: rgb(32,32,32);
	stroke-width:4;
	stroke:rgb(0,255,0);
}
.moving-aggro-room {
	fill: rgb(32,32,32);
	stroke-width:2;
	stroke:rgb(255,0,0);
}
.stationary-aggro-room {
	fill: rgb(32,32,32);
	stroke-width:4;
	stroke:rgb(255,0,0);
}
.room-label {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
    font-size: 12px;
	text-align: center;
	color: lightgrey;
}
.room-label > p {
	vertical-align: top;
	margin: 2px auto auto auto;
}
.area-exit-label {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
    font-size: 12px;
	text-align: center;
	color: lightgrey;
	display: flex;
	align-items: center;
	width: 100%;
	height: 100%;
}
.area-exit-label > p {
	font-style: italic;
	display: flex;
	align-items: center;
	justify-content: center;
	width: 100%;
	height: 100%;
}
.custom-exit-label {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
	font-size: 10px;
	fill: var(--customexit-color); /* SVG */
	stroke: none;
}
.pk-room-label {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
	font-size: 10px;
	fill: red; /* SVG */
	stroke: none;
}
.tooltip {
	fill: cornsilk;
	stroke-width:2;
	stroke: black;
}
.tooltip-text {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
    font-size: 12px;
	color: black;
}
.tooltip-text > p {
	vertical-align: top;
	margin: 15px auto auto auto;
}
#arrowhead, #doorarrowhead, #door {
	stroke: var(--color-fg);
	fill: none;
}
svg {
	stroke: var(--color-fg);
	fill: none;
	stroke-width: 2;
}
.maplabel-centre-14pt-bold {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
    font-size: 14pt;
	font-weight: bold;
	text-align: center;
	color: lightgrey;
	display: flex;
}
.maplabel-centre-14pt-bold > p {
	vertical-align: top;
	margin: 2px auto auto auto;
}
.maplabel-centre-24pt-bold-italic {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
    font-size: 24pt;
	font-weight: bold;
	font-style: italic;
	text-align: center;
	color: lightgrey;
	display: flex;
}
.maplabel-centre-24pt-bold-italic > p {
	vertical-align: top;
	margin: 2px auto auto auto;
}
.maplabel-left-10pt-plain {
	font-family: "Tahoma", "Verdana", "Arial", "sans-serif";
    font-size: 10pt;
	color: lightgrey;
	display: flex;
}
.maplabel-left-10pt-plain > p {
	vertical-align: top;
	margin: 2px auto auto auto;
}

"@

# HTML and JavaScript boilerplate
$outputdocument += @"
</STYLE>
<SCRIPT TYPE="text/javascript">
//<![CDATA[
const onClick = (event) => {
	var targetlist = event.target.dataset.toggleTarget;
	if (targetlist.includes(" ")) {
		// multiple targets
		var targetarray = targetlist.split(" ");
		targetarray.forEach(toggleTarget);
	} else {
		// single target
		toggleTarget(event.target.dataset.toggleTarget);
	}
}

function toggleTarget(item) {
	var svgtarget = document.getElementById(item);
	if (typeof(svgtarget) != 'undefined' && svgtarget != null) {	// check that target element exists
		if (svgtarget.style.visibility === "hidden") {				// visibility is for svg
			svgtarget.style.visibility = "visible";
		} else {
			svgtarget.style.visibility = "hidden";
		}
	}
}
window.addEventListener('click', onClick);
//]]>
</SCRIPT>
</HEAD>
<BODY>
	<div class="wrapper">
	<H1>The Gaardian Map Archives<br>$($area.name)</H1>

"@

# need to calculate width and height for SVG tag
# rooms are 100px wide, 60px high
# exits are 42px long
# in database, xpos and ypos are reversed, but in this JSON format x and y aren't reversed
$maxxpos = ($arearooms | Select-Object @{Name="x";Expression={[int]$_.x}} | Measure-Object -Maximum x).Maximum
$maxypos = ($arearooms | Select-Object @{Name="y";Expression={[int]$_.y}} | Measure-Object -Maximum y).Maximum
$svgheight = (60 * ($maxypos + 2)) + (42 * ($maxypos + 3))	# spaces around it for area exits
$svgwidth  = (100 * ($maxxpos + 2)) + (42 * ($maxxpos + 3))	# spaces around it for area exits

# grid variable for occlusion detection
$gridInUse = New-Object 'bool[,]' ($maxxpos+1),($maxypos+1) # X and Y are not reversed, but they're 1-based
# initialize to false
for ($i = 0; $i -lt ($maxxpos+1); $i++) {
	for ($j = 0; $j -lt ($maxypos+1); $j++ ) {
		$gridInUse[$i,$j] = $false
	}
}
# populate
foreach ($room in $arearooms) {
	$gridInUse[[int]($room.x),[int]($room.y)] = $true
}

# digital differential analyzer!
# https://en.wikipedia.org/wiki/Digital_differential_analyzer_(graphics_algorithm)#Program
# but fixed so it can deal with the edge case where dx or dy are zero
# and where some fuckwit is trying to detect if a room is occluded by itself?
function detectOcclusion {
	Param(
		[Parameter(Mandatory=$true)]
		$startroom,
		[Parameter(Mandatory=$true)]
		$endroom,
		[Parameter(Mandatory=$true)]
		$roomexit
	)
	$x1 = [int]($startroom.x)
	$y1 = [int]($startroom.y)
	$x2 = [int]($endroom.x)
	$y2 = [int]($endroom.y)
	$direction = $roomexit.dir
	# n,e,s,w,u,d
	switch($direction) {
		"n" {
			if ($y2 -gt $y1 -or $x1 -ne $x2) {
				# trying to go not north on a north exit
				return $true
			}
		}
		"e" {
			if ($x2 -lt $x1 -or $y1 -ne $y2) {
				# trying to go not east on an east exit
				return $true
			}
		}
		"s" {
			if ($y2 -lt $y1 -or $x1 -ne $x2) {
				# trying to go not south on a south exit
				return $true
			}
		}
		"w" {
			if ($x2 -gt $x1 -or $y1 -ne $y2) {
				# trying to go not west on a west exit
				return $true
			}
		}
		"u" {
			if ($y2 -gt $y1 -or $x1 -eq $x2) {
				# trying to go down on an up exit, or directly above when it should be left or right
				return $true
			}
		}
		"d" {
			if ($y2 -lt $y1 -or $x1 -eq $x2) {
				# trying to go up on a down exit, or directly below when it should be left or right
				return $true
			}
		}
	}
	# are (x1,y1) and (x2,y2) the same?
	if ($x1 -eq $x2 -and $y1 -eq $y2) {
		# yes, return true
		return $true
	}
	$dx = $x2 - $x1
	$dy = $y2 - $y1
	if ([Math]::Abs($dx) -ge [Math]::Abs($dy)) {
		$step = [Math]::Abs($dx)
	} else {
		$step = [Math]::Abs($dy)
	}
	if ($step -gt 0) {
		$dx = $dx / $step
		$dy = $dy / $step
	} else {
		# if $step is zero there's nowhere to go?
		return $false
	}
	$x = $x1
	$y = $y1
	$i = 1
	$isOccluded = $false
	$fudge = 0.2 # fudge factor
	while ($i -le $step) {
		if ($gridInUse[[Math]::Round(($x - $fudge)),[Math]::Round(($y - $fudge))]) {
			if (!($x1 -eq [Math]::Round(($x - $fudge)) -and $y1 -eq [Math]::Round(($y - $fudge))) -and !($x2 -eq [Math]::Round(($x - $fudge)) -and $y2 -eq [Math]::Round(($y - $fudge)))) {
				$isOccluded = $true
			}
		}
		$x = $x + $dx
		$y = $y + $dy
		$i = $i + 1
	}
	
	return $isOccluded
}

function gridPosToCoordinate {
	Param(
		[Parameter(Mandatory=$true)]
		$room,
		[Parameter(Mandatory=$true)]
		[string]$position
	)
	$coordinate = [PSCustomObject]@{
		x = ([int]($room.x) * 142) + 42 # X and Y axes are not swapped for rendering purposes
		y = ([int]($room.y) * 102) + 42 # X and Y axes are not swapped for rendering purposes
	}
	# n,e,s,w,ul,ur,dl,dr
	switch($position) {
		"n" {
			$coordinate.x += 50
			break
		}
		"e" {
			$coordinate.x += 100
			$coordinate.y += 30
			break
		}
		"s" {
			$coordinate.x += 50
			$coordinate.y += 60
			break
		}
		"w" {
			$coordinate.y += 30
			break
		}
		"ul" {
			# no change needed
			break
		}
		"ur" {
			$coordinate.x += 100
			break
		}
		"dl" {
			$coordinate.y += 60
			break
		}
		"dr" {
			$coordinate.x += 100
			$coordinate.y += 60
			break
		}
	}
	return $coordinate
}

function highlightRooms {
	Param(
		[Parameter(Mandatory=$true)]
		$startroom,
		[Parameter(Mandatory=$true)]
		$endroom,
		[Parameter()]
		[string]$deferredrender
	)
	# fix types
	$startroom.uid = [int]($startroom.uid)
	$startroom.x = [int]($startroom.x)
	$startroom.y = [int]($startroom.y)
	$endroom.uid = [int]($endroom.uid)
	$endroom.x = [int]($endroom.x)
	$endroom.y = [int]($endroom.y)
	if ($deferredrender -eq $null) {
		$deferredrender = ""
	}
	# sort ids
	$sortedids = ($startroom.uid, $endroom.uid) | Sort-Object
	$idstring = "highlight-$($sortedids[0])-$($sortedids[1])"
	# did this line already get drawn?
	if ($deferredrender -notmatch $idstring) {
		# no, draw it
		# dot in bottom right corner of start room to dot in bottom right corner of end room
		$startbottomright = gridPosToCoordinate $startroom "dr"
		$endbottomright = gridPosToCoordinate $endroom "dr"
		$deferredrender += @"

<!-- Highlight line between rooms $($sortedids[0]) and $($sortedids[1]) -->
<line x1="$($startbottomright.x - 10)" y1="$($startbottomright.y - 10)" x2="$($endbottomright.x - 10)" y2="$($endbottomright.y - 10)"
stroke="orange" stroke-width="2" marker-start="url(#orangedot)" marker-end="url(#orangedot)"
id="$($idstring)" style="visibility: hidden;" />

"@	
	}
	return [PSCustomObject]@{
		idstring = $idstring
		deferredrender = $deferredrender
	}
}

# SVG tag and boilerplate
$outputdocument += @"
<div class="svgwrapper">
<svg width="$($svgwidth)" height="$($svgheight)">
  <defs>
	<marker id="arrowhead"
	  viewBox="0 0 10 10"
	  refX="10"
	  refY="5"
	  markerWidth="12"
	  markerHeight="12"
	  markerUnits="userSpaceOnUse"
	  orient="auto-start-reverse">
	  <path d="M 0 0 L 10 5 L 0 10"/>
	</marker>
	<marker id="doorarrowhead"
	  viewBox="0 0 15 10"
	  refX="15"
	  refY="5"
	  markerWidth="17"
	  markerHeight="12"
	  markerUnits="userSpaceOnUse"
	  orient="auto-start-reverse">
	  <path d="M 0 0 L 0 10 M 1 0 L 1 10 M 5 0 L 15 5 L 5 10"/>
	</marker>
	<marker id="door"
	  viewBox="0 0 10 16"
	  refX="10"
	  refY="8"
	  markerWidth="12"
	  markerHeight="18"
	  orient="auto">
	  markerUnits="userSpaceOnUse"
	  <path d="M 10 0 L 10 16"/>
	</marker>
	<marker id="orangedot"
	  markerWidth="10"
	  markerHeight="10"
	  refX="5"
	  refY="5"
	  stroke="orange"
	  fill="orange"
	  markerUnits="strokeWidth">
	  <circle cx="5" cy="5" r="4"/>
	</marker>
	<marker id="purpledot"
	  markerWidth="10"
	  markerHeight="10"
	  refX="5"
	  refY="5"
	  stroke="purple"
	  fill="purple"
	  markerUnits="strokeWidth">
	  <circle cx="5" cy="5" r="4"/>
	</marker>
  </defs>

"@

# rooms, exits and doors go here
$seencoords = @()
# sort by x coordinate then y coordinate so they get rendered in the correct order
$arearooms = $arearooms | Sort-Object {[int]($_.xpos)}, {[int]($_.ypos)}
# deferred rendering
$deferredrender = ""
# iterate through rooms
foreach ($room in $arearooms) {
	# fix types
	$room.uid = [int]($room.uid)
	$room.x = [int]($room.x)
	$room.y = [int]($room.y)
	$checkseen = $null
	$checkseen = $seencoords | Where-Object {$_[0] -eq $room.x -and $_[1] -eq $room.y}
	if ($checkseen -ne $null -or $room.x -eq 0 -or $room.y -eq 0) {
		$outputdocument += @"
<!-- Already seen coordinates - room $($room.uid) name: '$($room.name)', Coordinates: $($room.x) , $($room.y) -->

"@
		continue
	}
	$seencoords += ($room.x, $room.y)
	$topleft = gridPosToCoordinate $room "ul"
	$bottomleft = gridPosToCoordinate $room "dl"
	$outputdocument += @"

<!-- Room $($room.uid) name: '$($room.name)', Coordinates: $($room.x) , $($room.y) -->

"@
	# rectangle start
	$outputdocument += @"
<rect x="$($topleft.x)" y="$($topleft.y)" width="100" height="60"
"@
	# give it an ID
	$outputdocument += " id=`"map-room-id-$($room.uid.ToString())`""
	# roomtype affects border
	$roomtype = "normal-room"
	# add the CSS class
	$outputdocument += " class=`"$($roomtype)`" />`r`n"
	# rectangle end
	# room label start
	# let's try foreignObject
	$outputdocument += @"
<foreignObject x="$($topleft.x + 2)" y="$($topleft.y + 2)" width="96" height="56" id="map-roomlabel-id-$($room.uid.ToString())">
<div class="room-label">
<p>$($room.name)<br /><small>$($room.uid) - $($room.x),$($room.y)</small>
</p>
</div>
</foreignObject>

"@
	# room label end
	# does the room have custom exits? we need to know as we need to move the PK label up
	$customexits = $arearoomexits | Where-Object {[int]($_.fromuid) -eq $room.uid -and ("n","e","s","w","u","d") -notcontains $_.dir}

	# pk label start
	if ($room.pk -gt 0) {
		$x = $bottomleft.x + 5
		$y = $bottomleft.y - 5
		if ($customexits -ne $null) {
			$y = $y - 10
		}
		$outputdocument += @"
<text x="$($x)" y="$($y)" text-anchor="start" class="pk-room-label">PK</text>

"@
	}
	# pk label end
	
	# room exits start
	$thisroomexits = $null
	$thisroomexits = $arearoomexits | Where-Object {[int]($_.fromuid) -eq $room.uid} | Sort-Object dir
	# iterate through room exits
	$firstmulticustomexit = $true
	$wasmulticustomexits = $false
	$multicustomtooltipid = ""
	$multicustomtooltip = ""
	foreach ($roomexit in $thisroomexits) {
		# fix types
		$roomexit.fromuid = [int]($roomexit.fromuid)
		$roomexit.touid = [int]($roomexit.touid)
		# figure out where the exit goes
		$targetroom = $null
		$areaexit = $false
		if ($arearooms.uid -notcontains $roomexit.touid) {
			$areaexit = $true
		}
		# is it an area exit? as if so, the targetroomid will be an areaid
		if ($areaexit) {
			# it is an area exit
			# is it a custom exit?
			if (("n","e","s","w","u","d") -notcontains $roomexit.dir) {
				# yes, skip
				continue
			}
			$targetroom = $room.PsObject.Copy() # we need a copy of the object, not the object itself!
			# fix types
			$targetroom.uid = [int]($targetroom.uid)
			$targetroom.x = [int]($targetroom.x)
			$targetroom.y = [int]($targetroom.y)
			# synthesize area exit room
			$targetroom.uid = -9999
			$targetroom.name = "Synthetic room for area exit"
			switch($roomexit.dir) {
				"n" { $targetroom.y = $targetroom.y - 1; break }
				"e" { $targetroom.x = $targetroom.x + 1; break }
				"s" { $targetroom.y = $targetroom.y + 1; break }
				"w" { $targetroom.x = $targetroom.x - 1; break }
				"u" { $targetroom.y = $targetroom.y - 1; $targetroom.x = $targetroom.x + 1; break }
				"d" { $targetroom.y = $targetroom.y + 1; $targetroom.x = $targetroom.x - 1; break }
			}
		} else {
			# it is not an area exit
			$targetroom = $arearooms | Where-Object {[int]($_.uid) -eq $roomexit.touid}
		}
		# assert that we know where the exit goes now
		$position = ""
		if ($targetroom -eq $null) {
			$outputdocument += @"
<!-- Room exit: $($roomexit.fromuid) direction $($roomexit.dir) - could not find destination room $($roomexit.touid)! -->

"@
			continue
		} else {
			# fix types
			$targetroom.uid = [int]($targetroom.uid)
			$targetroom.x = [int]($targetroom.x)
			$targetroom.y = [int]($targetroom.y)
			# determine exit position
			switch($roomexit.dir) {
				"n" { $position = "n"; break }
				"e" { $position = "e"; break }
				"s" { $position = "s"; break }
				"w" { $position = "w"; break }
				"u" {
					if ($targetroom.ypos -lt $room.ypos) {
						$position = "ul"
					} else {
						$position = "ur"
					}
					break
				}
				"d" {
					if ($targetroom.ypos -gt $room.ypos) {
						$position = "dr"
					} else {
						$position = "dl"
					}
					break
				}
				default { $position = $roomexit.dir; break }
			}
			$outputdocument += @"
<!-- Room exit: $($roomexit.fromid) exit '$($position)' leads to room $($targetroom.uid) at $($targetroom.x) , $($targetroom.y) - '$($targetroom.name)' -->

"@
		}
		$targetposition = ""
		switch($position) {
			"n"		{ $targetposition = "s"; break }
			"e"		{ $targetposition = "w"; break }
			"s"		{ $targetposition = "n"; break }
			"w"		{ $targetposition = "e"; break }
			"ul"	{ $targetposition = "dr"; break }
			"ur"	{ $targetposition = "dl"; break }
			"dl"	{ $targetposition = "ur"; break }
			"dr"	{ $targetposition = "ul"; break }
		}
		# deal with custom exits first so other exit types can be dealt with generically
		if (("n","e","s","w","u","d") -notcontains $roomexit.dir) {
			# insert orange highlight line deferred render
			$toggletarget = ""
			if ($targetroom -ne $null) {
				$highlightlink = highlightRooms $room $targetroom $deferredrender
				$deferredrender = $highlightlink.deferredrender
				$toggletarget = $highlightlink.idstring
			}
			# render custom exit
			$exitaction = ""
			$exitaction = $roomexit.dir
			if ($customexits.Count -gt 1 -or $exitaction.Length -gt 19) {
				if ($firstmulticustomexit) {
					$firstmulticustomexit = $false
					# calculate our coordinates and id strings beforehand
					$textx = $bottomleft.x + 5
					$texty = $bottomleft.y - 5
					$seemoreid = "map-room-seemore-id-$($room.uid)"
					$multicustomtooltipid = "map-room-seemore-tooltip-id-$($room.uid)"
					$rectx = $topleft.x - 18
					$recty = $topleft.y + 45
					$circley = $recty + 8
					$circlex1 = $rectx + 3
					$circlex2 = $rectx + 8
					$circlex3 = $rectx + 13
					$outputdocument += @"
			<g id="$($seemoreid)">
			<rect x="$($rectx)" y="$($recty)" width="16" height="16" style="stroke: rgb(32,32,32); fill: rgb(32,32,32); opacity: 0.0;" data-toggle-target="$($multicustomtooltipid) $($multicustomtooltipid)-text" onclick="" />
			<circle cx="$($circlex1)" cy="$($circley)" r="1" fill="currentColor" data-toggle-target="$($multicustomtooltipid) $($multicustomtooltipid)-text" onclick="" />
			<circle cx="$($circlex2)" cy="$($circley)" r="1" fill="currentColor" data-toggle-target="$($multicustomtooltipid) $($multicustomtooltipid)-text" onclick="" />
			<circle cx="$($circlex3)" cy="$($circley)" r="1" fill="currentColor" data-toggle-target="$($multicustomtooltipid) $($multicustomtooltipid)-text" onclick="" />
			</g>
			<text x="$($textx)" y="$($texty)" text-anchor="start" class="custom-exit-label">see more</text>
"@
					$rectx = $rectx
					$recty = $topleft.y - 136
					$forobjx = $rectx + 15
					$forobjy = $recty + 2
					$multicustomexitstooltip = @"
	<rect x="$($rectx)" y="$($recty)" width="400" height="150" rx="15" class="tooltip" style="visibility: hidden;" id="$($multicustomtooltipid)" />
	<foreignObject x="$($forobjx)" y="$($forobjy)" width="370" height="146" class="tooltip-text" style="visibility: hidden;" id="$($multicustomtooltipid)-text">
	<div>
	<p>Custom exits for <b>$($room.roomname)</b>:</p>
	<p><ul style="list-style: none; padding: 0px;">
"@
				}
				$imageid = "map-roomexit-id-$($roomexit.touid)"
				$multicustomexitstooltip += @"
			<li><img src="link.png" width="16" height="16" id="$($imageid)" data-toggle-target="$($toggletarget)" onclick="" style="vertical-align: middle;" />&nbsp;
			$($exitaction)</li>
"@
				$wasmulticustomexits = $true;
			} else {
				$outputdocument += @"
<text x="$($bottomleft.x + 5)" y="$($bottomleft.y - 5)" text-anchor="start" class="custom-exit-label">$($exitaction)</text>
<image x="$($topleft.x - 18)" y="$($topleft.y + 45)" width="16" height="16" href="link.png" id="map-roomexit-id-$($roomexit.touid.ToString())" data-toggle-target="$($toggletarget)" />

"@
			}
			# we don't need to do anything else with this exit type so continue
			continue
		}
		# draw an exit
		$startpoint = $null
		$startpoint = gridPosToCoordinate $room $position
		$endpoint = $null
		$endpoint = gridPosToCoordinate $targetroom $targetposition
		switch($position) {
			"n"		{ $xdirection = 0; $ydirection = -1;	break }
			"e"		{ $xdirection = 1; $ydirection = 0;		break }
			"s"		{ $xdirection = 0; $ydirection = 1;		break }
			"w"		{ $xdirection = -1; $ydirection = 0;	break }
			"ul"	{ $xdirection = -1; $ydirection = -1;	break }
			"ur"	{ $xdirection = 1; $ydirection = -1;	break }
			"dl"	{ $xdirection = -1; $ydirection = 1;	break }
			"dr"	{ $xdirection = 1; $ydirection = 1;		break }
		}
		# assume not a one way exit until we know otherwise
		$onewayexit = $false
		# is it disconnected?
		$isdisconnected = detectOcclusion $room $targetroom $roomexit
		if ($isdisconnected -or $areaexit) {
			# yes, move endpoint back
			if ($areaexit) {
				# area exits need to be handled differently
				$endpoint.x = $startpoint.x + (42 * $xdirection)
				$endpoint.y = $startpoint.y + (42 * $ydirection)
			} else {
				$endpoint.x = $startpoint.x + (21 * $xdirection)
				$endpoint.y = $startpoint.y + (21 * $ydirection)
				# is there a custom exit on this room?
				$customexits = $arearoomexits | Where-Object {$_.uid -eq $roomexit.fromuid -and ("n","e","s","w","u","d") -notcontains $_.dir}
				if ($roomexit.dir -ne "w" -or $customexits -eq $null) {
					# offset nesw exits (but don't offset w exits if there's a custom exit)
					if ($xdirection -eq 0) {
						$startpoint.x += (30 * $ydirection)
						$endpoint.x += (30 * $ydirection)
					} elseif ($ydirection -eq 0) {
						$startpoint.y += (-20 * $xdirection)
						$endpoint.y += (-20 * $xdirection)
					}
				}
			}
		} else {
			# it's not disconnected or an area exit
			# is it a one way exit?
			$oppositeexittype = ""
			switch($roomexit.dir) {
				"n" { $oppositeexittype = "s"; break }
				"e" { $oppositeexittype = "w"; break }
				"s" { $oppositeexittype = "n"; break }
				"w" { $oppositeexittype = "e"; break }
				"u" { $oppositeexittype = "d"; break }
				"d" { $oppositeexittype = "u"; break }
				default { $oppositeexittype = "" }
			}
			# we need to know if the target room has an exit of the opposite type that leads back to this room
			$targetroomexits = $arearoomexits | Where-Object {$_.fromuid -eq $roomexit.touid -and $_.touid -eq $roomexit.fromuid -and $_.dir -eq $oppositeexittype}
			if ($targetroomexits -ne $null) {
				$onewayexit = $false
			} else {
				$onewayexit = $true
			}
			if (!$onewayexit) {
				# not a one way exit
				$endpoint.x = $endpoint.x - (($endpoint.x - $startpoint.x) / 2)
				$endpoint.y = $endpoint.y - (($endpoint.y - $startpoint.y) / 2)
			}
		}
		if ($isdisconnected) {
			# if it's disconnected it needs an arrowhead
			# does it have a door as well? - JSON format doesn't capture doors
			$outputdocument += @"
<line x1="$($startpoint.x)" y1="$($startpoint.y)" x2="$($endpoint.x)" y2="$($endpoint.y)" stroke="grey" marker-end="url(#arrowhead)" />

"@
			# it also needs a link
			# insert orange highlight line deferred render
			$toggletarget = ""
			if ($targetroom -ne $null) {
				$highlightlink = highlightRooms $room $targetroom $deferredrender
				$deferredrender = $highlightlink.deferredrender
				$toggletarget = $highlightlink.idstring
			}
			# render link
			$endpoint.x = $endpoint.x - 8 + (8 * $xdirection)
			$endpoint.y = $endpoint.y - 8 + (8 * $ydirection)
			$outputdocument += @"
<image x="$($endpoint.x)" y="$($endpoint.y)" width="16" height="16" href="link.png" data-toggle-target="$($toggletarget)" />

"@
			
		} else {
			# not disconnected
			# is it one way?
			if ($onewayexit) {
				# yes
				# no door
				$outputdocument += @"
<line x1="$($startpoint.x)" y1="$($startpoint.y)" x2="$($endpoint.x)" y2="$($endpoint.y)" marker-end="url(#arrowhead)" />
"@
			} else {
				$outputdocument += @"
<line x1="$($startpoint.x)" y1="$($startpoint.y)" x2="$($endpoint.x)" y2="$($endpoint.y)" stroke="grey" />

"@
			}
		}
		# is it an area exit?
		if ($areaexit) {
			# yes, draw a label for the area
			# foreignObject with label "To <targetareaname>"
			$label = $null
			$label = gridPosToCoordinate $targetroom "ul"
			$outputdocument += @"
<foreignObject x="$($label.x + 2)" y="$($label.y + 2)" width="96" height="56" id="map-areaexit-id-$($roomexit.touid.ToString())">
<div class="area-exit-label">
<p>Area Exit</p>
</div>
</foreignObject>

"@
			# we don't need to do anything else for area exits, so continue
			continue
		}
		# does it have a locked door? (doortype 2) - JSON format has no doors, skip
	} # room exits loop ends
	if ($wasmulticustomexits) {
		# need to end multi custom exits tooltip and add it to deferred rendering
		$multicustomexitstooltip += @"
	</ul>
	</p>
	</div>
	</foreignObject>
"@
		$deferredrender += $multicustomexitstooltip;
	}
} # rooms loop ends

# add deferred rendering items
if ($deferredrender -ne "") {
	$outputdocument += $deferredrender
}

# close SVG tag
$outputdocument += @"
</svg>
</div>
</div>
"@

# close body and document
$outputdocument += @"
</BODY>
</HTML>
"@

# write to file
$outputdocument | Set-Content "$(Split-Path $jsonfilename)\$($area.name).html" -Encoding UTF8

}