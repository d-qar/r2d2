param(
    [string]$a,
    [string]$e,
    [string]$z,
    [string]$f,
    [string]$s,
    [string[]]$p)

###############################################################################################

############################################## Functions ######################################

function WriteLog {
    Param ([string]$Type, [string]$LogString)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    
    if ($Type -eq "i") {
        Write-Host -ForegroundColor Green $LogMessage 
    }
    elseif ($Type -eq "w") {
        Write-Host -ForegroundColor Yellow $LogMessage 
    }
   
}
Function createStorageContainer {  
    Param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$ctx,
        [string]$sacName,
        [string]$fsName,
        [string]$rsg
    )
    WriteLog "i"  "Creating storage container"  
 
    if (Get-AzStorageContainer -Name $fsName -Context $ctx -ErrorAction SilentlyContinue) {  
        WriteLog "w" "$fsName - container already exists."  
    }  
    else {  
        #WriteLog "i" "$fsName- container does not exist."   
        ## Create a new Azure Storage Account Container
        (New-AzStorageContainer -Name $fsName -Context $ctx -Permission Off).Name
        #WriteLog "i" "$fsName - container created."  
    }       
}
Function createFolders {
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$ctx,
        [string]$fsName,
        [string[]]$dirs
    )
    foreach ($dir in $dirs) {
        if ( Get-AzDataLakeGen2Item -Context $ctx -FileSystem $fsName -Path $dir -ErrorAction SilentlyContinue) {
            WriteLog "w" "$dir - folder already exist"
        }
        else {            
            (New-AzDataLakeGen2Item -Context $ctx -FileSystem $fsName -Path $dir -Directory).Path
        }
        
    }
    
    
}
Function setACLsBase {
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$ctx,
        [string]$entityID,
        [string]$flsName,
        [string[]]$Paths
    )
    $permissions = "--x"
    $aclroot = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $flsName).ACL;
    $aclroot = set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $entityID -Permission $permissions -InputObject $aclroot;
    Update-AzDataLakeGen2Item -Context $ctx -FileSystem $flsName -Acl $aclroot;

    ForEach ($dirname in $Paths) {
        $acl = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $flsName -Path $dirname).ACL;
        $acl = set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $entityID -Permission $permissions -InputObject $acl;     
        Update-AzDataLakeGen2Item -Context $ctx -FileSystem $flsName -Path $dirname -Acl $acl;
        
    }
    
}
Function setACLsDefault {
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$ctx,
        [string]$entityID,
        [string]$flsName,
        [string[]]$Paths
    )
    
    $permissions = "rwx";


    ForEach ($dirname in $Paths) {
        $acl = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $flsName -Path $dirname).ACL
        $acl = set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $entityID -Permission $permissions -DefaultScope -InputObject $acl     
        Update-AzDataLakeGen2Item -Context $ctx -FileSystem $flsName -Path $dirname -Acl $acl
    }
}
Function setACLsTable {
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$ctx,
        [string]$entityID,
        [string]$flsName,
        [string[]]$Paths
    )

    $permissions = "rwx";

    $acl = set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $entityID -Permission $permissions;	
    $acldefault = set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $entityID -Permission $permissions -DefaultScope;	

    ForEach ($dirname in $Paths) {		
        Update-AzDataLakeGen2AclRecursive -Context $ctx -FileSystem $filesystemName -Path $dirname -Acl $acl;
    }

    ForEach ($dirname in $Paths) {
        #$acldefault = set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $userID -Permission $permissions -DefaultScope;	
        Update-AzDataLakeGen2AclRecursive -Context $ctx -FileSystem $filesystemName -Path $dirname -Acl $acldefault;
    }
        
}

###############################################################################################

############################################## Init script ####################################

$resourceGroupName = "RSGREU2YADL" + $e + "01"
$serviceprincipalName = $s
$filesystemName = $f
$pathDirs = $p
$z

if ($z -eq "udv" -or $z -eq "rdv") { $storageName = "adlseu2yadlback" + $e + "02" }
elseif ($z -eq "ddv") { $storageName = "adlseu2yadlback" + $e + "04" }
elseif ($z -eq "edv") { $storageName = "adlseu2yadlback" + $e + "03" }
elseif ($z -eq "idv") { $storageName = "adlseu2yadlback" + $e + "05" }
elseif ($z -eq "stg") { $storageName = "adlseu2yadlback" + $e + "01" }
else { throw "Invalid Zone: $z" }


WriteLog "i" "Initializing DTI-APP-YADL-YAPE DATA LAKE Subscription"

Set-AzContext -SubscriptionId 75d56e05-437c-4d16-8aae-6b70ff5bfc33

WriteLog "i" "Obtaining Storage Account key"

$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageName)[0].Value

WriteLog "i" "Connect to Storage account: $storageName"

$context = New-AzStorageContext -StorageAccountName $storageName -StorageAccountKey $storageKey;

WriteLog "i" "Get service principal ID : $serviceprincipalName" 

$userID = az ad sp list  --display-name $serviceprincipalName --query [0].id --out tsv

createStorageContainer $context $storageName $filesystemName $resourceGroupName

WriteLog "i" "creating folders: $pathDirs"

createFolders $context $filesystemName $pathDirs
if ($a -eq "b") {
    setACLsBase $context $userID $filesystemName $pathDirs
}
elseif (($a -eq "d")) {
    setACLsDefault $context $userID $filesystemName $pathDirs
}
elseif (($a -eq "t")) {
    setACLsTable $context $userID $filesystemName $pathDirs  
}
else { throw "Invalid Type deploy: $a" }
