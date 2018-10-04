Function Get-SoguFileNames
{
	Param
	(
        [Parameter(Mandatory = $true, ParameterSetName = "Search")]
		[Switch]$ShowFileNames,
        [Parameter(Mandatory = $true, ParameterSetName = "CustomSearch")]
		[String]$CustomSerial,
        [Parameter(ParameterSetName = "Search")]
        [Parameter(ParameterSetName = "CustomSearch")]
		[Switch]$SearchFiles
	)
    begin
    {
        $Source =`
@"
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Management.Automation;

namespace SoguFiles
{
	public struct SoguStruct
	{
		public int code_val;
		public string code_ascii;
		public string desc;
		public bool dtg;
		
		public SoguStruct(int Code_Val, string Code_ascii, string Desc, bool DTG)
		{
			code_val = Code_Val;
			code_ascii = Code_ascii;
			desc = Desc;
			dtg = DTG;		
		}
	}

	public static class GenNames
	{
		public static PSObject main(string[] args, string vol)
		{
			List<string> files_out = new List<string>();
			PSObject obj_out = new PSObject();
			
			List<SoguStruct> items = new List<SoguStruct>();
			items.Add(new SoguStruct(0x4343, "CC", "VictimID", 			true));
			items.Add(new SoguStruct(0x4358, "CX", "ConfigBlock",		true));
			items.Add(new SoguStruct(0x4B4C, "KL", "KeylogCache", 		true));
			items.Add(new SoguStruct(0x485A, "HZ", "LearnedProxies", 	true));
			items.Add(new SoguStruct(0x4343, "CC", "VictimID", 			false));
			items.Add(new SoguStruct(0x4346, "CF", "ConfigBlock",		false));
			items.Add(new SoguStruct(0x4B4C, "KL", "KeylogCache", 		false));
			items.Add(new SoguStruct(0x4850, "HP", "LearnedProxies", 	false));
			foreach(string serial in args)
			{
				obj_out.Members.Add(new PSNoteProperty("Serial", serial));
				obj_out.Members.Add(new PSNoteProperty("VolumeLetter", vol));
				UInt32 num_serial = UInt32.Parse(serial.Replace("-",""), NumberStyles.HexNumber);
				Console.WriteLine("Drive {0} ({1}) ------------------------------------------------------", vol, serial);
				foreach (SoguStruct item in items)
				{
					string filename = GetFilename(num_serial, (UInt16)item.code_val, item.dtg);
					files_out.Add(item.desc+':'+filename);
					string type = item.dtg ? "Type1" : "Type2";
					Console.WriteLine("{0,0} {1,1} {2,-14} HD Serial {3,-10} Filename: {4}", type, item.code_ascii, item.desc, num_serial.ToString("X8"), filename);
				}
                Console.WriteLine("");
				obj_out.Members.Add(new PSNoteProperty("files", files_out.ToArray()));
			}
			
			return obj_out;
		}
		public static string GetFilename(UInt32 serial, UInt16 type, Boolean dtg)
		{
			string filename = "";
			UInt32 dtg_val = 20140121;
			UInt32 key = serial ^ type;
			UInt32 len = (key & 0xF) + 3;
			
			for (int i=0;i<len;i++)
			{
				filename += (char)(key % 26 + (char)'a');
				UInt32 temp = (key << 7) - (key >> 3) + ((dtg) ? dtg_val : 0xD);
				key = (temp << 3) - (temp >> 7) - ((dtg) ? dtg_val : 0x11);
			}
			
			return filename;
		}
	}
}
"@
	    # Adds the C# source code for use in the PowerShell script
	    Add-Type -TypeDefinition $Source -Language CSharp -ErrorAction SilentlyContinue
        $GenNames = [SoguFiles.GenNames]
    }
    process
    {
        if($ShowFileNames)
        {
            # Check For Windows Drives
            $Serials = Get-WmiObject Win32_LogicalDisk | Select-Object -Property VolumeSerialNumber, DeviceID, DriveType | Where-Object {$_.VolumeSerialNumber -ne $null -and ($_.DriveType -eq 3 -or $_.DriveType -eq 2)}
            # Supplies the serial and drive letter for each drive and processes them through the C# code to generate the list of SOGU filenames.
            $Results = @()
            foreach($Serial in $Serials)
            {
                if($Serial.VolumeSerialNumber)
                {
                    $Results += $GenNames::main($Serial.VolumeSerialNumber,$Serial.DeviceID)
                }
            }
        }
        if($CustomSerial)
        {
            $VolumeLetter = (Get-WmiObject Win32_LogicalDisk | Select-Object -Property VolumeSerialNumber, DeviceID, DriveType | Where-Object {$_.VolumeSerialNumber -eq $CustomSerial}).DeviceID
            if(!$VolumeLetter)
            {
                Write-Host "A System Drive with the SerialNumber you entered ($CustomSerial) does not exist." -ForegroundColor Red
                break
            }
            $Results = $GenNames::main($CustomSerial, $VolumeLetter)
        }
        if($SearchFiles)
        {
            $output = @{FilesFound = @(); FilesNotFound = @()}
            foreach($Result in $Results)
            {
                $DriveLetter = $Result.VolumeLetter+'\'
                $VolumeSerial = $Result.Serial
                foreach($SoguFileName in $Result.Files)
                {
                    $Description = $SoguFileName.Split(':')[0]
                    $FileName = $SoguFileName.Split(':')[1]
                    Write-Host "Searching for $FileName on $DriveLetter...`n" -ForegroundColor Green
                    $File = Get-ChildItem -Path $DriveLetter -Filter $FileName -Recurse -Force -ErrorAction SilentlyContinue
                    if($File)
                    {
                        Write-Host "$FileName was found on $DriveLetter!`nFileDescription = $Description`nFilePath = $($File.Fullname)`n" -ForegroundColor red
                    }
                    elseif(!$File)
                    {
                        Write-Host "$FileName was not found; Starting search for the next file...`n" -ForegroundColor DarkGray
                    }
                    $FileInfo = New-object -TypeName psobject -Property @{
                        ComputerName        =        (Get-WmiObject -Class Win32_ComputerSystem).Name
                        DriveLetter         =        $DriveLetter
                        VolumeSerialNumber  =        $VolumeSerial
                        FileDescription     =        $Description
                        FileName            =        $FileName
                        FilePath            =        $File.FullName
                        FileSize            =        [string][math]::Round([int]$File.Length /1kb,2)+'kb ('+$File.Length+' bytes)'
                    }
                    if($FileInfo.FilePath)
                    {
                        $output.FilesFound += $FileInfo | Select-Object ComputerName, DriveLetter, VolumeSerialNumber, FileDescription, FileName, FilePath, FileSize
                    }
                    elseif(!$FileInfo.FilePath)
                    {
                        $FileInfo.FilePath = 'The File Was Not Found'
                        $output.FilesNotFound += $FileInfo | Select-Object ComputerName, DriveLetter, VolumeSerialNumber, FileDescription, FileName, FilePath
                    }
                }
            }
            Return $output
        }
    }
}
