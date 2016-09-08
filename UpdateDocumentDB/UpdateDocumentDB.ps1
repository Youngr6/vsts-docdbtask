$sourceFile = Get-VstsInput -Name sourceFile -Require
$accountName  = Get-VstsInput -Name accountName -Require
$connectionKey = Get-VstsInput -Name connectionKey -Require
$collectionName = Get-VstsInput -Name collectionName -Require
$databaseName = Get-VstsInput -Name databaseName -Require
$scriptArguments = Get-VstsInput -Name scriptArguments 

Write-host ("Account " + $accountName)
Write-host ("Database  " + $databaseName)
Write-host ("Collection " + $collectionName)


    Write-Verbose -Verbose "Starting DocumentDB Document Deploy step"

    function GetKey([System.String]$Verb = '',[System.String]$ResourceId = '',
            [System.String]$ResourceType = '',[System.String]$Date = '',[System.String]$masterKey = '') {
        $keyBytes = [System.Convert]::FromBase64String($masterKey) 
        $text = @($Verb.ToLowerInvariant() + "`n" + $ResourceType.ToLowerInvariant() + "`n" + $ResourceId + "`n" + $Date.ToLowerInvariant() + "`n" + "" + "`n")
        $body =[Text.Encoding]::UTF8.GetBytes($text)
        $hmacsha = new-object -TypeName System.Security.Cryptography.HMACSHA256 -ArgumentList (,$keyBytes) 
        $hash = $hmacsha.ComputeHash($body)
        $signature = [System.Convert]::ToBase64String($hash)

        [System.Web.HttpUtility]::UrlEncode($('type=master&ver=1.0&sig=' + $signature))
    }

    function GetUTDate() {
        $date = get-date
        $date = $date.ToUniversalTime();
        return $date.ToString("r", [System.Globalization.CultureInfo]::InvariantCulture);
    }

    function GetDatabases() {
        $uri = $rootUri + "/dbs"

        $hdr = BuildHeaders -resType dbs

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $hdr
        $response.Databases

        Write-Host ("Found " + $Response.Databases.Count + " Database(s)")

    }

    function GetCollections([string]$dbname){
        $uri = $rootUri + "/" + $dbname + "/colls"
        $headers = BuildHeaders -resType colls -resourceId $dbname
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        $response.DocumentCollections
        Write-Host ("Found " + $Response.DocumentCollections.Count + " DocumentCollection(s)")
   }

    function BuildHeaders([string]$action = "get",[string]$resType, [string]$resourceId){
        $authz = GetKey -Verb $action -ResourceType $resType -ResourceId $resourceId -Date $apiDate -masterKey $connectionKey
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $authz)
        $headers.Add("x-ms-version", '2015-12-16')
        $headers.Add("x-ms-date", $apiDate) 
        $headers
    }

    function PostDocument([string]$document, [string]$dbname, [string]$collection){
        $collName = "dbs/"+$dbname+"/colls/" + $collection
        $headers = BuildHeaders -action Post -resType docs -resourceId $collName
        $headers.Add("x-ms-documentdb-is-upsert", "true")
        $uri = $rootUri + "/" + $collName + "/docs"
    
        Write-host ("Calling " + $uri)
#        write-host $authz
#        write-host $apiDate

        $response = Invoke-RestMethod $uri -Method Post -Body $json -ContentType 'application/json' -Headers $headers
        $response
    }


    $rootUri = "https://" + $accountName + ".documents.azure.com"
    write-host ("Root URI is " + $rootUri)

    #validate arguments

    $apiDate = GetUTDate

    $db = GetDatabases | where { $_.id -eq $databaseName }

    if ($db -eq $null) {
        write-error "Could not find database in account"
        return
    } 

    $dbname = "dbs/" + $databaseName
    $collection = GetCollections -dbname $dbname | where { $_.id -eq $collectionName }
    
    if($collection -eq $null){
        write-error "Could not find collection in database"
        return
    }

    $json = Get-Content -Path $sourceFile
    PostDocument -document $json -dbname $databaseName -collection $collectionName

    Write-Verbose -Verbose "Leaving DocumentDB Document Deploy step"







