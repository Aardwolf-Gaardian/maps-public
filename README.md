# maps-public
A public repository where scripts related to the Gaardian maps project can be shared.

# AardMapLayoutEngine.ps1
If you want this script to work you will need to:
1. Export the areas, rooms and exits tables from your MUSHclient mapper SQLite database as separate JSON files.
2. Edit the downloaded AardMapLayoutEngine.ps1 to put in the paths where those files are saved, the area you want to try and lay out, and your desired output file name / location

Once you've done those things you should be able to just right-click it and choose "Run with PowerShell".

If you want to actually get some output (it currently doesn't work properly), comment out everything between "OPTIMIZATION LOOP" and "OPTIMIZATION LOOP ENDS".

You should get to a "command>" prompt, you can just type "exit" and press Enter to have it output the result.
