<#
.SYNOPSIS
    Generates a CSV report of all documents in a Nintex Process Manager site.

.DESCRIPTION
    This script connects to a Nintex Process Manager site, retrieves all documents
    (both active and archived), and generates a comprehensive CSV report with
    document metadata including review dates, owners, approvers, and history.

.EXAMPLE
    .\Generate-DocumentReport.ps1
#>

[CmdletBinding()]
param()

# Function to get authentication token
function Get-AuthToken {
    param(
        [string]$SiteUrl,
        [string]$Username,
        [string]$Password
    )

    Write-Host "Authenticating..." -ForegroundColor Cyan

    # Extract tenant ID from Site URL
    $uri = [System.Uri]$SiteUrl
    $tenantId = $uri.AbsolutePath.Trim('/')

    $tokenUrl = "$($uri.Scheme)://$($uri.Host)/$tenantId/oauth2/token"

    $body = @{
        grant_type = 'password'
        username = $Username
        password = $Password
        duration = '60000'
    }

    try {
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded'
        Write-Host "Authentication successful!" -ForegroundColor Green
        return $response.access_token
    }
    catch {
        Write-Error "Authentication failed: $_"
        throw
    }
}

# Function to get all documents with pagination
function Get-AllDocuments {
    param(
        [string]$SiteUrl,
        [string]$Token,
        [string]$ListType = "Active"  # Active or Archived
    )

    $uri = [System.Uri]$SiteUrl
    $tenantId = $uri.AbsolutePath.Trim('/')
    $baseUrl = "$($uri.Scheme)://$($uri.Host)/$tenantId"

    $headers = @{
        'Authorization' = "Bearer $Token"
    }

    $allDocuments = @()
    $page = 1
    $pageSize = 100

    Write-Host "Fetching $ListType documents..." -ForegroundColor Cyan

    do {
        if ($ListType -eq "Archived") {
            $url = "$baseUrl/bff/document/api/v1/documents?Page=$page&PageSize=$pageSize&DocumentType=All&ListType=Archived"
        }
        else {
            $url = "$baseUrl/bff/document/api/v1/documents?Page=$page&PageSize=$pageSize&DocumentType=All"
        }

        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
            $allDocuments += $response.items

            Write-Host "  Retrieved page $page ($($allDocuments.Count) of $($response.totalItemCount) documents)" -ForegroundColor Gray

            $page++

            # Check if we've retrieved all documents
            if ($allDocuments.Count -ge $response.totalItemCount) {
                break
            }
        }
        catch {
            Write-Error "Error fetching documents page $page : $_"
            throw
        }
    } while ($true)

    Write-Host "  Total $ListType documents retrieved: $($allDocuments.Count)" -ForegroundColor Green
    return $allDocuments
}

# Function to get document properties
function Get-DocumentProperties {
    param(
        [string]$SiteUrl,
        [string]$Token,
        [int]$DocumentId
    )

    $uri = [System.Uri]$SiteUrl
    $tenantId = $uri.AbsolutePath.Trim('/')
    $baseUrl = "$($uri.Scheme)://$($uri.Host)/$tenantId"

    $headers = @{
        'Authorization' = "Bearer $Token"
    }

    $url = "$baseUrl/bff/document/api/v1/documents/$DocumentId/properties"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        return $response
    }
    catch {
        Write-Warning "Error fetching properties for document $DocumentId : $_"
        return $null
    }
}

# Function to get document history
function Get-DocumentHistory {
    param(
        [string]$SiteUrl,
        [string]$Token,
        [int]$DocumentId
    )

    $uri = [System.Uri]$SiteUrl
    $tenantId = $uri.AbsolutePath.Trim('/')
    $baseUrl = "$($uri.Scheme)://$($uri.Host)/$tenantId"

    $headers = @{
        'Authorization' = "Bearer $Token"
    }

    $url = "$baseUrl/bff/document/api/v1/documents/$DocumentId/history?Page=1&PageSize=500"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        return $response.items
    }
    catch {
        Write-Warning "Error fetching history for document $DocumentId : $_"
        return @()
    }
}

# Function to extract last upload date from history
function Get-LastUploadDate {
    param($History)

    # Type 1 = Upload
    $uploads = $History | Where-Object { $_.type -eq 1 } | Sort-Object date -Descending
    if ($uploads -and $uploads.Count -gt 0) {
        return $uploads[0].date
    }
    return $null
}

# Function to extract last approved by from history
function Get-LastApprovedBy {
    param($History)

    # Type 4 = Approved
    $approvals = $History | Where-Object { $_.type -eq 4 } | Sort-Object date -Descending
    if ($approvals -and $approvals.Count -gt 0) {
        return $approvals[0].userName
    }
    return $null
}

# Function to extract archived date from history
function Get-ArchivedDate {
    param($History)

    # For archived documents, get the most recent history entry date
    if ($History -and $History.Count -gt 0) {
        $sorted = $History | Sort-Object date -Descending
        return $sorted[0].date
    }
    return $null
}

# Function to format stakeholders
function Format-Stakeholders {
    param($StakeholdersGrouped, $Type)

    $stakeholderGroup = $StakeholdersGrouped | Where-Object { $_.type -eq $Type }
    if ($stakeholderGroup -and $stakeholderGroup.stakeholders) {
        return ($stakeholderGroup.stakeholders.name -join '; ')
    }
    return ""
}

# Main script
Write-Host "`n=== Nintex Process Manager Document Report Generator ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for Site URL
$siteUrl = Read-Host "Enter your Process Manager Site URL (e.g., https://demo.promapp.com/93555a16ceb24f139a6e8a40618d3f8b)"

# Validate Site URL
if ([string]::IsNullOrWhiteSpace($siteUrl)) {
    Write-Error "Site URL is required"
    exit 1
}

# Ensure URL doesn't end with a slash
$siteUrl = $siteUrl.TrimEnd('/')

# Prompt for credentials
$username = Read-Host "Enter your username"
$securePassword = Read-Host "Enter your password" -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

# Get authentication token
try {
    $token = Get-AuthToken -SiteUrl $siteUrl -Username $username -Password $password
}
catch {
    Write-Error "Failed to authenticate. Please check your credentials and try again."
    exit 1
}

# Get all documents (both active and archived)
Write-Host "`nRetrieving documents..." -ForegroundColor Cyan
$activeDocuments = Get-AllDocuments -SiteUrl $siteUrl -Token $token -ListType "Active"
$archivedDocuments = Get-AllDocuments -SiteUrl $siteUrl -Token $token -ListType "Archived"

$allDocuments = $activeDocuments + $archivedDocuments
Write-Host "`nTotal documents to process: $($allDocuments.Count)" -ForegroundColor Yellow

# Process each document and build report data
$reportData = @()
$counter = 0

foreach ($doc in $allDocuments) {
    $counter++
    Write-Host "`nProcessing document $counter of $($allDocuments.Count): $($doc.documentName)" -ForegroundColor Cyan

    # Get document properties
    $properties = Get-DocumentProperties -SiteUrl $siteUrl -Token $token -DocumentId $doc.documentId

    # Get document history
    $history = Get-DocumentHistory -SiteUrl $siteUrl -Token $token -DocumentId $doc.documentId

    # Extract data
    $lastUploadDate = Get-LastUploadDate -History $history
    $lastApprovedBy = Get-LastApprovedBy -History $history

    # For archived documents, get the archived date
    $archivedDate = $null
    if ($doc.isArchived) {
        $archivedDate = $doc.archivedDate
    }

    # Extract owners and approvers
    $owners = ""
    $approvers = ""
    if ($properties -and $properties.stakeholdersGroupedByType) {
        $owners = Format-Stakeholders -StakeholdersGrouped $properties.stakeholdersGroupedByType -Type "Owner"
        $approvers = Format-Stakeholders -StakeholdersGrouped $properties.stakeholdersGroupedByType -Type "Approver"
    }

    # Extract review dates
    $lastReviewDate = $null
    $nextReviewDate = $null
    if ($properties -and $properties.documentReview) {
        $lastReviewDate = $properties.documentReview.lastReviewDate
        $nextReviewDate = $properties.documentReview.nextReviewDueDate
    }

    # Create report row
    $row = [PSCustomObject]@{
        'Document Name' = $doc.documentName
        'Document Primary Group Name' = $doc.primaryGroupName
        'Last Upload Date' = if ($lastUploadDate) { $lastUploadDate } else { $doc.uploadDate }
        'Last Reviewed Date' = $lastReviewDate
        'Next Review Date' = $nextReviewDate
        'Archived Date' = $archivedDate
        'Owners' = $owners
        'Approvers' = $approvers
        'Last Approved By' = $lastApprovedBy
        'Document ID' = $doc.documentId
        'Is Archived' = $doc.isArchived
    }

    $reportData += $row

    Write-Host "  ✓ Processed successfully" -ForegroundColor Green
}

# Generate output filename with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = "DocumentReport_$timestamp.csv"

# Export to CSV
Write-Host "`nGenerating CSV report..." -ForegroundColor Cyan
$reportData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "`n=== Report Generation Complete ===" -ForegroundColor Green
Write-Host "Report saved to: $outputFile" -ForegroundColor Yellow
Write-Host "Total documents processed: $($reportData.Count)" -ForegroundColor Yellow
Write-Host ""
