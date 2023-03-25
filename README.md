# maps-public
A public repository where scripts related to the Gaardian maps project can be shared.

# AardMapLayoutEngine.ps1
Completely rewritten to be more user friendly. Still only achieves sub-optimal layouts though.

Dependencies:
* Windows (but you're already running Windows if you're using MUSHclient, right?)
* .NET Framework 4.6 or better
* Visual C++ 2015 Redistributable
* System.Data.SQLite library

Don't worry if there are any of these you don't have (well except for the Windows one), the script will tell you what you need to do to resolve any dependency issues.

The script will attempt to automatically locate your MUSHclient install folder and your Aardwolf.db database, if it can't do so for some reason it will tell you.

Once you get a "command>" prompt you can issue commands - start with "help" as this will tell you what the other available commands are.

Some of the commands aren't implemented yet but you can at least:
* list areas
* select an area
* lay it out
* export the area layout to JSON or CSV
