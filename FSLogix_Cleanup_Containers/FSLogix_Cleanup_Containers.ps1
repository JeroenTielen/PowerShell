<#
.SYNOPSIS
    This script checks the path where FSLogix containers are stored. For each folder it will check the active directory for the status of the specific useraccount.
    The following checks will be performed: 

        1. Does the user still exists? 
        2. Is the user disabled? 
        3. What is the last logon date? 

    There are a couple of variables to set to tune the script for your needs: 
   
        1. $FSLogixPath       : The location where the containers are stored.
        2. $ExcludeFolders    : Is the location has folders which must not be processed you can add them here.
        3. $DaysInactive      : Minimum amount of days when the last logon occured.
        4. $DeleteDisabled    : Set this to 0 or 1. 0 will NOT delete conainters from disabled user accounts. 1 will ;) 
        5. $DeleteNotExisting : When an user is deleted and the conainers aren't deleted set this to 1 and the containers will be deleted.
        6. $DeleteInactive    : Users with a last logon longer the the $DaysInactive will be deleted if this is set to 1. 
        7. $FlipFlopEnabled   : Set this to 0 when the containers are stored in a folder starting with the user SID. When the folder starts with the username set this to 1. 
        8. $DryRun            : When this is set to 1, nothing will be deleted regardless the settings. This will also output more information which containers are claiming space.

.DESCRIPTION
    Can automatically cleanup FSLogix containers if they match the criteria. This will reduce the used space.  

.NOTES
    Version    : 1.1
    Date       : 13 March 2023 
    Created by : Jeroen Tielen - Tielen Consultancy B.V. 
    Email      : jeroen@tielenconsultancy.nl 

    History: 
        1.0 : 12 June 2022 - Initial setup script;
        1.1 : 13 March 2023 - Add FlipFlop Switch.
#>

# Tune this variables to your needs
$FSLogixPath                = "\\Nutanix_Files\FSLogix"                 # Set FSLogix containers path.
[string[]]$ExcludeFolders   = @('FSLogix_Redirections', 'Template')     # Excluded directories from the FSLogix containers path.
$DaysInactive               = 90                                        # Days of inactivity before FSLogix containers are removed. 
$DeleteDisabled             = 1                                         # Delete containers from disabled users.
$DeleteNotExisting          = 1                                         # Delete containers from not existing users.
$DeleteInactive             = 1                                         # Delete containers from inactive users.
$FlipFlopEnabled            = 1                                         # When 1 the default naming convention of the folders is used.
$DryRun                     = 1                                         # Override switch, nothing will be deleted, script will also output user names and what will be deleted. 

# Script Start
$PotentialSpaceReclamation  = 0
$SpaceReclaimed             = 0
$SpaceDisabled              = 0
$SpaceNotExisting           = 0
$SpaceInactive              = 0 
$Counter                    = 0  

If ($DryRun -eq 1) {Write-Host "!! DryRun Active, nothing will be deleted !!" -ForegroundColor Green -BackgroundColor Blue} Else {
    Write-Host "!! DryRun NOT Active, containers will be deleted !!" -ForegroundColor Red -BackgroundColor White
    Write-Host -nonewline "Continue? (Y/N) "
    $Response = Read-Host
    If ($Response -ne "Y") {EXIT}
}

$PathItems = Get-ChildItem -Path "$($FSLogixPath)" -Directory -Exclude $ExcludeFolders

Foreach ($PathItem in $PathItems) {
    If ($FlipFlopEnabled -eq 1) {$UserName = $PathItem.Name.Substring(0,$PathItem.Name.IndexOf('_S-1-5'))}
    If ($FlipFlopEnabled -eq 0) {$UserName = $PathItem.Name.Substring($PathItem.Name.IndexOf('_') + 1)}
    Write-Host $UserName
    $Counter ++
    Try { 
        $Information = Get-ADUser -Identity $UserName -Properties sAMAccountName, Enabled, lastLogon, lastLogonDate
        If ($False -eq $Information.Enabled) {
            If ($DryRun -eq 1 ) {Write-host "User $UserName is disabled."}
            $PotentialSpaceReclamation = $PotentialSpaceReclamation + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
            $SpaceDisabled = $SpaceDisabled + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
            If ($DeleteDisabled -eq 1) {
                Write-Host "Deleting containers from $UserName" -ForegroundColor Red
                $SpaceReclaimed = $SpaceReclaimed + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
                If ($DryRun -ne 1) {Remove-Item -Path $PathItem -Recurse -Force}
            }
        }
        ElseIf ($Information.lastLogonDate -lt ((Get-Date).Adddays( - ($DaysInactive)))) {
            If ($DryRun -eq 1 ) {Write-Host "User $UserName is more than $DaysInactive days inactive."}
            $PotentialSpaceReclamation = $PotentialSpaceReclamation + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
            $SpaceInactive = $SpaceInactive + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
            If ($DeleteInactive -eq 1) {
                Write-Host "Deleting containers from $UserName" -ForegroundColor Red
                $SpaceReclaimed = $SpaceReclaimed + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
                If ($DryRun -ne 1) {Remove-Item -Path $PathItem -Recurse -Force}
            }
        }
    }
    Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        If ($DryRun -eq 1 ) { Write-Host "User $UserName doesn't exist." }
        $PotentialSpaceReclamation = $PotentialSpaceReclamation + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
        $SpaceNotExisting = $SpaceNotExisting + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
        If ($DeleteNotExisting -eq 1) {
            Write-Host "Deleting containers from $UserName" -ForegroundColor Red
            $SpaceReclaimed = $SpaceReclaimed + (Get-ChildItem -Path "$PathItem" | Measure Length -Sum).Sum / 1Gb
            If ($DryRun -ne 1) {Remove-Item -Path $PathItem -Recurse -Force}
        }
    }
}

$PotentialSpaceReclamation = "{0:N2} GB" -f $PotentialSpaceReclamation
$SpaceReclaimed = "{0:N2} GB" -f $SpaceReclaimed
$SpaceDisabled = "{0:N2} GB" -f $SpaceDisabled
$SpaceNotExisting = "{0:N2} GB" -f $SpaceNotExisting
$SpaceInactive = "{0:N2} GB" -f $SpaceInactive

Write-Host "========================================="
Write-Host "Processed Container Folderss:"$Counter
If ($DryRun -eq 1) {Write-Host "Potential $PotentialSpaceReclamation can be reclaimed."}
Write-Host "Disabled users are claiming $SpaceDisabled"
Write-Host "Not Existing users are claiming $SpaceNotExisting"
Write-Host "Inactive users are claiming $SpaceInactive" 
Write-Host "$SpaceReclaimed total reclaimed."