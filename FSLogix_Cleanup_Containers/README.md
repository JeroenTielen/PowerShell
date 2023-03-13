# FSLogix_Cleanup_Containers

This script checks the path where FSLogix containers are stored. For each folder it will check the active directory for the status of the specific useraccount.
    The following checks will be performed: 

        1. Does the user still exists? 
        2. Is the user disabled? 
        3. What is the last logon date? 

# There are a couple of variables to set to tune the script for your needs: 
   
        1. $FSLogixPath       : The location where the containers are stored.
        2. $ExcludeFolders    : Is the location has folders which must not be processed you can add them here.
        3. $DaysInactive      : Minimum amount of days when the last logon occured.
        4. $DeleteDisabled    : Set this to 0 or 1. 0 will NOT delete conainters from disabled user accounts. 1 will ;) 
        5. $DeleteNotExisting : When an user is deleted and the conainers aren't deleted set this to 1 and the containers will be deleted.
        6. $DeleteInactive    : Users with a last logon longer the the $DaysInactive will be deleted if this is set to 1. 
        7. $FlipFlopEnabled   : Set this to 0 when the containers are stored in a folder starting with the user SID. When the folder starts with the username set this to 1. 
        8. $DryRun            : When this is set to 1, nothing will be deleted regardless the settings. This will also output more information which containers are claiming space.
        
## Syntax

Open script in your PowerShell editor (Visual Studio Code, PowerShell ISE, etc), change the paramters and run, 
