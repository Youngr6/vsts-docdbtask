#Calling DocumentDB's REST API using PowerShell 

As well as giving you the right information for calling the DocumentDB APIs from Powershell, this description also gives a basis for being able to call any RESTful web API from a Powershell script – which is particularly useful for things like creating custom VSTS Build and Release tasks.

The task we needed  to achieve was to be able to create or update a .json formatted document in an Azure DocumentDB collection, from Powershell.  There is plenty of [documentation](https://msdn.microsoft.com/en-GB/library/azure/dn781481.aspx) covering the API itself, however I did it a little sparse at times – but the example POSTs and corresponding Http responses are useful.  DocumentDB has a hierarchical object structure, starting with the Account as the main container, which holds Databases, which hold Collections, which contain your Documents.

![Hierarchy](/doc/img/documentdb-hierarchy.png)

So, in order to create or update a document, we need to connect to and authenticate with the Account, then validate that the Database exists in the account, and that the Collection exists within the Database, then we can make the call to the Document API to Create the document.
##Authentication
My strategy is to use the Azure DocumentDB master keys to carry out this operation.  The task is going to be part of a release management process, so the key can be stored securely (secret string) as an environment variable in VSTS’s Release configuration, and can therefore be managed as part of the ops team’s key rotation process.

![Keys](/doc/img/keys.png)

Choose either primary or secondary key from the Keys blade.  In the image below you can see this DocumentDB account name is “calibredocdb” – this is the name the script will expect and use to locate the resources when building the URI.

![Keys2](/doc/img/keys2.png)

DocumentDB’s API requires an[HTTP Authorization header](https://msdn.microsoft.com/en-us/library/azure/dn783368.aspx) to be built that is specific to the kind of resource you’re about to access.  The header is a base64 string made by combining several values as a signature and hashing it.  I had a few problems getting this to work, but the main issue was trying to figure out what the ResourceType and ResourceId should be, making sure the keys used to form the signature were in the right case (generally lower), and getting the date format right.  The biggest help in debugging failures was the response from the API, which tells you what keys it was expecting the Authorization header to be signed with.  Make sure these values match the values you’re building your key with and it should work fine.

``` 
StringToSign = HTTPVerb.ToLower() + “\n” 
+ ResourceType.ToLower() + “\n” 
+ ResourceId + “\n” 
+ (headers["x-ms-date"] || "").ToLower() + "\n" 
+ (headers["date"] || "").ToLower() + "\n"
```


- HTTPVerb is easy – That’s Get, Post, Put, etc depending on the type of call you want to make.
- [ResourceType](https://azure.microsoft.com/en-gb/documentation/articles/documentdb-resources/) – this is a short name for the kind of resource/api you want to call, which can be blank (to access top level resources in the account, like enumerating the databases), or one of
- dbs, colls, docs, colls, users, permissions, sprocs, triggers, functions, attachments
- ResourceId – this is the URI for the resource you want to access, eg. /dbs/mydatabase/colls/configdocs might be the ResourceId if I was wanting to create a document in the configdocs collection.
- x-ms-date – has to be close to current date/time, and has to match the value inserted into your headers, and also has to be in a specific format - $date.ToString("ddd, d MMM yyyy HH:mm:ss \G\M\T")
- date – optionally add the same date/time again in the same format:

```
function GetUTDate() {
 $date = get-date
 $date = $date.ToUniversalTime();
 return $date.ToString("ddd, d MMM yyyy HH:mm:ss \G\M\T")
}
```

Here’s the Powershell code to put the signature together.  Note that most of the values are converted to lower case, apart from the resource Id.  Also, the string returned is the full Authorization header for the call, ie. it includes the type (<strong>master </strong>means use master key), <strong>version </strong>is 1.0, and <strong>sig </strong>is the hashed signature.

The whole string is also UrlEncoded.

```
 
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
 
```

##Making the RESTful calls
Now the Authorization header is sorted, we need to add the other common HTTP headers for each call.  The three headers required are:

- Authorization (as above)
- x-ms-version (dated version of the API to call)
- x-ms-date (current UTC date time in the same format as used in the signature)

Here’s the function we’re going to call before each REST call, which will build the authorization header, then add it and the other two.  Note that some calls, like POSTing a new document to a collection, has some optional other headers which control some of the features of the method call.

``` 
    function BuildHeaders([string]$action = "get",[string]$resType, [string]$resourceId){
        $authz = GetKey -Verb $action -ResourceType $resType -ResourceId $resourceId -Date $apiDate -masterKey $connectionKey
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $authz)
        $headers.Add("x-ms-version", '2015-12-16')
        $headers.Add("x-ms-date", $apiDate) 
        $headers
    }
```

##Querying the Databases in an account, and Collections in a Database
Now we have all the building blocks, getting a list of resources is simple:

``` 
   function GetDatabases() {
        $uri = $rootUri + "/dbs"
        $hdr = BuildHeaders -resType dbs

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $hdr
        $response.Databases

        Write-Host ("Found " + $Response.Databases.Count + " Database(s)")
    }
```

The above is an HTTP GET call to the account’s “dbs” collection (ResourceType = “dbs”, and returns the list of Databases as a collection of objects.

```
 
    function GetCollections([string]$dbname){
        $uri = $rootUri + "/" + $dbname + "/colls"
        $headers = BuildHeaders -resType colls -resourceId $dbname
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        $response.DocumentCollections
        Write-Host ("Found " + $Response.DocumentCollections.Count + " DocumentCollection(s)")
   }
 
```

And this one queries the database’s “colls” resource list in a similar way.
##Creating a new document
The call to Post a new document is slightly different, in that it’s an HTTP POST call instead of a GET, and we’re adding a new header to indiciate that if a document with the same id already exists, we want to update it rather than return a Conflict error (“Upsert” the record).

```
 
   function PostDocument([string]$document, [string]$dbname, [string]$collection){
        $collName = "dbs/"+$dbname+"/colls/" + $collection
        $headers = BuildHeaders -action Post -resType docs -resourceId $collName
        $headers.Add("x-ms-documentdb-is-upsert", "true")
        $uri = $rootUri + "/" + $collName + "/docs"
    
        $response = Invoke-RestMethod $uri -Method Post -Body $document -ContentType 'application/json' -Headers $headers
        $response
    }
 
```

The return value ($response) is the document record (metadata) which includes the internal id of the document.
##Putting it all Together
Here is the complete script:

```
 
param
(
    [System.String]$sourceFile = '',
    [System.String]$accountName  = '',
    [System.String]$connectionKey = '',
    [System.String]$collectionName = '',
    [System.String]$databaseName = ''
)

begin
{

    function GetKey([System.String]$Verb = '',[System.String]$ResourceId = '',
            [System.String]$ResourceType = '',[System.String]$Date = '',[System.String]$masterKey = '') {
        $keyBytes = [System.Convert]::FromBase64String($masterKey) 
        $text = @($Verb.ToLowerInvariant() + "`n" + $ResourceType.ToLowerInvariant() + "`n" + $ResourceId + "`n" + $Date.ToLowerInvariant() + "`n" + "`n")
        $body =[Text.Encoding]::UTF8.GetBytes($text)
        $hmacsha = new-object -TypeName System.Security.Cryptography.HMACSHA256 -ArgumentList (,$keyBytes) 
        $hash = $hmacsha.ComputeHash($body)
        $signature = [System.Convert]::ToBase64String($hash)

        [System.Web.HttpUtility]::UrlEncode($('type=master&ver=1.0&sig=' + $signature))
    }

    function GetUTDate() {
        $date = get-date
        $date = $date.ToUniversalTime();
        return $date.ToString("ddd, d MMM yyyy HH:mm:ss \G\M\T")
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
    
        $response = Invoke-RestMethod $uri -Method Post -Body $document -ContentType 'application/json' -Headers $headers
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

}
```

###Resources

(My blog post about this)[https://russellyoung.net/2016/06/18/managing-documentdb-with-powershell/]