# maps-public
A public repository where scripts related to the Gaardian maps project can be shared.

# AardMapLayoutEngine.ps1
If you want this script to work you will need to:
1. Export the areas, rooms and exits tables from your MUSHclient mapper SQLite database as separate JSON files.
2. Edit the downloaded AardMapLayoutEngine.ps1 to put in the paths where those files are saved, the area you want to try and lay out, and your desired output file name / location

Once you've done those things you should be able to just right-click it and choose "Run with PowerShell".

The script has now been fixed enough that it actually does run without getting stuck. However the optimization passes do not give the desired result.

After that you should get to a "command>" prompt, you can just type "exit" and press Enter to have it output the result.
