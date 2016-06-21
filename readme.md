#VSTS Build and Release extension tasks

The VSTS vNext Build and Release systems are a huge improvement in terms of usability and maintainability on the previous XAML based system.  
Ive published a [walkthrough](https://russellyoung.net/2016/04/15/arm-cd-vsts/) that shows how to use the Build and Release systems to create a continuous delivery process to deploy Azure resource groups using the built in tasks.  
This page will walk through how to create your own VSTS build or release tasks, and how to install or publish them to other VSTS accounts.

![DocDBTask](/doc/img/docdbtask-1.png)

If you need to do something that’s not specifically covered by one of the existing tasks, then you need to resort to adding one or more generic “run Powershell script” tasks.  The inputs will be all text only, entered as a string in the build tasks UI – these cant be validated at the time you’re editing the task at all, and to find out what parameters are expected, you need to inspect or know the Powershell script you’re running pretty well.  Also, a build or release definition that consists of one or many generic Powershell script tasks is harder to maintain, and when you come to look at the definition for the first time, it’s not going to be easy to find out what the script does, without going into the script behind each task.

These kinds of VSTS extension can consist of Powershell or javascript (or both) – bear in mind that if you want to target cross platform build agents, you need to use js instead of Powershell, which will only run on Windows agents.

This walkthrough packages up the DocumentDB deploy document powershell task which stores the configuration file data for each of the environments, as documented [here](/buildtasks/tasks/UpdateDocumentDB/docdb-posh.md) (rather than manage files as part of the code deployment).  As such, they need to be able to deploy an environment-specific configuration .json document to a DocumentDB as part of their build/release management process.

DocumentDB currently doesn’t have Powershell cmdlets to do what we need to achieve:
- Connect to the DocumentDB  
- enumerate the Databases to check the target exists  
- enumerate the Database’s _Collections_ for the same reason  
- Create or Update the document in question. 
 
How the DocumentDB updates are done is covered in the UpdateDocumentDB readme.  This readme focuses on how to create and publish the task.

##Folder structure
![Files](/doc/img/tasks-files.png)  

|Path|Description|
|----|----|
|vss-extension.json|Manifest file that describes the package, required by the marketplace|
|*.vsix|Output installation file (upload this to the publish page to make available to other accounts)|
|images|Icons used in the marketplace, and when displaying the package in VSTS accounts to end users|
|UpdateDocumentDB|Folder containing assets to publish for a specific task|
|UpdateDocumentDB/ps_modules|Required to integrate with VSTS|
|UpdateDocumentDB/icon.png|Icon for the task (used in Build/Release Configuration Builder)|
|UpdateDocumentDB/task.json|Manifest file describing the task|
|UpdateDocumentDB/UpdateDocumentDB.ps1|The powershell for the actual task|

##Task Manifest
The task manifest is fairly straightforward.  The  `"category": "Deploy"`, parameter tells VSTS which group you want your task to appear in when adding a build or release step.
The most important parts of the manifest are the inputs, which form the UI for the build step inside VSTS, and the execute step, which tells the build agent what to do when it's being run - in this case, we just want it to call our powershell script.

```
 "execution": {
    "PowerShell3": {
      "target": "$(currentDirectory)\\UpdateDocumentDB.ps1",
      "argumentFormat":"",
      "workingDirectory":"$(currentDirectory)"
    }
  }
  ```

The parameters from the UI build step configuration will be passed into the powershell script, which uses the VSTS Tasks SDK to receive and map to parameters, eg. to 
read the "sourceFile" input into a $sourceFile parameter in my script, I'd use the following:

```
$sourceFile = Get-VstsInput -Name sourceFile -Require
```

To deploy the build task alone directly into your own VSTS account (you must have the correct rights over the account to be able to do this). 
You will need a Personal access token (PAT) to complete this step.  PATs can be created by logging into your VSTS account online, clicking your logged in name (top right), selecting "My Security" then selecting Add under Personal Access tokens.

```
tfx build tasks upload --task-path UpdateDocumentDB --service-url https://<your-account>.visualstudio.com/DefaultCollection

TFS Cross Platform Command Line Interface v0.3.21
Copyright Microsoft Corporation
> Personal access token:

Task at C:\dev\Repos\DevOps\BuildTasks\Tasks\UpdateDocumentDB uploaded successfully!

```

To package one or more tasks and prepare an installer to share to other accounts, you must create a VSIX file:

```
tfx extension create --manifest-globs vss-extension.json

TFS Cross Platform Command Line Interface v0.3.21
Copyright Microsoft Corporation
Could not determine content type for extension .psd1. Defaulting to application/octet-stream. To override this, add a contentType property to this file entry in the manifest.
Could not determine content type for extension .psm1. Defaulting to application/octet-stream. To override this, add a contentType property to this file entry in the manifest.

=== Completed operation: create extension ===

```
The publishing site can be accessed using the URL
```
https://marketplace.visualstudio.com/manage/publishers/<publisherid>
```
Go to `https://marketplace.visualstudio.com/` and choose "Publish an extension" from the bottom navigation footer, and create a new publisher if you haven't published before.




###Resources

https://github.com/colindembovsky/cols-agent-tasks/blob/master/extension-manifest.json
http://colinsalmcorner.com/post/developing-a-custom-build-vnext-task-part-1
http://colinsalmcorner.com/post/developing-a-custom-build-vnext-task-part-2

https://github.com/Microsoft/vsts-task-lib
https://www.visualstudio.com/en-us/docs/integrate/extensions/develop/add-build-task
https://www.visualstudio.com/docs/integrate/extensions/develop/manifest#contributiontypes
https://blogs.msdn.microsoft.com/visualstudioalm/2016/04/26/authoring-vs-team-services-extension-with-buildrelease-tasks/



