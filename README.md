## Sogu
This script generates a list of
possible SOGU filenames based on serial numbers of active drives. It has the
added functionality of searching each drive from the generated file list.

## Description
This script uses C# code to generate a list of SOGU filenames based on the algorithm used in the SOGU implant.
The script then utilizes PowerShell to query the system for drive information and, if selected, locates any Sogu files found on disk. 
The script can be deployed domain-wide to enumerate hosts to locate malicious files.
                                             
## Commands to import this script for use                                
To import the powershell script for use enter the following commands in the PowerShell Console 

```
PS> cd c:\Users\<username>\<folder that contains this script>
PS> import-module SoguFileSearch.ps1
```
### Parameters
```
ShowFileNames         Displays a list of all possible Sogu log filenames generated for each drive.

CustomSerial          1. Displays a list of all possible Sogu log filenames generated based on the 
                      Serial Number provided by the user. 
                      2. A user can provide a single or list of serials in the form of an array in the powershell 
                      console or a user generated text file.
                      3. If the Serial Number entered does not correlate to an active local drive on the machine 
                      the user is prompted with an error message.
                      4. The Serials used in the examples for this parameter will cause the script to throw an error, 
                      unless a drive is found with a serial that matches.
                      
SearchFiles           1. Searches the filesytem for the presence of Sogu log files.
                      2. Information for each file is saved as an object in a hashtable named output.
                      3. The output hashtable separates the file information based on the presence/absence of each Sogu log on disk.
                      4. The information collected by this option can be exported to log files for review.
```
## Examples
Import module for use and display a list of Sogu file names generated based on local disk serial numbers.
```
PS> Get-SoguFileNames -ShowFileNames
```
Displays a list of Sogu file names based on a single serial number provided by the user.
```
PS> Get-SoguFileNames-CustomSerial AAAAAAAA
```
Displays a list of Sogu file names based on a list of serial numbers provided by the user in the powershell console. 
```
PS> $Serials = @('AAAAAAAA','BBBBBBBB','CCCCCCCC','DDDDDDDD')
PS> foreach($Serial in $Serials)
    {
      Get-SoguFileNames -CustomSerial $Serial
    }
```
Display a list of Sogu file names based on a list of serial numbers provided by the user in a text file.
```
PS> $Serials = Get-Content <path to serial list text file>
PS> foreach($Serial in $Serials)
    {
      Get-SoguFileNames -CustomSerial $Serial
    }
```
Searches the drives for files with the generated names and saves the output to a vatiable. 
```
PS> $SoguFiles = Get-SoguFileNames -ShowFileNames-SearchFiles
```
## The following commands explain how to display the output or pipe the data to a log file.
Displays the "FilesFound" output from the $SoguFiles variable created in the example above.
```
PS> $SoguFiles.FilesFound
```
Displays the "FilesNotFound" output from the $SoguFiles variable created in the example above.
```
PS> $SoguFiles.FilesNotFound
```
Export the "FilesFound" output from the $Sogufiles variable to a log file.
```
PS> $SoguFiles.FilesFound | Out-File -FilePath <filepath>\<filename>.txt
```
Export the "FilesNotFound" output from the $Sogufiles variable to a log file.
```
PS> $SoguFiles.FilesNotFound | Out-File -FilePath <filepath>\<filename>.txt
```
## License
See the [LICENSE](https://github.com/DHS-NCCIC/Sogu/blob/master/LICENSE.md) file for license rights and limitations.
