#UpdateDocumentDB Build/Release Task

This folder contains the source for creating a VSTS extension Build/Release task for creating or updating documents within an existing Azure DocumentDB resource.

This is a Powershell task, and the source will validate the DocumentDB and Collection before attempting to upload your document from the source folder (Build) or your published artifact (Release).

To install the task directly into your VSTS account, you can use the following TFX command line:

```
\DevOps\BuildTasks\Tasks> tfx build tasks upload --task-path UpdateDocumentDB --service-url https://ehieu.visualstudio.com/DefaultCollection
TFS Cross Platform Command Line Interface v0.3.21
Copyright Microsoft Corporation
> Personal access token:

Task at \DevOps\BuildTasks\Tasks\UpdateDocumentDB uploaded successfully!
```
Note the Personal Access Token needs to be generated in VSTS - Login > click on your login name (top right) > My Security - save the PAT somewhere as the TFX tools asks for it frequently.

In order to publish the task to other VSTS accounts, you must either be an administrator with the correct permissions, or you can package and publish the task to the VSTS Marketplace, and then Share it with other accounts:

To create the VSIX File:
```
\DevOps\BuildTasks\Tasks>tfx extension create --manifest-globs vss-extension.json
TFS Cross Platform Command Line Interface v0.3.21
Copyright Microsoft Corporation
Could not determine content type for extension .psd1. Defaulting to application/octet-stream. To override this, add a contentType property to this file entry in the manifest.
Could not determine content type for extension .psm1. Defaulting to application/octet-stream. To override this, add a contentType property to this file entry in the manifest.

=== Completed operation: create extension ===
 - VSIX: \DevOps\BuildTasks\Tasks\russellyoung.russellyoung-docdbpublish-1.0.0.vsix
 - Extension ID: russellyoung-docdbpublish
 - Publisher: russellyoung
```
Then upload to your publisher portal, eg.  https://marketplace.visualstudio.com/manage/publishers/russellyoung

