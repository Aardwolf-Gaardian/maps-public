# Aardwolf Map Layout Engine
# by Danj
# Lays out map data gathered by the MUSHclient GMCP mapper to an (x,y) grid, plus various other utility functions
# v1.0	2023-03-25	Initial version

# Contents:
# Requirements checking at line 14
# Startup processes at line 65
# Class definitions at line 251
# Comnmand help at line 513
# Breadth-first search algorithm at line 555
# Command parser at line 725

#Requires -Version 5.1

# Check required .NET version (4.6 or later)
if ($PSVersionTable.PSVersion -match '5.1') {
    $ReleaseKey = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' | Get-ItemPropertyValue -Name Release
    if ($ReleaseKey -lt 393295)
    {
		Clear-Host
		Write-Host -ForegroundColor "Red" "You must be running .NET Framework version 4.6 or later."
		Write-Host "Please download and install the latest .NET Framework version from:"
		Write-Host "https://dotnet.microsoft.com/en-us/download/dotnet-framework"
		Write-Host ""
		Write-Host "Press any key to exit..."
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
		exit 1
    }   
}

# Check required Visual Studio 2015 runtime
try {
	$VCRedistKey = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\' -ErrorAction Stop | Get-ItemPropertyValue -Name Installed
} catch {
	$VCRedistKey = 0
}
if ($VCRedistKey -ne 1) {
	Clear-Host
	Write-Host -ForegroundColor "Red" "The Visual C++ 2015 Redistributable is not installed."
	Write-Host "Please download and install the latest 64-bit VC++ Redist from:"
	Write-Host "https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist"
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}

# Check required System.Data.SQLite binaries
if (!(Test-Path "$($PSScriptRoot)\SQLite.Interop.dll") -or !(Test-Path "$($PSScriptRoot)\System.Data.SQLite.dll")) {
	Clear-Host
	Write-Host -ForegroundColor "Red" "The System.Data.SQLite libraries are missing."
	Write-Host "Please download the latest 64-bit .NET Framework 4.6 compatible version from:"
	Write-Host "https://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki"
	Write-Host "then extract SQLite.Interop.dll and System.Data.SQLite.dll to:"
	Write-Host "$($PSScriptRoot)"
	Write-Host ""
	Write-Host "NOTE: please check to make sure you do NOT choose the 'mixed-mode' or 'statically linked' versions when downloading."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}

# "Greetings, programs!"
# Title
$AMLEBanner = @"
Aardwolf Map Layout Engine
==========================

"@
Clear-Host
$AMLEBanner
$Host.UI.RawUI.WindowTitle = "Aardwolf Map Layout Engine"

# Load SQLite library
Write-Host -NoNewLine "Loading SQLite library..."
try {
	Add-Type -Path "$($PSScriptRoot)\System.Data.SQLite.dll"
} catch {
	Write-Host -ForegroundColor "Red" "ERROR"
	Write-Host -ForegroundColor "Red" "The System.Data.SQLite library could not be loaded."
	Write-Host "Unable to continue."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}
Write-Host -ForegroundColor "Green" "OK"

# Try to locate user's MUSHclient installation
$MUSHclientPath = "$($env:LocalAppData)\MUSHclient"
if (!(Test-Path $MUSHclientPath)) {
	Write-Host -ForegroundColor "Red" "Couldn't automatically locate your MUSHclient folder."
	Write-Host "At the prompt, please input the full path to the folder where MUSHclient is installed."
	Write-Host "If you prefer, you can drag and drop the MUSHclient folder onto this window and then press Enter."
	Write-Host ""
	$MUSHclientPath = Read-Host -Prompt "MUSHclient folder path"
	# Remove quotes - these get added in the case of drag and drop
	$MUSHclientPath = $MUSHclientPath.Replace('"',"")
	# Check the input was correct
	if (!(Test-Path $MUSHclientPath)) {
		Write-Host -ForegroundColor "Red" "The inputted folder does not exist or cannot be accessed."
		Write-Host "Unable to continue."
		Write-Host ""
		Write-Host "Press any key to exit..."
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
		exit 1
	}
}
Write-Host -NoNewLine "Locating MUSHclient folder..."
Write-Host -ForegroundColor "Green" "OK"

# Try to locate Aardwolf.db SQLite database within MUSHclient folder
$AardwolfDBPath = "$($MUSHclientPath)\Aardwolf.db"
if (!(Test-Path $AardwolfDBPath)) {
	Write-Host -ForegroundColor "Red" "Couldn't locate your Aardwolf.db SQLite database file."
	Write-Host "Unable to continue."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}
Write-Host -NoNewLine "Locating Aardwolf.db..."
Write-Host -ForegroundColor "Green" "OK"

# Connect to Aardwolf.db as read only
Write-Host -NoNewLine "Connecting to Aardwolf.db as read only..."
$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
$con.ConnectionString = "Data Source=$($AardwolfDBPath);Read Only=true"
try {
	$con.Open()
} catch {
	Write-Host -ForegroundColor "Red" "ERROR"
	Write-Host -ForegroundColor "Red" "Couldn't connect to your Aardwolf.db SQLite database."
	Write-Host "Unable to continue."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}
Write-Host -ForegroundColor "Green" "OK"

# Read areas table
Write-Host -NoNewLine "Reading areas table..."
$sql = $con.CreateCommand()
$sql.CommandText = "SELECT * FROM areas ORDER BY name"
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
try {
	[void]$adapter.Fill($data)
	$areas = $data.tables.rows
} catch {
	Write-Host -ForegroundColor "Red" "ERROR"
	Write-Host -ForegroundColor "Red" "Couldn't read the areas table."
	Write-Host "Unable to continue."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}
$sql.Dispose()
Write-Host -ForegroundColor "Green" "OK"

# Read rooms table
Write-Host -NoNewLine "Reading rooms table..."
$sql = $con.CreateCommand()
# Sort by area then uid, making sure numeric uids are sorted numerically and alphanumeric uids go at the bottom
$sql.CommandText = @"
SELECT * FROM rooms
ORDER BY area,
	CASE uid
		WHEN CAST(uid AS INTEGER) THEN CAST(uid AS INTEGER)
		ELSE 999999
	END
"@
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
try {
	[void]$adapter.Fill($data)
	$rooms = $data.tables.rows
} catch {
	Write-Host -ForegroundColor "Red" "ERROR"
	Write-Host -ForegroundColor "Red" "Couldn't read the rooms table."
	Write-Host "Unable to continue."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}
$sql.Dispose()
Write-Host -ForegroundColor "Green" "OK"

# Read exits table
Write-Host -NoNewLine "Reading exits table..."
$sql = $con.CreateCommand()
# Sort by fromuid then direction, making sure numeric uids are sorted numerically and alphanumeric uids go at the bottom
# and that directions are sorted in n,e,s,w,u,d,custom order
$sql.CommandText = @"
SELECT fromuid,dir,touid FROM exits
WHERE fromuid IN (
	SELECT uid FROM rooms
)
AND touid IN (
	SELECT uid FROM rooms
)
ORDER BY
	CASE fromuid
		WHEN CAST(fromuid AS INTEGER) THEN CAST(fromuid AS INTEGER)
		ELSE 999999
	END,
	CASE dir
		WHEN "n" THEN 0
		WHEN "e" THEN 1
		WHEN "s" THEN 2
		WHEN "w" THEN 3
		WHEN "u" THEN 4
		WHEN "d" THEN 5
		ELSE 6
	END
"@
$adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
$data = New-Object System.Data.DataSet
try {
	[void]$adapter.Fill($data)
	$exits = $data.tables.rows
} catch {
	Write-Host -ForegroundColor "Red" "ERROR"
	Write-Host -ForegroundColor "Red" "Couldn't read the exits table."
	Write-Host "Unable to continue."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}
$sql.Dispose()
Write-Host -ForegroundColor "Green" "OK"

# Report status
Write-Host -ForegroundColor "Cyan" "Loaded $($areas.Count) areas, $($rooms.Count) rooms and $($exits.Count) exits."

# Disconnect from database
Write-Host -NoNewLine "Closing database connection..."
try {
	$con.Close()
} catch {
	Write-Host -ForegroundColor "Red" "ERROR"
	Write-Host -ForegroundColor "Red" "Couldn't close the database connection."
	Write-Host "Unable to continue."
	Write-Host ""
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 1
}
Write-Host -ForegroundColor "Green" "OK"

# "The Grid. A digital frontier. I tried to picture clusters of information as they moved through the computer.
# What did they look like? Ships? Motorcycles? Were the circuits like freeways?
# I kept dreaming of a world I thought I'd never see. And then, one day... I got in."
class AardMapGridPosition {
	[int]$x
	[int]$y
	
	# class constructors
	AardMapGridPosition (
		[int]$x,
		[int]$y
	) {
		# check the values are not negative
		if ($x -lt 0 -or $y -lt 0) {
			# they are negative
			throw "Grid position coordinates must be nonnegative integers."
		}
		$this.x = $x
		$this.y = $y
	}
	AardMapGridPosition () {
		$this.x = 0
		$this.y = 0
	}
}
class AardMapGridRegion {
	[AardMapGridPosition]$topLeft
	[AardMapGridPosition]$bottomRight
	
	# class constructors
	AardMapGridRegion (
		[int]$x1,
		[int]$y1,
		[int]$x2,
		[int]$y2
	) {
		# check the values are not negative
		if ($x1 -lt 0 -or $y1 -lt 0 -or $x2 -lt 0 -or $y2 -lt 0) {
			# they are negative
			throw "Grid position coordinates must be nonnegative integers."
		}
		$this.topLeft.x = [Math]::min($x1, $x2)
		$this.topLeft.y = [Math]::min($y1, $y2)
		$this.bottomRight.x = [Math]::max($x2, $x1)
		$this.bottomRight.y = [Math]::max($y2, $y1)
	}
	AardMapGridRegion () {
		$this.topLeft = [AardMapGridPosition]::New()
		$this.bottomRight = [AardMapGridPosition]::New()
	}
}
class AardMapGrid {
	[int[,]] hidden $GridToUid
	[System.Collections.HashTable] hidden $UidToGrid
	[int]$GridXSize
	[int]$GridYSize
	
	# class constructor
	AardMapGrid (
		[int]$xsize,
		[int]$ysize
	) {
		$this.GridToUid = New-Object 'int[,]' $xsize,$ysize
		$this.GridXSize = $xsize
		$this.GridYSize = $ysize
		$this.UidToGrid = @{}
		# fill grid with zeroes
		for ($i = 0;$i -lt $xsize;$i++) {
			for ($j = 0;$j -lt $ysize;$j++) {
				$this.GridToUid[$i,$j] = 0
			}
		}
	}
	
	# methods
	[void] Add([int]$uid, [AardMapGridPosition]$pos) {
		# check if the uid has already been added to the grid
		if ($this.UidToGrid[$uid] -ne $null) {
			# it has, throw an exception
			throw "uid $($uid) has already been added."
		}
		# check if the grid location is occupied
		if ($this.GridToUid[$pos.x,$pos.y] -ne 0) {
			# it is, throw an exception
			throw "Grid position ($($pos.x),$($pos.y)) is already occupied by uid $($this.GridToUid[$pos.x,$pos.y])."
		}
		# check the uid is a positive nonzero integer
		if ($uid -le 0) {
			# it isn't, throw an exception
			throw "uid must be a positive nonzero integer."
		}
		# check the position coordinates are nonnegative integers and less than the grid dimensions
		if ($pos.x -lt 0 -or $pos.x -ge $this.GridXSize -or $pos.y -lt 0 -or $pos.y -ge $this.GridYSize) {
			# they aren't, throw an exception
			throw "Grid position must be between (0,0) and ($($this.GridXSize - 1),$($this.GridYSize - 1)) inclusive."
		}
		# add it to the grid
		$this.UidToGrid.Add($uid, $pos)
		$this.GridToUid[$pos.x,$pos.y] = $uid
	}
	[void] Move([int]$uid, [AardMapGridPosition]$destination) {
		# check if the uid is on the grid
		if ($this.UidToGrid[$uid] -eq $null) {
			# it isn't, throw an exception
			throw "uid $($uid) is not on the grid."
		}
		# check if the destination coordinates are valid
		if ($destination.x -lt 0 -or $destination.x -ge $this.GridXSize -or $destination.y -lt 0 -or $destination.y -ge $this.GridYSize) {
			# they aren't, throw an exception
			throw "Grid position must be between (0,0) and ($($this.GridXSize - 1),$($this.GridYSize - 1)) inclusive."
		}
		# check the destination coordinates are not occupied
		if ($this.GridToUid[$destination.x,$destination.y] -ne 0) {
			# they are, throw an exception
			throw "Grid position ($($destination.x),$($destination.y)) is already occupied by uid $($this.GridToUid[$destination.x,$destination.y])."
		}
		# get source location
		$source = $this.UidToGrid[$uid]
		# set new location
		$this.UidToGrid[$uid] = $destination
		$this.GridToUid[$destination.x,$destination.y] = $uid
		# empty old location
		$this.GridToUid[$source.x,$source.y] = 0
	}
	[void] Swap([int]$uidOne, [int]$uidTwo) {
		# check if both uids are on the grid
		if ($this.UidToGrid[$uidOne] -eq $null -or $this.UidToGrid[$uidTwo] -eq $null) {
			# they aren't, throw an exception
			throw "Both uids $($uidOne) and $($uidTwo) must be on the grid when performing a swap."
		}
		# get first location
		$firstLocation = $this.UidToGrid[$uidOne]
		# get second location
		$secondLocation = $this.UidToGrid[$uidTwo]
		# swap them around
		$this.UidToGrid[$uidOne] = $secondLocation
		$this.GridToUid[$secondLocation.x,$secondLocation.y] = $uidOne
		$this.UidToGrid[$uidTwo] = $firstLocation
		$this.GridToUid[$firstLocation.x,$firstLocation.y] = $uidTwo
	}
	[bool] isOccupied([AardMapGridPosition]$pos) {
		# check if the coordinates are valid
		if ($pos.x -lt 0 -or $pos.x -ge $this.GridXSize -or $pos.y -lt 0 -or $pos.y -ge $this.GridYSize) {
			# they aren't, throw an exception
			throw "Grid position must be between (0,0) and ($($this.GridXSize - 1),$($this.GridYSize - 1)) inclusive."
		}
		# return value
		return ($this.GridToUid[$pos.x,$pos.y] -ne 0)
	}
	[int] getMinMax([string]$mode, [string]$axis) {
		# check if the arguments are valid
		if ($mode -ne "min" -and $mode -ne "max" -and $axis -ne "x" -and $axis -ne "y") {
			# they aren't, throw an exception
			throw "getMinMax mode must be 'min' or 'max' and axis must be 'x' or 'y'."
		}
		$minx = 50
		$miny = 50
		$maxx = 50
		$maxy = 50
		for ($i = 0;$i -lt $this.GridXSize;$i++) {
			for ($j = 0;$j -lt $this.GridYSize;$j++) {
				if ($this.GridToUid[$i,$j] -ne 0) {
					if ($minx -gt $i) {
						$minx = $i
					}
					if ($miny -gt $j) {
						$miny = $j
					}
					if ($maxx -lt $i) {
						$maxx = $i
					}
					if ($maxy -lt $j) {
						$maxy = $j
					}
				}
			}
		}
		$returnvalue = 0
		switch ($mode) {
			"min" {
				switch ($axis) {
					"x" { $returnvalue = $minx; break }
					"y" { $returnvalue = $miny; break }
				}
				break
			}
			"max" {
				switch ($axis) {
					"x" { $returnvalue = $maxx; break }
					"y" { $returnvalue = $maxy; break }
				}
				break
			}
		}
		return $returnvalue
	}
	[bool] isPositioned([int]$uid) {
		if ($this.UidToGrid[$uid] -ne $null) {
			return $true
		} else {
			return $false
		}
	}
}
class AardMapUidHelper {
	[System.Collections.HashTable] hidden $UidToInt
	[System.Collections.HashTable] hidden $IntToUid
	[int] hidden $NextIntValue
	
	# class constructor
	AardMapUidHelper () {
		$this.UidToInt = [hashtable]::new() # because alphanumeric uids are case sensitive!
		$this.IntToUid = @{}
		$this.NextIntValue = 100000
	}
	
	# methods
	[void] Add([string]$alphaNumericUid) {
		# is it already on our list?
		if ($this.UidToInt[$alphaNumericUid] -ne $null) {
			# it is, throw an exception
			throw "uid '$($alphaNumericUid)' already mapped to integer $($this.UidToInt[$alphaNumericUid])."
		}
		$uid = 0
		# is it already an int?
		if (($alphaNumericUid -as [int]) -eq $null) {
			# no
			$uid = $this.NextIntValue
			$this.NextIntValue++
		} else {
			# yes
			$uid = ($alphaNumericUid -as [int])
		}
		# add it
		$this.UidToInt[$alphaNumericUid] = $uid
		$this.IntToUid.Add($uid, $alphaNumericUid)
	}
	[int] LookupUidAlpha([string]$alphaNumericUid) {
		# is it in our list?
		if ($this.UidToInt[$alphaNumericUid] -eq $null) {
			# it isn't, throw an exception
			throw "uid '$($alphaNumericUid)' not found. Did you add it?"
		}
		# return value
		return $this.UidToInt[$alphaNumericUid]
	}
	[string] LookupUidInt([int]$uid) {
		# is it in our list?
		if ($this.IntToUid[$uid] -eq $null) {
			# it isn't, throw an exception
			throw "Integer uid $($uid) not found."
		}
		# return value
		return $this.IntToUid[$uid]
	}
}

$unsavedChanges = $false
$areaSelected = $false
$areaLayout = $false
$selectedArea = ""
$selectedRegion = [AardMapGridRegion]::new()
$roomuids = [AardMapUidHelper]::new()
# set up roomuids
foreach ($room in $rooms) {
	$roomuids.Add($room.uid)
}
$grid = [AardMapGrid]::new(200,200)
$positionedRooms = @()
$helpArray = @()
$helpArray += [PSCustomObject]@{
	Command = "help"
	Description = "This command help table."
}
$helpArray += [PSCustomObject]@{
	Command = "exit"
	Description = "Exits the Aardwolf Map Layout Engine."
}
$helpArray += [PSCustomObject]@{
	Command = "list areas"
	Description = "Lists the names and uids of all the areas mapped by your MUSHclient mapper."
}
$helpArray += [PSCustomObject]@{
	Command = "select area <uid>"
	Description = "Selects the area identified by uid <uid>."
}
$helpArray += [PSCustomObject]@{
	Command = "layout"
	Description = "Lays out the rooms on an (x,y) grid."
}
$helpArray += [PSCustomObject]@{
	Command = "select region <x1>,<y1> <x2>,<y2>"
	Description = "Selects the rectangular region defined by (<x1>,<y1>) and (<x2>,<y2>)."
}
$helpArray += [PSCustomObject]@{
	Command = "move <uid> <x>,<y>"
	Description = "Moves the room <uid> in the currently selected area to location (<x>,<y>)."
}
$helpArray += [PSCustomObject]@{
	Command = "move region <x>,<y>"
	Description = "Moves the previously selected region to location (<x>,<y>) in the current area."
}
$helpArray += [PSCustomObject]@{
	Command = "export <filename>.json"
	Description = "Exports the map data of the currently-selected area to a JSON-format file."
}
$helpArray += [PSCustomObject]@{
	Command = "export <filename>.csv"
	Description = "Exports the map data of the currently-selected area to a set of CSV-format files."
}

function layoutArea {
	Write-Host -NoNewLine "Laying out area '$($selectedArea)'..."
	# Breadth-first search algorithm
	$script:positionedRooms = @()
	$arearooms = $rooms | Where-Object {$_.area -eq $selectedArea}
	$arearoomexits = $exits | Where-Object {$arearooms.uid -contains $_.fromuid}
	# Sort by most-connected compass exits
	$arearooms = $arearooms | Sort-Object -Descending { $thisRoom=$_;($arearoomexits | Where-Object {$_.touid -ne "-1" -and $_.fromuid -ne "-1" -and ($_.touid -eq $thisRoom.uid -or $_.fromuid -eq $thisRoom.uid) -and ("n","e","s","w","u","d") -contains $_.dir}).Count }
	# Let Q be the queue
	$roomsToBePositioned = New-Object System.Collections.ArrayList
	$visited = @()
	# Start room at 50,50
	# Q.enqueue(X) // Inserting source node X into the queue
	$room = $arearooms | Select-Object -First 1
	$info = $room.info
	$pk = 0
	if ($info -ne $null -and ($info -split ",") -contains "pk") {
		$pk = 1
	}
	$result = $roomsToBePositioned.Add([PSCustomObject]@{
		uid		= $roomuids.LookupUidAlpha($room.uid)
		name	= $room.name
		x		= 50
		y		= 50
		pk		= $pk
	})
	# Mark X node as visited.
	$visited += $roomuids.LookupUidAlpha($room.uid)
	# While (Q is not empty)
	while ($roomsToBePositioned.Count -gt 0) {
		# Y = Q.dequeue() // Removing the front node from the queue
		$frontNode = $roomsToBePositioned[0].PSObject.Copy()
		$result = $roomsToBePositioned.RemoveAt(0)
		$script:grid.Add($frontNode.uid, [AardMapGridPosition]::new($frontNode.x,$frontNode.y))
		$script:positionedRooms += $frontNode
		$minx = $script:grid.getMinMax("min","x")
		$miny = $script:grid.getMinMax("min","y")
		$maxx = $script:grid.getMinMax("max","x")
		$maxy = $script:grid.getMinMax("max","y")
		foreach ($item in $roomsToBePositioned) {
			if ($minx -gt $item.x) {
				$minx = $item.x
			}
			if ($miny -gt $item.y) {
				$miny = $item.y
			}
			if ($maxx -lt $item.x) {
				$maxx = $item.x
			}
			if ($maxy -lt $item.y) {
				$maxy = $item.y
			}
		}
		# Process all the neighbors of Y
		# exclude custom exits
		$alphaNumericUid = $roomuids.LookupUidInt($frontNode.uid)
		$neighbourExits = $null
		$neighbourExits = $arearoomexits | Where-Object {$_.touid -ne "-1" -and $_.fromuid -ne "-1" -and $_.fromuid -eq $alphaNumericUid -and ("n","e","s","w","u","d") -contains $_.dir}
		$neighbourNodes = New-Object System.Collections.ArrayList
		foreach ($exit in $neighbourExits) {
			$neighbour = $arearooms | Where-Object {$exit.touid -ne $null -and $exit.touid -ne "" -and $_.uid -eq $exit.touid}
			if (($neighbourNodes.Count -eq 0 -or $neighbourNodes.uid -notcontains $neighbour.uid) -and $neighbour -ne $null) {
				$result = $neighbourNodes.Add($neighbour)
			}
		}
		# For all the neighbors Z of Y
		foreach ($node in $neighbourNodes) {
			$nodealphaNumericUid = $node.uid
			$nodeuid = $roomuids.LookupUidAlpha($nodealphaNumericUid)
			# If Z is not visited
			if ($visited -notcontains $nodeuid -and $roomsToBePositioned.uid -notcontains $nodeuid -and !$grid.isPositioned($nodeuid)) {
				# Q.enqueue(Z) // Stores Z in Q
				# work out where it needs to go first
				$neighbourExits = $null
				$neighbourExits = $arearoomexits | Where-Object {$_.touid -ne "-1" -and $_.fromuid -ne "-1" -and $_.touid -eq $nodealphaNumericUid -and $_.fromuid -eq $alphaNumericUid -and ("n","e","s","w","u","d") -contains $_.dir}
				$x = $frontNode.x
				$y = $frontNode.y
				$info = $node.info
				$pk = 0
				if ($info -ne $null -and ($info -split ",") -contains "pk") {
					$pk = 1
				}
				$xdelta = 0
				$ydelta = 0
				switch ($neighbourExits.dir) {
					"n" { $ydelta = -1; break }
					"e" { $xdelta =  1; break }
					"s" { $ydelta =  1; break }
					"w" { $xdelta = -1; break }
					"u" { $xdelta =  1; $ydelta = -1; break }
					"d" { $xdelta = -1; $ydelta =  1; break }
				}
				if (($x + $xdelta) -lt 0 -or ($y + $ydelta) -lt 0) {
					Write-Host ""
					Write-Host -ForegroundColor "Yellow" "WARNING: bad coordinates ($($x + $xdelta),$($y + $ydelta)) attempted for uid $($nodeuid)."
					if (($x + $xdelta) -lt 0) {
						$xdelta = 0
						$x = 0
					}
					if (($y + $ydelta) -lt 0) {
						$ydelta = 0
						$y = 0
					}
				}
				$checkRooms = $null
				$checkRooms = $roomsToBePositioned | Where-Object {$_.x -eq ($x + $xdelta) -and $_.y -eq ($y + $ydelta)}
				if ($script:grid.isOccupied([AardMapGridPosition]::new(($x + $xdelta),($y + $ydelta))) -or $checkRooms -ne $null) {
					$ydelta = ($maxy + 2) - $y
				}
				if (($x + $xdelta) -ge 0 -and ($y + $ydelta) -ge 0) {
					$x = $x + $xdelta
					$y = $y + $ydelta
				}
				if ($x -lt $minx) {
					$minx = $x
				}
				if ($x -gt $maxx) {
					$maxx = $x
				}
				if ($y -lt $miny) {
					$miny = $y
				}
				if ($y -gt $maxy) {
					$maxy = $y
				}
				$result = $roomsToBePositioned.Add([PSCustomObject]@{
					uid		= $nodeuid
					name	= $node.name
					x		= $x
					y		= $y
					pk		= $pk
				})
				# Mark Z as visited
				$visited += $nodeuid
			} # end if Z is not visited
		} # end for all the neighbours Z of Y
		# Are there any nodes not already visited and not already in the queue?
		$minx = $script:grid.getMinMax("min","x")
		$miny = $script:grid.getMinMax("min","y")
		$maxx = $script:grid.getMinMax("max","x")
		$maxy = $script:grid.getMinMax("max","y")
		foreach ($item in $roomsToBePositioned) {
			if ($minx -gt $item.x) {
				$minx = $item.x
			}
			if ($miny -gt $item.y) {
				$miny = $item.y
			}
			if ($maxx -lt $item.x) {
				$maxx = $item.x
			}
			if ($maxy -lt $item.y) {
				$maxy = $item.y
			}
		}
		$remainingNodes = $null
		$remainingNodes = $arearooms | Where-Object {$visited -notcontains $roomuids.LookupUidAlpha($_.uid) -and $roomsToBePositioned.uid -notcontains $roomuids.LookupUidAlpha($_.uid)}
		if ($remainingNodes -ne $null -and $roomsToBePositioned.Count -eq 0) {
			# yes, there are nodes remaining, add the first of these
			if ($remainingNodes.Count -gt 0) {
				$newFrontNode = $remainingNodes[0]
			} else {
				$newFrontNode = $remainingNodes
			}
			# need to figure out where it goes first
			$nodeuid = $roomuids.LookupUidAlpha($newFrontNode.uid)
			$x = [Math]::round(((($maxx - $minx) / 2) + $minx))
			$y = $maxy + 2
			$xdelta = 0
			$ydelta = 0
			$checkRooms = $null
			$checkRooms = $roomsToBePositioned | Where-Object {$_.x -eq ($x + $xdelta) -and $_.y -eq ($y + $ydelta)}
			while ($script:grid.isOccupied([AardMapGridPosition]::new(($x + $xdelta),($y + $ydelta)))) {
				if ($script:grid.isOccupied([AardMapGridPosition]::new(($x + $xdelta),($y + $ydelta))) -or $checkRooms -ne $null) {
					$ydelta = $ydelta + 1
				}
				$checkRooms = $null
				$checkRooms = $roomsToBePositioned | Where-Object {$_.x -eq ($x + $xdelta) -and $_.y -eq ($y + $ydelta)}
			} # end while checking for occupied
			if (($x + $xdelta) -ge 0 -and ($y + $ydelta) -ge 0) {
				$x = $x + $xdelta
				$y = $y + $ydelta
			}
			if ($x -lt $minx) {
				$minx = $x
			}
			if ($x -gt $maxx) {
				$maxx = $x
			}
			if ($y -lt $miny) {
				$miny = $y
			}
			if ($y -gt $maxy) {
				$maxy = $y
			}
			# now we can add it
			$info = $newFrontNode.info
			$pk = 0
			if ($info -ne $null -and ($info -split ",") -contains "pk") {
				$pk = 1
			}
			$result = $roomsToBePositioned.Add([PSCustomObject]@{
				uid		= $nodeuid
				name	= $newFrontNode.name
				x		= $x
				y		= $y
				pk		= $pk
			})
			$visited += $nodeuid
		} # end remaining nodes
	} # end while (Q is not empty)
	Write-Host -ForegroundColor "Green" "DONE"
	Write-Host -ForegroundColor "Yellow" "NOTE: Please be aware that breadth-first search currently provides a sub-optimal layout."
} # end layout

function parseCommand {
	Param(
		[Parameter(Mandatory=$true)]
		[string]$command
	)
	# Is the command empty?
	if ($command -eq $null -or $command -eq "") {
		# yes, return
		return
	}
	# Split the command into tokens
	$tokens = $command -split " "
	switch ($tokens[0]) {
		"list" {
			switch ($tokens[1]) {
				"areas" {
					$arealist = $areas | Where-Object {$_.uid -ne "*" -and $_.uid -ne "**"} | Select-Object name,uid | Sort-Object uid | Format-Table | Out-String
					Write-Host $arealist
					break
				} # end list areas command
			}
		} # end list command
		"select" {
			switch ($tokens[1]) {
				"area" {
					# has an area been specified?
					if ($tokens[2] -eq $null -or $tokens[2] -eq "") {
						# must specify an area uid
						Write-Host -ForegroundColor "Red" "You must specify an area uid after 'select area'."
						return
					}
					# is it a valid area uid?
					if ($areas.uid -notcontains $tokens[2]) {
						# must specify a valid area uid
						Write-Host -ForegroundColor "Red" "Area '$($tokens[2])' not found. Try 'list areas' to get a list of area uids."
						return
					}
					# has an area already been selected and there's unsaved changes?
					if ($areaSelected -and $unsavedChanges) {
						# yes, warn the user
						Write-Host -ForegroundColor "Yellow" "WARNING: There are unsaved changes in your currently selected area '$($selectedArea)'."
						$yesno = "X"
						while ($yesno -notmatch "[yYnN]") {
							Write-Host -ForegroundColor "Yellow" -NoNewLine "Are you sure you want to discard changes (Y/N)? "
							$yesno = Read-Host
							Write-Host ""
							if ($yesno -notmatch "[yYnN]") {
								Write-Host -ForegroundColor "Red" "Invalid response, please choose Y or N."
							}
						}
						if ($yesno -match "[nN]") {
							# user doesn't want to discard changes, return
							return
						}
					}
					$script:areaSelected = $true
					$script:areaLayout = $false
					$script:selectedArea = $tokens[2]
					$script:unsavedChanges = $false
					$script:commandPrompt = "area $($selectedArea)"
					Write-Host "Area '$(($areas | Where-Object {$_.uid -eq $selectedArea}).name)' (uid '$($selectedArea)') selected."
					break
				} # end select area command
				default {
					Write-Host -ForegroundColor "Red" "Syntax error. Try 'select area <uid>'."
					return
				}
			}
		} # end select command
		"layout" {
			# has an area been selected?
			if (!$areaSelected) {
				# must select an area first
				Write-Host -ForegroundColor "Red" "You must select an area first. Try 'list areas' then 'select area <uid>', replacing <uid> with your chosen area's uid."
				return
			}
			# are there unsaved changes?
			if ($unsavedChanges) {
				Write-Host -ForegroundColor "Yellow" "WARNING: There are unsaved changes."
				$yesno = "X"
				while ($yesno -notmatch "[yYnN]") {
					Write-Host -ForegroundColor "Yellow" -NoNewLine "Are you sure you want to discard changes (Y/N)? "
					$yesno = Read-Host
					Write-Host ""
					if ($yesno -notmatch "[yYnN]") {
						Write-Host -ForegroundColor "Red" "Invalid response, please choose Y or N."
					}
				}
				if ($yesno -match "[nN]") {
					# user doesn't want to discard changes, return
					return
				}
			}
			$script:unsavedChanges = $false
			$script:grid = [AardMapGrid]::new(200,200)
			layoutArea
			$script:unsavedChanges = $true
			$script:areaLayout = $true
			break
		} # end layout command
		"export" {
			$filename = $command.SubString(6,($command.Length - 6)).Trim()
			$exporttype = "none"
			if ($filename -match ".json") {
				$exporttype = "json"
			} elseif ($filename -match ".csv") {
				$exporttype = "csv"
			}
			# has the user specified an appropriate export filetype?
			if ($exporttype -eq "none") {
				# no they haven't
				Write-Host -ForegroundColor "Red" "Invalid export file type. You must supply a filename ending in .json or .csv."
				return
			}
			Write-Host -NoNewLine "Collating data for export..."
			$filename = $filename.Replace('"',"")
			$area = $areas | Where-Object {$_.uid -eq $selectedArea} | Select-Object uid,name,texture,color,flags
			$arearoomexits = $exits | Where-Object {$_.fromuid -ne "-1" -and $_.touid -ne "-1" -and ($positionedRooms.uid -contains $roomuids.LookupUidAlpha($_.fromuid) -or $positionedRooms.uid -contains $roomuids.LookupUidAlpha($_.touid))} | Select-Object fromuid,dir,touid
			$oldGeneration = $arearoomexits.PSObject.Copy()
			$arearoomexits = @()
			foreach ($item in $oldGeneration) {
				# fix up uids
				$item.fromuid = $roomuids.LookupUidAlpha($item.fromuid)
				$item.touid = $roomuids.LookupUidAlpha($item.touid)
				$arearoomexits += $item
			}
			$newPositionedRooms = @()
			$minx = $script:grid.getMinMax("min","x") - 1
			$miny = $script:grid.getMinMax("min","y") - 1
			foreach ($item in $positionedRooms) {
				# fix up positions
				$item.x = $item.x - $minx
				$item.y = $item.y - $miny
				$newPositionedRooms += $item
			}
			Write-Host -ForegroundColor "Green" "DONE"
			switch ($exporttype) {
				"json" {
					$jsonexport = [PSCustomObject]@{
						areas = @($area)
						rooms = $newPositionedRooms
						exits = $arearoomexits
					}
					$jsonexport | ConvertTo-Json | Set-Content $filename
				}
				"csv" {
					$areascsv = $filename.Replace(".csv", "_areas.csv")
					$roomscsv = $filename.Replace(".csv", "_rooms.csv")
					$exitscsv = $filename.Replace(".csv", "_exits.csv")
					$area | Export-Csv $areascsv -NoTypeInformation -Encoding Ascii
					$positionedRooms | Export-Csv $roomscsv -NoTypeInformation -Encoding Ascii
					$arearoomexits | Export-Csv $exitscsv -NoTypeInformation -Encoding Ascii
				}
			}
			$script:unsavedChanges = $false
			Write-Host "Exported area '$($selectedArea)' to '$($filename)'"
			break
		} # end export command
		"move" {
			
		} # end move command
		"exit" {
			# are there unsaved changes?
			if ($unsavedChanges) {
				Write-Host -ForegroundColor "Yellow" "WARNING: There are unsaved changes."
				$yesno = "X"
				while ($yesno -notmatch "[yYnN]") {
					Write-Host -ForegroundColor "Yellow" -NoNewLine "Are you sure you want to discard changes (Y/N)? "
					$yesno = Read-Host
					Write-Host ""
					if ($yesno -notmatch "[yYnN]") {
						Write-Host -ForegroundColor "Red" "Invalid response, please choose Y or N."
					}
				}
				if ($yesno -match "[nN]") {
					# user doesn't want to discard changes, return
					return
				}
			}
			$script:exitRequested = $true
			break
		} # end exit command
		"script" {
			
		} # end script command
		"help" {
			Write-Host "$($helpArray | Format-Table | Out-String)"
			break
		} # end help command
	}
}

$command = ""
$commandPrompt = "command"
$exitRequested = $false
while (!$exitRequested) {
	Write-Host -ForegroundColor "Cyan" -NoNewLine "$($commandPrompt)> "
	$command = Read-Host
	parseCommand $command
}

exit 0

