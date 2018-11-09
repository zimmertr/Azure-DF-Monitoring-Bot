######################################################################################################
######################################################################################################
##########################################DATA.FACTORY.BOT############################################
######################################################################################################
######################################################################################################
##  Data Factory Bot is a small PowerShell script that leverages the PowerShell modules AzureRM and ##
##  PSSlack.                                                                                        ##
##                                                                                                  ##
##  The bot will request credentials to log into a Prod account on Azure with read access to the    ##
##  Data Factory. When this has been satisfied, the bot will use the cmdlet                         ##
##  `Get-AzureRmDataFactoryRun` to retrieve information about the most recent Data Factory Run. This##
##  information is shaped and, if the duration was longer than the longest historical duration, is  ##
##  saved to said data file.                                                                        ##
######################################################################################################
######################################################################################################
$ErrorActionPreference = 'Stop'
$SlackToken = '>TOKEN<'
$SlackChannel = '>CHANNEL<'
$ResourceGroup = '>RESOURCEGROUP<'
$SubscriptionID = '>SUBSCRIPTIONID<'
$DataFactoryname = '>DATAFACTORY<'
$Dataset = '>DATASETNAME<'


#Create logs directory if it doesn't exist.
if ($(Test-Path .\logs\) -eq $false){
   
    New-Item -ItemType Directory .\logs\

}

#Rotate logs
if ($(Test-Path .\logs\output.log) -eq $true){
   
    Add-Content .\logs\output.log -value "$(Get-Date) - New run detected. Rotating log file."
    Move-Item .\logs\output.log -Destination .\logs\last_run.log -Force
    
    #Create new log file.
    New-Item -ItemType File .\logs\output.log -Force

}

clear
Write-Host "*** The Data Factory Bot has been initialized ***"
Add-content .\logs\output.log -value "$(Get-Date) - Bot initiated."


######################################################################################################
##Log into Azure##
######################################################################################################
Add-content .\logs\output.log -value "$(Get-Date) - Logging into Azure."
try{

    Select-AzureRmSubscription -SubscriptionId $SubscriptionID > $null
    Write-Host "> You have already authenticated with Azure. Your active subscription was changed to dev."
    Add-content .\logs\output.log -value "$(Get-Date) - Already logged in. Subscription was set."
        
} catch {

    Write-Host "> You are not logged into Azure. Please log in now to continue." 
	Login-AzureRMAccount -SubscriptionID $SubscriptionID > $null
    Write-Host
   
    Write-Host "> Successfully logged in. Calculating last copy information..."
    Add-content .\logs\output.log -value "$(Get-Date) - Successfully logged in. Subscription was set."

}

Write-Host
Write-Host "> The bot will now pause until $((Get-Date).Hour):59. After which the bot will post hourly updates at ##:59."
Write-Host


######################################################################################################
##Pause until :59 after the hour##
######################################################################################################
Add-content .\logs\output.log -value "$(Get-Date) - Pausing until $((Get-Date).Hour):59"
While ($(get-date).Minute -ne 59){
   
    start-sleep -Seconds 60

}

Add-content .\logs\output.log -value "$(Get-Date) - $((Get-Date).Hour):59 has been reached. Starting infinite loop now."


######################################################################################################
##Start reporting loop to PowerShell and Slack##
######################################################################################################
While ($true) {
    #Get Last Data Factory Run Start and Stop Time
    $timeRange = New-TimeSpan -Minutes 60
    $startDateTime = $(Get-Date) - $timeRange

    $ProcessingStartTime = $(Get-AzureRmDataFactoryRun -DataFactoryName $DataFactoryname -DatasetName $dataset -StartDateTime $startDateTime -ResourceGroupName ResourceGroup | select ProcessingStartTime | Out-String).Trim().trim("ProcessingStartTime").trim().trim("-------------------").trim().split(' ')[1]
    Add-content .\logs\output.log -value "$(Get-Date) - Finding start time for previous run. - $ProcessingStartTime"
    $ProcessingEndTime = $(Get-AzureRmDataFactoryRun -DataFactoryName $DataFactoryname -DatasetName $dataset -StartDateTime $startDateTime -ResourceGroupName ResourceGroup | select ProcessingEndTime | Out-String).Trim().trim("ProcessingEndTime").trim().trim("-----------------").trim().split(' ')[1]
    Add-content .\logs\output.log -value "$(Get-Date) - Finding end time for previous run. - $ProcessingEndTime"
    Add-content .\logs\output.log -value "$(Get-Date) - Finding duration of previous run."
    
    #Ensure that Both StartTime and EndTime are instantiated. And that the EndTime isn't rolling over into the next 24 hour period to avoid a negative duration. 
    #If they're not, attempt to obtain them over and over until they are or 20 minutes is reached an an alert is sent to Slack. 
    $count=1
    While((!$ProcessingStartTime) -or (!$ProcessingEndTime) -or ($ProcessingEndTime.equals("11:59:59"))){

        $count++   
        Add-content .\logs\output.log -value "$(Get-Date) - Duration of previous run could not be calculated. The run probably hasn't completed yet. Sleeping for 1 minute."
        Start-Sleep -Seconds 60
        
        $ProcessingStartTime = $(Get-AzureRmDataFactoryRun -DataFactoryName $DataFactoryname -DatasetName $dataset -StartDateTime $startDateTime -ResourceGroupName ResourceGroup | select ProcessingStartTime | Out-String).Trim().trim("ProcessingStartTime").trim().trim("-------------------").trim().split(' ')[1]
        Add-content .\logs\output.log -value "$(Get-Date) - Finding start time for previous run. Attempt No. $count - $ProcessingStartTime"
        $ProcessingEndTime = $(Get-AzureRmDataFactoryRun -DataFactoryName $DataFactoryname -DatasetName $dataset -StartDateTime $startDateTime -ResourceGroupName ResourceGroup | select ProcessingEndTime | Out-String).Trim().trim("ProcessingEndTime").trim().trim("-----------------").trim().split(' ')[1]
        Add-content .\logs\output.log -value "$(Get-Date) - Finding end time for previous run. Attempt No. $count - $ProcessingEndTime"
        
        #If been trying to get duration for 15 minutes, add warning to log. 
        if($(Get-Date).minutes -gt 15){
           
            Add-Content .\logs\output.log -value "$(Get-Date) - Something might be wrong. Previous run is still not available after $(Get-Date).minutes minutes."
        
        }
        #If been trying to get duration for 20 minutes, add warning to log and alert Slack. 
        elseif($(Get-Date).minutes -gt 20){
        
            Add-Content .\logs\output.log -value "$(Get-Date) - Something is really wrong. Previous run is still not available after $(Get-Date).minutes minutes. Alerting Slack now."
            Add-content .\logs\output.log -value "$(Get-Date) - Processing durataion was greater than 20 minutes. Building custom slack message."

            $Fields = [pscustomobject]@{
                CopyStart = $ProcessingStartTime
                CopyEnd = $ProcessingEndTime
                TotalSeconds = $ProcessingDuration
                LongestCopy = $LongestDuration
                Severity = "High"
                DataFactoryURL = "https://goo.gl/#####"
            } | New-SlackField -Short

            Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been constructed. Sending slack message now."
            New-SlackMessageAttachment -Pretext "Hello, a strange exception was just thrown. Consider investigating it? <!channel>" -Fallback "Something went wrong." -Fields $Fields -Color $([System.Drawing.Color]::Red)| new-SlackMessage -Channel $SlackChanne -Username 'Data Factory Bot' -IconEmoji :exclamation: | Send-SlackMessage -Token $SlackToken > $null
            Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been successfully delivered."
            
            break
     
        }
    }

    #Calculate duration
    $ProcessingDuration = $(New-Timespan -start $ProcessingStartTime -End $ProcessingEndTime).TotalSeconds
    Add-content .\logs\output.log -value "$(Get-Date) - Duration was successfully calculated. - $ProcessingDuration"


    #Retrieve Longest Duration from File and compare to this run.
    #If data file doesn't exist, create it. 
    Add-content .\logs\output.log -value "$(Get-Date) - Attempting to read longest duration from file."
    try{
      
        $LongestDuration = [IO.File]::ReadAllLines(".\logs\longestDuration.dat")
        Add-Content .\logs\output.log -value "$(Get-Date) - File exists. Successfully imported the data."
    
    } catch {
        #Sleep to ensure that the file is closed before attempting to recreate or reread. 
        start-sleep -Seconds 5
       
        Add-content .\logs\output.log -value "$(Get-Date) - Longest duration file does not yet exist. Creating one now."
        Write-Host "> History file containing previous Longest Duration does not exist. Creating one now."
        New-Item .\logs\longestDuration.dat -ItemType file > $null
    
    }    
    
    Write-Host

    #Calculate longest duration. Update if necessary...
    If (!$LongestDuration){
    
        Add-content .\logs\output.log -value "$(Get-Date) - Longest duration was null. Instantiating with the value of the Processing Duration now."
        $LongestDuration = $ProcessingDuration
    
    }ElseIf (($LongestDuration -le $ProcessingDuration) -and ($LongestDuration)){
    
        Add-content .\logs\output.log -value "$(Get-Date) - Longest duration was less than the Processing duration for the last run. Updating longest duration now."
        $LongestDuration = $ProcessingDuration
    
    }Else{
    
        Add-content .\logs\output.log -value "$(Get-Date) - Longest duration is still longer than processing duration for the last run. Reading from file."
        $LongestDuration = [IO.File]::ReadAllLines(".\logs\longestDuration.dat")
    
    }
    
    #Save Longest Duration to file....
    Add-content .\logs\output.log -value "$(Get-Date) - Saving longest duration to file."
    $LongestDuration | Out-File .\logs\longestDuration.dat
    

    ######################################################################################################
    ##Report to PowerShell.##
    ######################################################################################################
    Add-content .\logs\output.log -value "$(Get-Date) - Reporting findings to PowerShell."
    Write-Host "----------------------------------"
    Write-Host "Report Sent at: " $(Get-Date).TimeOfDay
    Write-Host "Data Factory Copy Duration Report"
    Write-Host "Copy Start: " $ProcessingStartTime
    Write-Host "Copy End: " $ProcessingEndTime
    Write-Host "Copy Duration: $ProcessingDuration seconds"
    Write-Host "Longest copy since last run: " $LongestDuration "seconds"
    Write-Host "----------------------------------"
    Write-Host
    

    ######################################################################################################
    ##Report to log file.##
    ######################################################################################################
    Add-Content .\logs\output.log -value "----------------------------------"
    Add-Content .\logs\output.log -value "Report Sent at: $((Get-Date).TimeOfDay)"
    Add-Content .\logs\output.log -value "Data Factory Copy Duration Report"
    Add-Content .\logs\output.log -value "Copy Start: $ProcessingStartTime"
    Add-Content .\logs\output.log -value "Copy End: $ProcessingEndTime"
    Add-Content .\logs\output.log -value "Copy Duration: $ProcessingDuration seconds"
    Add-Content .\logs\output.log -value "Longest copy since last run: $LongestDuration seconds"
    Add-Content .\logs\output.log -value "----------------------------------"


    ######################################################################################################
    ##Report to Slack.##
    ######################################################################################################
    Add-content .\logs\output.log -value "$(Get-Date) - Entering Slack Reporting phase."
    
    #If Duration < 15 minutes.
    if ($ProcessingDuration -lt 900){
    
        Add-content .\logs\output.log -value "$(Get-Date) - Processing duration was less than 10 minutes. Doing nothing."

        $Fields = [pscustomobject]@{
            CopyStart = $ProcessingStartTime
            CopyEnd = $ProcessingEndTime
            TotalSeconds = $ProcessingDuration
            LongestCopy = $LongestDuration
            Severity = "Low"
            DataFactoryURL = "https://goo.gl/#####"
        } | New-SlackField -Short
        
        New-SlackMessageAttachment -Pretext "Data Factory Copy Duration Report." -Fallback "Data Factory Pipeline Copy Duration < 15 Minutes." -Fields $Fields -Color $([System.Drawing.Color]::Green)| new-SlackMessage -Channel '-testing' -Username 'Data Factory Bot' -IconEmoji :white_check_mark: | Send-SlackMessage -Token $SlackToken > $null
    
    }
    
    #If Duration > 15 minutes && < 20 minutes
    elseif ($ProcessingDuration -gt 899 -and $ProcessingDuration -lt 1200){
    
        Add-content .\logs\output.log -value "$(Get-Date) - Processing duration was between 10 and 20 minutes. Building custom slack message."

        $Fields = [pscustomobject]@{
            CopyStart = $ProcessingStartTime
            CopyEnd = $ProcessingEndTime
            TotalSeconds = $ProcessingDuration
            LongestCopy = $LongestDuration
            Severity = "Medium"
            DataFactoryURL = "https://goo.gl/#####"
        } | New-SlackField -Short

        Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been cosntructed. Sending slack message now."
        New-SlackMessageAttachment -Pretext "Data Factory Copy Duration Report: " -Fallback "Data Factory Pipeline Copy Duration > 10 Minutes." -Fields $Fields -Color $([System.Drawing.Color]::Yellow)| new-SlackMessage -Channel $SlackChanne -Username 'Data Factory Bot' -IconEmoji :warning: | Send-SlackMessage -Token $SlackToken > $null
        Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been sucessfully delivered."
    
    }
    
    #If Duration > 20 minutes
    elseif ($ProcessingDuration -gt 1199){
       
        Add-content .\logs\output.log -value "$(Get-Date) - Processing durataion was greater than 20 minutes. Building custom slack message."

        $Fields = [pscustomobject]@{
            CopyStart = $ProcessingStartTime
            CopyEnd = $ProcessingEndTime
            TotalSeconds = $ProcessingDuration
            LongestCopy = $LongestDuration
            Severity = "High"
            DataFactoryURL = "https://goo.gl/#####"
        } | New-SlackField -Short

        Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been constructed. Sending slack message now."
        New-SlackMessageAttachment -Pretext "Data Factory Copy Duration Report: WARNING! Copy duration > 20 minutes! <!channel>" -Fallback "Data Factory Pipeline Copy Duration > 20 Minutes." -Fields $Fields -Color $([System.Drawing.Color]::Red)| new-SlackMessage -Channel $SlackChanne -Username 'Data Factory Bot' -IconEmoji :exclamation: | Send-SlackMessage -Token $SlackToken > $null
        Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been successfully delivered."
    
    }
    
    #If something went wrong with this logic
    else{
    
        Add-content .\logs\output.log -value "$(Get-Date) - Something weird happened. Processing duration did not fall into any conditional checks. Building custom slack message."

        $Fields = [pscustomobject]@{
        CopyStart = $ProcessingStartTime
        CopyEnd = $ProcessingEndTime
        TotalSeconds = $ProcessingDuration
        LongestCopy = $LongestDuration
        Severity = "Unknown"
        DataFactoryURL = "https://goo.gl/#####"
        } | New-SlackField -Short

        Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been constructed. Sending Slack message now."
        New-SlackMessageAttachment -Pretext "Data Factory Copy Duration Report: WARNING! Something is amiss with the bot! <!channel>" -Fallback "Something went wrong." -Fields $Fields | new-SlackMessage -Channel $SlackChanne -Username 'Data Factory Bot' -IconEmoji :skull_and_crossbones: | Send-SlackMessage -Token $SlackToken > $null
        Add-content .\logs\output.log -value "$(Get-Date) - Custom Slack Message has been successfully delivered."
    
    }
    
    #Pause for 1 hour to await next copy pipeline.
    Add-content .\logs\output.log -value "$(Get-Date) - Slack reporting phase has completed. Pausing for one hour."
    Start-Sleep -Seconds 3600

    #If transitioning between days, wait an additional hour to avoid a negative timespan being returned.
    if ($(Get-Date).Hour -eq 0){
    
        Add-Content .\logs\output.log -value "$(Get-Date) - Script has been paused for one hour. However, we have transitioned into a new day. Due to limitations of the TimeSpan() class, the script will pause for an additional hour."
        Start-Sleep -Seconds 3600
    
    }
    
    Add-content .\logs\output.log -value "$(Get-Date) - Script has been paused for one hour. Returning to beginning of loop."
}
