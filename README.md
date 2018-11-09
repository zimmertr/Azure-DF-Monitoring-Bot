# Data.Factory.Bot

## Project Summary
Data Factory Bot is a small PowerShell script that leverages the PowerShell modules AzureRM and PSSlack.

The bot will request credentials to log into a Prod account on Azure with read access to the Data Factory. When this has been satisfied, the bot will use the cmdlet `Get-AzureRmDataFactoryRun` to retrieve information about the most recent Data Factory Run. This information is shaped and, if the duration was longer than the longest historical duration, is saved to said data file.

Some information about the Data Factory is then relied to the PowerShell window. A demonstration can be seen below:

```
----------------------------------
Report Sent at:  13:20:43.4733721
Data Factory Copy Duration Report
Copy Start:  1:06:16 PM
Copy End:  1:08:50 PM
Copy Duration:  154 seconds
Longest copy since last run:  195 seconds
----------------------------------
```

After this, the bot constructs a Slack message that leverages an attachment to relay information. A different message is generated based on the severity of the duration of the copy. Depending on the severity of the copy duration, this message is then shipped to the Slack API via a legacy token. If the message is of HIGH criticality then the members that belong to the Slack channel are alerted. 
