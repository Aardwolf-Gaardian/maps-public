# Aardwolf Map Layout Engine
# by Danj

# ** YOU NEED TO CHANGE SOME THINGS BEFORE THIS WILL ACTUALLY RUN **
# ** LOOK FOR THE DOUBLE ASTERISKS **

# Import JSON files from MUSHclient mapper
Write-Host "Importing files..."
$m_areas = Get-Content "** PUT A JSON EXPORTED VERSION OF YOUR MUSHCLIENT MAPPER DB AREAS TABLE HERE **" | ConvertFrom-JSON
$m_rooms = Get-Content "** PUT A JSON EXPORTED VERSION OF YOUR MUSHCLIENT MAPPER DB ROOMS TABLE HERE **" | ConvertFrom-JSON
$m_exits = Get-Content "** PUT A JSON EXPORTED VERSION OF YOUR MUSHCLIENT MAPPER DB EXITS TABLE HERE **" | ConvertFrom-JSON

# Pick an area
$areauid = "** PUT THE KEYWORD OF YOUR AREA HERE, I HAVE BEEN TRYING annwn **"
Write-Host "Filtering to area..."
$thisarea = $m_areas | Where-Object {$_.uid -eq $areauid}
$arearooms = $m_rooms | Where-Object {$_.area -eq $areauid -and ($_.uid -as [int]) -ne $null -and ($_.uid -as [int]) -ne 0} # we only care about real rooms
$arearoomexits = $m_exits | Where-Object {$arearooms.uid -contains $_.fromuid} | Where-Object {($_.fromuid -as [int]) -ne $null -and ($_.fromuid -as [int]) -ne 0 -and ($_.touid -as [int]) -ne $null -and ($_.touid -as [int]) -ne 0}

# Main loop
Write-Host "Laying out rooms..."
# Variables
$positionedRooms = @()
$yeetfactor = 1
# Let Q be the queue
$roomsToBePositioned = New-Object System.Collections.ArrayList
$visited = @()

# Start room at 50,50
# Q.enqueue( X ) // Inserting source node X into the queue
$arearooms = $arearooms | Sort-Object -Descending { $this=$_;($arearoomexits | Where-Object {($_.touid -as [int]) -eq ($this.uid -as [int]) -or ($_.fromuid -as [int]) -eq ($this.uid -as [int])}).Count }
$room = $arearooms | Select-Object -First 1
$info = $room.info
$pk = 0
if ($info -ne $null -and ($info -split ",") -contains "pk") {
	$pk = 1
}
$result = $roomsToBePositioned.Add([PSCustomObject]@{
	uid		= ($room.uid -as [int])
	name	= $room.name
	x		= 50
	y		= 50
	pk		= $pk
})
# Mark X node as visited.
$visited += ($room.uid -as [int])

$roomorder = 1
# While ( Q is not empty )
while ($roomsToBePositioned.Count -gt 0) {
	# Y = Q.dequeue( ) // Removing the front node from the queue
	$frontNode = $roomsToBePositioned[0]
	$result = $roomsToBePositioned.RemoveAt(0)
	$frontNode.name += " ($($roomorder))"
	$positionedRooms += $frontNode
	Write-Host -NoNewLine "$($roomorder)..."
	$roomorder++
	$maxy = -999
	$minx = 999
	$maxx = -999
	foreach ($item in $positionedRooms) {
		if ($maxy -lt $item.y) {
			$maxy = $item.y
		}
		if ($minx -gt $item.x) {
			$minx = $item.x
		}
		if ($maxx -lt $item.x) {
			$maxx = $item.x
		}
	}
	foreach ($item in $roomsToBePositioned) {
		if ($maxy -lt $item.y) {
			$maxy = $item.y
		}
		if ($minx -gt $item.x) {
			$minx = $item.x
		}
		if ($maxx -lt $item.x) {
			$maxx = $item.x
		}
	}
	# Process all the neighbors of Y
	# exclude custom exits
	$neighbourExits = $null
	$neighbourExits = $arearoomexits | Where-Object {($_.fromuid -as [int]) -eq ($frontNode.uid -as [int]) -and ("n","e","s","w","u","d") -contains $_.dir}
	$neighbourNodes = New-Object System.Collections.ArrayList
	foreach ($exit in $neighbourExits) {
		$neighbour = $arearooms | Where-Object {($_.uid -as [int]) -eq ($exit.touid -as [int]) -and ($_.uid -as [int]) -ne $null -and ($_.uid -as [int]) -ne 0}
		if ($neighbourNodes.Count -eq 0 -or ($neighbourNodes.Count -gt 0 -and $neighbourNodes.uid -notcontains $neighbour.uid)) {
			$result = $neighbourNodes.Add($neighbour)
		}
	}
	# For all the neighbors Z of Y
	foreach ($node in $neighbourNodes) {
		if (($node.uid -as [int]) -eq $null -or ($node.uid -as [int]) -eq 0) {
			# skip it
			continue
		}
		# If Z is not visited
		if ($visited -notcontains ($node.uid -as [int]) -and $roomsToBePositioned.uid -notcontains ($node.uid -as [int]) -and $positionedRooms.uid -notcontains ($node.uid -as [int])) {
			# Q. enqueue( Z ) // Stores Z in Q
			# work out where it needs to go first
			$neighbourExits = $null
			$neighbourExits = $arearoomexits | Where-Object {($_.touid -as [int]) -eq ($node.uid -as [int]) -and ($_.fromuid -as [int]) -eq ($frontNode.uid -as [int]) -and ("n","e","s","w","u","d") -contains $_.dir}
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
				"n" { $ydelta = -$yeetfactor; break }
				"e" { $xdelta =  $yeetfactor; break }
				"s" { $ydelta =  $yeetfactor; break }
				"w" { $xdelta = -$yeetfactor; break }
				"u" { $xdelta =  $yeetfactor; $ydelta = -$yeetfactor; break }
				"d" { $xdelta = -$yeetfactor; $ydelta =  $yeetfactor; break }
			}
			if ($xdelta -ne 0) {
				$xsign = $xdelta / [Math]::abs($xdelta)
			} else {
				$xsign = 0
			}
			if ($ydelta -ne 0) {
				$ysign = $ydelta / [Math]::abs($ydelta)
			} else {
				$ysign = 0
			}
			$checkRooms = $null
			$checkRooms = ($positionedRooms + $roomsToBePositioned) | Where-Object {$_.x -eq ($x + $xdelta) -and $_.y -eq ($y + $ydelta)}
			if ($checkRooms -ne $null) {
				$ydelta = ($maxy + 1 + $yeetfactor) - $y
			}
			# while ($checkRooms -ne $null) {
				# if ($checkRooms -ne $null) {
					# # already a room there
					# # yeet it
					# $xdelta = $xdelta + ($xsign * $yeetfactor)
					# $ydelta = $ydelta + ($xsign * $yeetfactor)
					# if ($xdelta -eq 0 -and $ydelta -eq 0) {
						# # it's not gonna move, so yeet it down
						# $ydelta = $yeetfactor
					# }
				# }
				# $checkRooms = $null
				# $checkRooms = ($positionedRooms + $roomsToBePositioned) | Where-Object {$_.x -eq ($x + $xdelta) -and $_.y -eq ($y + $ydelta)}
			# }
			$x = $x + $xdelta
			$y = $y + $ydelta
			$result = $roomsToBePositioned.Add([PSCustomObject]@{
				uid		= ($node.uid -as [int])
				name	= $node.name
				x		= $x
				y		= $y
				pk		= $pk
			})
			# Mark Z as visited
			$visited += ($node.uid -as [int])
		}
	}
	# Are there any nodes not already visited and not already in the queue?
	$maxy = -999
	$minx = 999
	$maxx = -999
	foreach ($item in $positionedRooms) {
		if ($maxy -lt $item.y) {
			$maxy = $item.y
		}
		if ($minx -gt $item.x) {
			$minx = $item.x
		}
		if ($maxx -lt $item.x) {
			$maxx = $item.x
		}
	}
	foreach ($item in $roomsToBePositioned) {
		if ($maxy -lt $item.y) {
			$maxy = $item.y
		}
		if ($minx -gt $item.x) {
			$minx = $item.x
		}
		if ($maxx -lt $item.x) {
			$maxx = $item.x
		}
	}
	$remainingNodes = $null
	$remainingNodes = $arearooms | Where-Object {$visited -notcontains ($_.uid -as [int]) -and $roomsToBePositioned.uid -notcontains ($_.uid -as [int]) -and ($_.uid -as [int]) -ne $null -and ($_.uid -as [int]) -ne 0}
	if ($remainingNodes -ne $null -and $roomsToBePositioned.Count -eq 0) {
		# yes, there are nodes remaining, add the first of these
		if ($remainingNodes.Count -gt 0) {
			$newFrontNode = $remainingNodes[0]
		} else {
			$newFrontNode = $remainingNodes
		}
		# need to figure out where it goes first
		# how about 10-20 below the lowest node already positioned or in the queue?
		$x = [Math]::round(((($maxx - $minx) / 2) + $minx))
		$y = $maxy + 1 + $yeetfactor
		$xdelta = $yeetfactor
		$ydelta = $yeetfactor
		# $checkRooms = $null
		# $checkRooms = ($positionedRooms + $roomsToBePositioned) | Where-Object {$_.x -eq ($x + $xdelta) -and $_.y -eq ($y + $ydelta)}
		# while ($checkRooms -ne $null) {
			# if ($checkRooms -ne $null) {
				# # already a room there
				# # yeet it
				# $xdelta = $xdelta + $yeetfactor
				# $ydelta = $ydelta + $yeetfactor
			# }
			# $checkRooms = $null
			# $checkRooms = ($positionedRooms + $roomsToBePositioned) | Where-Object {$_.x -eq ($x + $xdelta) -and $_.y -eq ($y + $ydelta)}
		# }
		$x = $x + $xdelta
		$y = $y + $ydelta
		# now we can add it
		$info = $newFrontNode.info
		$pk = 0
		if ($info -ne $null -and ($info -split ",") -contains "pk") {
			$pk = 1
		}
		$result = $roomsToBePositioned.Add([PSCustomObject]@{
			uid		= ($newFrontNode.uid -as [int])
			name	= $newFrontNode.name
			x		= $x
			y		= $y
			pk		= $pk
		})
		$visited += ($newFrontNode.uid -as [int])
	}
}

Write-Host ""

# function to get the total number of disconnected compass exits
function getDisconnectedScore {
	Param(
		[Parameter(Mandatory=$true)]
		$rooms
	)
	$disconnectedScore = 0
	$maxx = -999
	$maxy = -999
	foreach ($room in $rooms) {
		if ($maxx -lt $room.x) {
			$maxx = $room.x
		}
		if ($maxy -lt $room.y) {
			$maxy = $room.y
		}
	}
	foreach ($room in $rooms) {
		$roomexits = $null
		$roomexits = $arearoomexits | Where-Object {($_.fromuid -as [int]) -ne $null -and ($_.touid -as [int]) -ne $null -and ($_.fromuid -as [int]) -ne 0 -and ($_.touid -as [int]) -ne 0 -and ($_.fromuid -as [int]) -eq $room.uid -and ("n","e","s","w","u","d") -contains $_.dir }
		if ($roomexits -eq $null) {
			# this room has no compass exits, skip
			continue
		}
		$neighbours = @()
		foreach ($exit in $roomexits) {
			if (($exit.touid -as [int]) -eq $room.uid) {
				# an exit that goes back to itself, skip
				continue
			}
			if ($neighbours -contains ($exit.touid -as [int])) {
				# a target room we've already looked at, skip
				continue
			}
			$neighbours += ($exit.touid -as [int])
			if ($rooms.uid -notcontains ($exit.touid -as [int])) {
				# a target room that isn't in the list of rooms, add 1 to disconnectedScore and skip
				$disconnectedScore++
				continue
			}
			$xdelta = 0
			$ydelta = 0
			switch ($exit.dir) {
				"n" { $ydelta = -1; break }
				"e" { $xdelta =  1; break }
				"s" { $ydelta =  1; break }
				"w" { $xdelta = -1; break }
				"u" { $xdelta =  1; $ydelta = -1; break }
				"d" { $xdelta = -1; $ydelta =  1; break }
			}
			# find target room
			$targetRoom = $null
			$targetRoom = $rooms | Where-Object {$_.uid -eq ($exit.touid -as [int])}
			if ($xdelta -eq 0 -and $targetRoom.x -ne $room.x) {
				# not in the same column, add 1 to disconnectedScore and skip
				$disconnectedScore++
				continue
			}
			if ($ydelta -eq 0 -and $targetRoom.y -ne $room.y) {
				# not in the same row, add 1 to disconnectedScore and skip
				$disconnectedScore++
				continue
			}
			if ($targetRoom.x -eq ($room.x + $xdelta) -and $targetRoom.y -eq ($room.y + $ydelta)) {
				# perfect positioning, skip
				continue
			}
			$x = $room.x + $xdelta
			$y = $room.y + $ydelta
			$found = $false
			$isCorrect = $false
			do {
				$checkRoom = $null
				$checkRoom = $rooms | Where-Object {$_.x -eq $x -and $_.y -eq $y}
				if ($checkRoom -ne $null) {
					$found = $true
					if ($checkRoom.uid -eq $targetRoom.uid) {
						$isCorrect = $true
					}
				} else {
					$x = $x + $xdelta
					$y = $y + $ydelta
				}
			} until ($x -lt 0 -or $x -gt $maxx -or $y -lt 0 -or $y -gt $maxy -or $found)
			if ($isCorrect) {
				# acceptable positioning, skip
				continue
			}
			if ($found) {
				# there's a room in the way, so the exit is disconnected
				$disconnectedScore++
			} else {
				# we hit the edge, so the exit is disconnected
				$disconnectedScore++
			}
		}
	}
	
	return $disconnectedScore
}

function whatIfMove {
	Param(
		[Parameter(Mandatory=$true)]
		$srcRoom,
		[Parameter(Mandatory=$true)]
		$destRoom,
		[Parameter(Mandatory=$true)]
		$rooms
	)
	# if $destRoom.uid equals 0 then that means it's a move not a swap
	$roomsNow = $rooms.PSObject.Copy()
	$roomsIfMoved = $rooms.PSObject.Copy()
	if ($destRoom.uid -eq 0) {
		$roomsIfMoved = $roomsIfMoved | Where-Object {if ($_.uid -eq $srcRoom.uid) {
			[PSCustomObject]@{
				uid		= $srcRoom.uid
				name	= $srcRoom.name
				x		= $destRoom.x
				y		= $destRoom.y
				pk		= $srcRoom.pk
			}
		} else {$_}}
	} else {
		$roomsIfMoved = $roomsIfMoved | Where-Object {if ($_.uid -eq $srcRoom.uid) {
			[PSCustomObject]@{
				uid		= $srcRoom.uid
				name	= $srcRoom.name
				x		= $destRoom.x
				y		= $destRoom.y
				pk		= $srcRoom.pk
			}
		} elseif ($_.uid -eq $destRoom.uid) {
			[PSCustomObject]@{
				uid		= $destRoom.uid
				name	= $destRoom.name
				x		= $srcRoom.x
				y		= $srcRoom.y
				pk		= $destRoom.pk
			}
		} else {$_}}
	}
	$resultNow = getDisconnectedScore $roomsNow
	$resultIfMoved = getDisconnectedScore $roomsIfMoved
	$result = $resultIfMoved - $resultNow
	
	return $result
}

# OPTIMIZATION LOOP
$moves = 0
$lastmoves = 0
$roomsMoved = @()
$index = 0
$passes = 0
$lastdisconnectedScore = 9999
$disconnectedScore = getDisconnectedScore $positionedRooms
if ($disconnectedScore -gt 0) {
	Write-Host "Optimizing..."
	do {
		# is the index out of bounds?
		if ($index -gt $positionedRooms.Count) {
			# yes, reset it
			Write-Host "Pass $($passes), $($moves) move(s), $($disconnectedScore) disconnected exits."
			$index = 0
			$lastmoves = $moves
			$moves = 0
			$lastdisconnectedScore = $disconnectedScore
			$disconnectedScore = getDisconnectedScore $positionedRooms
			$passes++
		}
		$room = $positionedRooms[$index]
		# have we already moved this room?
		if ($roomsMoved.uid -contains $room.uid) {
			# yes we have, skip it
			continue
		}
		# get compass exits of this room
		$roomexits = $null
		$roomexits = $arearoomexits | Where-Object {($_.fromuid -as [int]) -ne $null -and ($_.touid -as [int]) -ne $null -and ($_.fromuid -as [int]) -ne 0 -and ($_.touid -as [int]) -ne 0 -and ($_.fromuid -as [int]) -eq $room.uid -and ("n","e","s","w","u","d") -contains $_.dir }
		if ($roomexits -eq $null) {
			# this room has no compass exits, skip
			continue
		}
		$neighbours = @()
		foreach ($exit in $roomexits) {
			if (($exit.touid -as [int]) -eq $room.uid) {
				# an exit that goes back to itself, skip
				continue
			}
			if ($neighbours -contains ($exit.touid -as [int])) {
				# a target room we've already looked at, skip
				continue
			}
			if ($positionedRooms.uid -notcontains ($exit.touid -as [int])) {
				# not on the list, skip
				continue
			}
			$neighbours += ($exit.touid -as [int])
			$isDisconnected = $false
			$isConnected = $false
			$xdelta = 0
			$ydelta = 0
			switch ($exit.dir) {
				"n" { $ydelta = -1; break }
				"e" { $xdelta =  1; break }
				"s" { $ydelta =  1; break }
				"w" { $xdelta = -1; break }
				"u" { $xdelta =  1; $ydelta = -1; break }
				"d" { $xdelta = -1; $ydelta =  1; break }
			}
			# find target room
			$targetRoom = $null
			$targetRoom = $positionedRooms | Where-Object {$_.uid -eq ($exit.touid -as [int])}
			if ($xdelta -eq 0 -and $targetRoom.x -ne $room.x) {
				# not in the same column
				$isDisconnected = $true
			}
			if ($ydelta -eq 0 -and $targetRoom.y -ne $room.y) {
				# not in the same row
				$isDisconnected = $true
			}
			if ($targetRoom.x -eq ($room.x + $xdelta) -and $targetRoom.y -eq ($room.y + $ydelta)) {
				# perfect positioning, skip
				continue
			}
			$destRoom = $null
			if (!$isDisconnected) {
				$x = $room.x + $xdelta
				$y = $room.y + $ydelta
				$found = $false
				do {
					$checkRoom = $null
					$checkRoom = $positionedRooms | Where-Object {$_.x -eq $x -and $_.y -eq $y}
					if ($checkRoom -ne $null) {
						$found = $true
						if ($checkRoom.uid -eq $targetRoom.uid) {
							$isConnected = $true
						} else {
							$destRoom = $checkRoom
						}
					} else {
						$x = $x + $xdelta
						$y = $y + $ydelta
					}
				} until ($x -lt 0 -or $x -gt $maxx -or $y -lt 0 -or $y -gt $maxy -or $found)
			}
			if ($isConnected) {
				# acceptable positioning, skip
				continue
			}
			if ($found -and $destRoom -ne $null) {
				# if it's found but it's not connected, there's a room in the way, so the exit is disconnected and a swap is needed
				$result = whatIfMove $targetRoom $destRoom $positionedRooms
				if ($result -le 0) {
					# this move would reduce the number of disconnected exits, do it
					$destRoom.uid = $targetRoom.uid
					$positionedRooms = $positionedRooms | Where-Object {if ($_.uid -eq $destRoom.uid) {$destRoom} else {$_}}
					$moves++
					$disconnectedScore += $result
					$roomsMoved += $targetRoom
					$roomsMoved += $destRoom
				}
			} else {
				# it's not connected but nothing was found, so the exit is disconnected and a move is needed
				$destRoom = $null
				$destRoom = [PSCustomObject]@{
					uid		= 0
					name	= $targetRoom.name
					x		= ($room.x + $xdelta)
					y		= ($room.y + $ydelta)
					pk		= $targetRoom.pk
				}
				$result = whatIfMove $targetRoom $destRoom $positionedRooms
				if ($result -le 0) {
					# this move would reduce the number of disconnected exits, do it
					$destRoom.uid = $targetRoom.uid
					$positionedRooms = $positionedRooms | Where-Object {if ($_.uid -eq $destRoom.uid) {$destRoom} else {$_}}
					$moves++
					$disconnectedScore += $result
					$roomsMoved += $targetRoom
				}
			}
		}
		$index++
	} until ($disconnectedScore -eq $lastdisconnectedScore -and $passes -gt 1)
}
# OPTIMIZATION LOOP ENDS

# we need to move the rooms from being in a 100x100 grid first
$minx = 999
$miny = 999
foreach ($room in $positionedRooms) {
	if ($minx -gt $room.x) {
		$minx = $room.x
	}
	if ($miny -gt $room.y) {
		$miny = $room.y
	}
}
$minx = $minx - 1
$miny = $miny - 1
$oldGeneration = $positionedRooms.PSObject.Copy()
$positionedRooms = @()
foreach ($room in $oldGeneration) {
	$positionedRooms += [PSCustomObject]@{
		uid = $room.uid
		name = $room.name
		x = ($room.x - $minx)
		y = ($room.y - $miny)
		pk = $room.pk
	}
}

# COMMAND LOOP
function parseCommand {
	Param(
		[Parameter(Mandatory=$true)]
		$command,
		[Parameter(Mandatory=$true)]
		$positionedRooms,
		[Parameter()]
		$region
	)
	$tokens = $command -split " "
	switch($tokens[0]) {
		"insert" {
			switch($tokens[1]) {
				"column" {
					# $tokens[2] will be the column number to insert before
					$column = ($tokens[2] -as [int])
					$oldGeneration = $positionedRooms.PSObject.Copy()
					$positionedRooms = @()
					foreach ($room in $oldGeneration) {
						if ($room.x -ge $column) {
							$x = $room.x + 1
						} else {
							$x = $room.x
						}
						$y = $room.y
						$positionedRooms += [PSCustomObject]@{
							uid = $room.uid
							name = $room.name
							x = $x
							y = $y
							pk = $room.pk
						}
					}
					Write-Host -ForegroundColor Green "Column inserted at x position $($column)."
					break
				}
				"row" {
					# $tokens[2] will be the row number to insert before
					$row = ($tokens[2] -as [int])
					$oldGeneration = $positionedRooms.PSObject.Copy()
					$positionedRooms = @()
					foreach ($room in $oldGeneration) {
						if ($room.y -ge $row) {
							$y = $room.y + 1
						} else {
							$y = $room.y
						}
						$x = $room.x
						$positionedRooms += [PSCustomObject]@{
							uid = $room.uid
							name = $room.name
							x = $x
							y = $y
							pk = $room.pk
						}
					}
					Write-Host -ForegroundColor Green "Row inserted at y position $($row)."
					break
				}
			}
			break
		}
		"move" {
			# $tokens[1] will be a room uid or "region", $tokens[2] will be an x,y coordinate
			if ($tokens[1].ToLower() -eq "region") {
				if ($region -ne $null) {
					# $region.x1 and y1 defines top left, x2 and y2 defines bottom right
					$coords = $tokens[2] -split ","
					$x = ($coords[0] -as [int])
					$y = ($coords[1] -as [int])
					$oldGeneration = $positionedRooms.PSObject.Copy()
					$positionedRooms = @()
					$xdelta = $x - $region.x1
					$ydelta = $y - $region.y1
					foreach ($room in $oldGeneration) {
						if ($room.x -ge $region.x1 -and $room.x -le $region.x2 -and $room.y -ge $region.y1 -and $room.y -le $region.y2) {
							$positionedRooms += [PSCustomObject]@{
								uid = $room.uid
								name = $room.name
								x = ($room.x + $xdelta)
								y = ($room.y + $ydelta)
								pk = $room.pk
							}
						} else {
							$positionedRooms += $room
						}
					}
					Write-Host -ForegroundColor Green "Moved region $($region.x1),$($region.y1)-$($region.x2),$($region.y2) to $($x),$($y)."
					# invalidate region
					$region = $null
				} else {
					Write-Host -ForegroundColor Red "No region selected."
				}
			} elseif (($tokens[1] -as [int]) -ne $null) {
				$roomuid = ($tokens[1] -as [int])
				$coords = $tokens[2] -split ","
				$x = ($coords[0] -as [int])
				$y = ($coords[1] -as [int])
				$oldGeneration = $positionedRooms.PSObject.Copy()
				$positionedRooms = @()
				foreach ($room in $oldGeneration) {
					if ($room.uid -eq $roomuid) {
						$positionedRooms += [PSCustomObject]@{
							uid = $room.uid
							name = $room.name
							x = $x
							y = $y
							pk = $room.pk
						}
					} else {
						$positionedRooms += $room
					}
				}
				Write-Host -ForegroundColor Green "Moved room uid $roomuid to $($x),$($y)."
			} else {
				Write-Host -ForegroundColor Red "Invalid command: $command"
			}
			break
		}
		"select" {
			switch($tokens[1]) {
				"region" {
					# $tokens[2] will be x1,y1, $tokens[3] will be x2,y2
					$topLeft = $tokens[2] -split ","
					$bottomRight = $tokens[3] -split ","
					$x1 = ($topLeft[0] -as [int])
					$y1 = ($topLeft[1] -as [int])
					$x2 = ($bottomRight[0] -as [int])
					$y2 = ($bottomRight[1] -as [int])
					$region = [PSCustomObject]@{
						x1 = $x1
						y1 = $y1
						x2 = $x2
						y2 = $y2
					}
					Write-Host -ForegroundColor Green "Region $($region.x1),$($region.y1)-$($region.x2),$($region.y2) selected."
					break
				}
			}
			break
		}
		"mirror" {
			switch($tokens[1]) {
				"x" {
					# mirror the region about the x axis, with the top line acting as the axis
					if ($region -ne $null) {
						$axis = $region.y1
						$oldGeneration = $positionedRooms.PSObject.Copy()
						$positionedRooms = @()
						foreach ($room in $oldGeneration) {
							if ($room.x -ge $region.x1 -and $room.x -le $region.x2 -and $room.y -ge $region.y1 -and $room.y -le $region.y2) {
								$ydelta = $axis - $room.y
								$y = $axis + $ydelta
								$positionedRooms += [PSCustomObject]@{
									uid = $room.uid
									name = $room.name
									x = $room.x
									y = $y
									pk = $room.pk
								}
							} else {
								$positionedRooms += $room
							}
						}
						Write-Host -ForegroundColor Green "Mirrored region $($region.x1),$($region.y1)-$($region.x2),$($region.y2) about the axis y = $($axis)."
						# invalidate region
						$region = $null
					} else {
						Write-Host -ForegroundColor Red "No region selected."
					}
					break
				}
				"y" {
					# mirror the region about the y axis, with the left line acting as the axis
					if ($region -ne $null) {
						$axis = $region.x1
						$oldGeneration = $positionedRooms.PSObject.Copy()
						$positionedRooms = @()
						foreach ($room in $oldGeneration) {
							if ($room.x -ge $region.x1 -and $room.x -le $region.x2 -and $room.y -ge $region.y1 -and $room.y -le $region.y2) {
								$xdelta = $axis - $room.x
								$x = $axis + $xdelta
								$positionedRooms += [PSCustomObject]@{
									uid = $room.uid
									name = $room.name
									x = $x
									y = $room.y
									pk = $room.pk
								}
							} else {
								$positionedRooms += $room
							}
						}
						Write-Host -ForegroundColor Green "Mirrored region $($region.x1),$($region.y1)-$($region.x2),$($region.y2) about the axis x = $($axis)."
						# invalidate region
						$region = $null
					} else {
						Write-Host -ForegroundColor Red "No region selected."
					}
					break
				}
			}
		}
		"script" {
			$filename = $tokens[1]
			if (Test-Path $filename) {
				Write-Host -ForegroundColor Green "Executing script $($filename)."
				$filecontent = Get-Content $filename
				foreach ($line in $filecontent) {
					$result = parseCommand $line $positionedRooms $region
					$region = $result.region
					$positionedRooms = $result.positionedRooms
				}
			} else {
				Write-Host -ForegroundColor Red "Invalid filename $($filename)."
			}
			break
		}
		default {
			Write-Host "Your command was: $command"
		}
	}
	return [PSCustomObject]@{
		positionedRooms = $positionedRooms
		region = $region
	}
}
$command = ""
$region = $null
while ($command.ToLower() -ne "exit") {
	$command = ""
	Write-Host -NoNewLine -ForegroundColor Magenta "command> "
	$command = Read-Host
	Write-Host ""
	$result = parseCommand $command $positionedRooms $region
	$region = $result.region
	$positionedRooms = $result.positionedRooms
}
# COMMAND LOOP END

# we should have a full set of rooms in $positionedRooms now, hopefully a bit more optimised for position
Write-Host "Outputting to JSON format."
$positionedRooms | ConvertTo-JSON | Set-Content "** PUT YOUR DESIRED OUTPUT FILENAME HERE **"
