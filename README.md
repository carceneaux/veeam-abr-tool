# Veeam AsBuiltReport "Quickstart" Configuration Tool

[As Built Report](https://www.asbuiltreport.com/) is an open source configuration document framework which utilises Microsoft PowerShell to produce as-built documentation in multiple document formats for multiple vendors and technologies. The framework allows users to easily generate clear and consistent documentation, for any environment which supports Microsoft PowerShell and/or a RESTful API.

The [veeam-abr-tool.ps1](veeam-abr-tool.ps1) PowerShell script, included in this repository, provides a "quickstart" to leveraging AsBuiltReport to generate a Veeam Backup & Replication report while having little to no knowledge of AsBuiltReport and/or PowerShell itself. Running the script will perform the following actions:

* Installation of required PowerShell modules
* Creation of the AsBuiltReport configuration file
* Creation of the AsBuiltReport Veeam.VBR report configuration file
* Generation of an AsBuiltReport Veeam Backup & Replication report

## Downloading & running the script

> **Note**
> The below steps **must** be performed on the server where Veeam Backup & Replication is installed.

1. Open PowerShell ensuring that you are using an [administrative shell](https://www.howtogeek.com/194041/how-to-open-the-command-prompt-as-administrator-in-windows-8.1/)
2. The below code can be used to download the script to the current user's desktop and execute it:

```powershell
cd $([Environment]::GetFolderPath("Desktop"))
Start-BitsTransfer "https://raw.githubusercontent.com/carceneaux/veeam-abr-tool/master/veeam-abr-tool.ps1"
.\veeam-abr-tool.ps1
```

Once the script has been executed, it will then interactively ask for information. Here's a sample of the recommended responses:

1. *Enter the name of the Author for this As Built Report []:* `<Full name of person generating this report>`
2. *Would you like to enter Company information for the As Built Report? (y/n):* `y`
3. *Enter the Full Company Name:* `<Company name>`
4. *Enter the Company Short Name:* `<leave blank>`
5. *Enter the Company Contact:* `<leave blank>`
6. *Enter the Company Email Address:* `<leave blank>`
7. *Enter the Company Phone:* `<leave blank>`
8. *Enter the Company Address:* `<leave blank>`
9. *Would you like to enter SMTP configuration? (y/n):* `n`
10. *Would you like to save the As Built Report configuration file? (y/n):* `y`
11. *Enter a name for the As Built Report configuration file []:* `<leave blank>`
12. *Enter the path to save the As Built Report configuration file []:* `<leave blank>`
13. *Enter the full path of the folder to use for storing the configuration files []:* `<leave blank>`

Advanced configuration options are also available. To learn more, access the scripts built-in documentation:

```powershell
Get-Help .\veeam-abr-tool.ps1 -Full
```

## 🤝🏾 License

* [MIT License](LICENSE)

## 🤔 Questions

If you have any questions or something is unclear, please don't hesitate to [create an issue](https://github.com/carceneaux/veeam-abr-tool/issues/new/choose) and let us know!
