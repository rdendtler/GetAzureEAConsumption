 #GetAzureEAConsumption
This script is designed to use the new [Azure Consumption API's](https://docs.microsoft.com/en-us/azure/billing/billing-enterprise-api) which replace the old EA Billing API.

To configure the script update the following variables in the script

    $enrollmentNumber = "<enrollment number>"
    accessKey = "<api billing key>"
    $blobAccountName = "<storage account name>"
    $blobAccountKey = "<storage account key>"
    $blobContainerName = "<blob container name>"# GetAzureEAConsumption
Example Powershell script to download Usage, Pricesheets, Summary and Marketplace charges using the new Azure Consumption API

# Running the App
the application has two optional parameters
- Type: which is either detail (default) | summary | pricesheet | marketplace
- Month: which is the month for which you need teh data in the form of yyyymm.  Defaults to the current month

Run without any of the parameters the script will download the current months usage data and upload to Azure Blob Storage.  Note:  In the first 5 days of the month, the script will download both the current month and the previous months data as there is often a 24-48 hour lag on data from the billing system. 
