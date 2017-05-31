Param(
[string]$month,
[string]$type = "detail"  #Options are pricesheet, marketplace, summary or detail
)
<#
Based on the API's 
- Balance Summary https://docs.microsoft.com/en-us/azure/billing/billing-enterprise-api-balance-summary
- Consumption https://docs.microsoft.com/en-us/azure/billing/billing-enterprise-api-usage-detail
- Marketplace https://docs.microsoft.com/en-us/azure/billing/billing-enterprise-api-marketplace-storecharge
- Price Sheet https://docs.microsoft.com/en-us/azure/billing/billing-enterprise-api-pricesheet 
#>
################################# 
# Global Variables
$enrollmentNumber = "<enrollment number>"
$accessKey = "<api billing key>"
$baseurl = "https://consumption.azure.com/v1/enrollments" 
$header = @{"authorization"="bearer $accessKey"}
$contentType = "application/json;charset=utf-8"
$blobAccountName = "<storage account name>"
$blobAccountKey = "<storage account key>"
$blobContainerName = "<blob container name>"
################################# 

#Get the list of Billing Periods and return in an array
function GetBillingPeriods() 
{
    $url = "$baseurl/$enrollmentNumber/billingperiods";
    Try {
        Write-Host "[Getting   ] Available Reports for $enrollmentNumber"
        $response = Invoke-RestMethod -Uri $url -Headers $header -Method Get
        $billingPeriods = @($response | Select-Object billingPeriodId)
        }
    Catch {
        $errorMessage = $_.Exception.Message 
        $failedItem = $_.Exception.ItemName
        Write-Host "[ERROR    ] $errorMessage $failedItem "
        Break
        }
    return $billingPeriods
}
#Get the usage report for the specific month.
function Get-ConsumptionData([string]$reportType, [string]$reportMonth) 
{     
    switch ($reportType)
    {
        "detail" {$uri = "$baseurl/$enrollmentNumber/billingPeriods/$reportMonth/usagedetails"}
        "summary" {$uri = "$baseurl/$enrollmentNumber/billingPeriods/$reportMonth/balancesummary"}
        "pricesheet" {$uri = "$baseurl/$enrollmentNumber/billingPeriods/$reportMonth/pricesheet"}
        "marketplace" {$uri = "$baseurl/$enrollmentNumber/billingPeriods/$reportMonth/marketplacecharges"}
        default {$uri = "$baseurl/$enrollmentNumber/billingPeriods/$reportMonth/usagedetails"}
    }
   
    #request the data
    $counter = 0
    Try {
        Write-Host "[Trying    ] Requesting $reportType report for the month of $reportMonth for enrollment $enrollmentNumber"
        Do {
            $response = Invoke-RestMethod `
                -Uri $uri `
                -Headers $header `
                -Method Get `
                -ContentType $contentType `
                -TimeoutSec 30
            if ($reportType -eq "detail")
                {
                $consumptionData = $consumptionData + $response.data 
                $counter = $counter + $response.data.count
                $uri = $response.nextlink               
                Write-Host $counter
                }
            else
                {
                $consumptionData = $response 
                $uri = ""
                }
            }
        Until ([String]::IsNullOrEmpty($uri))
    }
    Catch {
        $errorMessage = $_.Exception.Message 
        $failedItem = $_.Exception.ItemName
        Write-Host "[ERROR] $errorMessage $failedItem "
        Break
        }
    return $consumptionData
 } 
function WriteDataToBlob($data, [string]$reportType, [string]$month)
{
    # Write to a local file
    $filename = ".\$($month)_$($reportType).csv"
    Write-Host "[Saving    ] to file $filename"
    $data | Export-Csv -Path $filename -NoTypeInformation -Delimiter "|"
    $context = New-AzureStorageContext -StorageAccountName $blobAccountName -StorageAccountKey $blobAccountKey
    $blobProperties = @{"ContentType" = "text/csv"};
    $fileSend = Set-AzureStorageBlobContent `
                    -Force `
                    -File $filename `
                    -Container $blobContainerName `
                    -BlobType "Block" `
                    -Properties $blobProperties `
                    -Context $context
    Write-Host "[Uploading ] Wrote $([math]::Truncate($fileSend.Length /1KB)) KB to $($fileSend.ICloudBlob)"
    Remove-Item -Path $filename -Force   
 return
 }
# Start of Main Program  
# If no month specified, get the current month to download.  Otherwise use passed in parameter
if ([String]::IsNullOrEmpty($month))
{
    $today = Get-Date
    $billingPd = GetBillingPeriods
    if ($type -eq "detail" -and $today.Day -le 5) #if we're getting usage detail and we're in data lag
        {
        for($i=0; $i -le 1; $i++)
        {    
         $data = Get-ConsumptionData $type $billingPd.BillingPeriodId[$i]
         WriteDataToBlob $data $type $billingPd.BillingPeriodId[$i]
        }
        }
    else # run this for the current month
        {
        $data = Get-ConsumptionData $type $billingPd.BillingPeriodID[0]
        WriteDataToBlob $data $type $billingPd.BillingPeriodID[0]
        }
}
else # use the month specified
{
    $data = Get-ConsumptionData $type $month
    WriteDataToBlob $data $type $month
}
