function Get-AbsolutePath ($Path)
{
    # System.IO.Path.Combine has two properties making it necesarry here:
    #   1) correctly deals with situations where $Path (the second term) is an absolute path
    #   2) correctly deals with situations where $Path (the second term) is relative
    # (join-path) commandlet does not have this first property
    $Path = [System.IO.Path]::Combine( ((pwd).Path), ($Path) );

    # this piece strips out any relative path modifiers like '..' and '.'
    $Path = [System.IO.Path]::GetFullPath($Path);

    return $Path;
}
function syncToS3 ($bucket, $original_path, $shadowcopy_location){
    $drive_letter = $original_path.Substring(0,1)
    $read_from_nodrive = Split-Path -Path $original_path -NoQualifier
    $read_from_nodrive = $read_from_nodrive.replace("\","/")

    
    $dest = "s3://$bucket/$drive_letter$read_from_nodrive"
    Write-Host "Uploading from $shadowcopy_location to $dest"

    aws s3 sync $shadowcopy_location $dest --sse AES256 --delete
}

$backup_path=Get-AbsolutePath($args[1])
Write-Host "Backing up $backup_path"

$drive_letter = Split-Path -Path $backup_path -Qualifier
$drive = "$drive_letter\\"

Write-Host "Creating shadow copy of drive $drive"

$s1 = (Get-WmiObject -List Win32_ShadowCopy).Create($drive, "ClientAccessible")
$s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
$d  = $s2.DeviceObject + "\\"
cmd /c mklink /d C:\shadowcopy "$d"


$read_from_nodrive = Split-Path -Path $backup_path -NoQualifier
$read_from = "C:\shadowcopy$read_from_nodrive"
Write-Host "reading shadow copy from $read_from"
syncToS3 $args[0] $backup_path $read_from

$s2.Delete()#Delete shadow copy
$(get-item "C:\shadowcopy").Delete()