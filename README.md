# Nintex Process Manager Document Report Generator

A PowerShell script that generates a comprehensive CSV report of all documents in a Nintex Process Manager site.

## Features

- **Interactive authentication**: Prompts for Site URL and credentials
- **Comprehensive data collection**: Retrieves both active and archived documents
- **Pagination support**: Handles large document libraries automatically
- **Detailed reporting**: Includes review dates, ownership, approval history, and more

## Report Columns

The generated CSV report includes the following information for each document:

- **Document Name**: The name of the document
- **Document Primary Group Name**: The primary group/folder the document belongs to
- **Last Upload Date**: Date of the most recent upload
- **Last Reviewed Date**: Date of the last review
- **Next Review Date**: Scheduled date for the next review
- **Archived Date**: Date the document was archived (if applicable)
- **Owners**: List of document owners (semicolon-separated)
- **Approvers**: List of document approvers (semicolon-separated)
- **Last Approved By**: Name of the person who last approved the document
- **Document ID**: Internal document identifier
- **Is Archived**: Whether the document is archived (True/False)

## Prerequisites

- PowerShell 5.1 or later
- Network access to your Process Manager site
- Valid Process Manager credentials with appropriate permissions

## Usage

1. **Run the script**:
   ```powershell
   .\Generate-DocumentReport.ps1
   ```

2. **Enter your Site URL** when prompted:
   ```
   Example: https://demo.promapp.com/93555a16ceb24f139a6e8a40618d3f8b
   ```

3. **Enter your username** (email address):
   ```
   Example: your.email@company.com
   ```

4. **Enter your password** (input will be hidden)

5. **Wait for processing**: The script will:
   - Authenticate with the Process Manager site
   - Retrieve all active documents
   - Retrieve all archived documents
   - Fetch detailed properties and history for each document
   - Generate the CSV report

6. **Find your report**: The script generates a timestamped CSV file:
   ```
   DocumentReport_YYYYMMDD_HHMMSS.csv
   ```

## Example Output

The script provides progress updates during execution:

```
=== Nintex Process Manager Document Report Generator ===

Authenticating...
Authentication successful!

Retrieving documents...
Fetching Active documents...
  Retrieved page 1 (100 of 261 documents)
  Retrieved page 2 (200 of 261 documents)
  Retrieved page 3 (261 of 261 documents)
  Total Active documents retrieved: 261

Fetching Archived documents...
  Retrieved page 1 (66 of 66 documents)
  Total Archived documents retrieved: 66

Total documents to process: 327

Processing document 1 of 327: Document Name
  ✓ Processed successfully

...

=== Report Generation Complete ===
Report saved to: DocumentReport_20251219_143052.csv
Total documents processed: 327
```

## API Endpoints Used

The script uses the following Nintex Process Manager API endpoints:

1. **Authentication**:
   - `POST /{tenantId}/oauth2/token`

2. **Document List**:
   - `GET /{tenantId}/bff/document/api/v1/documents?Page={page}&PageSize={pageSize}&DocumentType=All`
   - `GET /{tenantId}/bff/document/api/v1/documents?Page={page}&PageSize={pageSize}&DocumentType=All&ListType=Archived`

3. **Document Properties**:
   - `GET /{tenantId}/bff/document/api/v1/documents/{documentId}/properties`

4. **Document History**:
   - `GET /{tenantId}/bff/document/api/v1/documents/{documentId}/history?Page=1&PageSize=500`

## Data Extraction Logic

### Last Upload Date
Extracts from document history by finding the most recent entry with `type: 1` (Upload event).

### Last Approved By
Extracts from document history by finding the most recent entry with `type: 4` (Approval event) and returns the `userName`.

### Archived Date
For archived documents, uses the `archivedDate` field from the document list response.

### Review Dates
Extracted from the `documentReview` section of the document properties:
- `lastReviewDate`: Date of the last completed review
- `nextReviewDueDate`: Date when the next review is due

### Owners and Approvers
Extracted from the `stakeholdersGroupedByType` section of document properties, grouped by type ("Owner" or "Approver").

## Troubleshooting

### Authentication Fails
- Verify your Site URL is correct and includes the tenant ID
- Check that your username and password are correct
- Ensure your account has appropriate permissions

### Missing Data
- Some documents may not have all fields populated (e.g., no approvals, no reviews)
- The script handles missing data gracefully by leaving those fields empty

### Performance
- Processing time depends on the number of documents
- The script processes documents sequentially to avoid API rate limits
- For large sites (1000+ documents), expect 10-15 minutes of processing time

## Notes

- The script uses a token duration of 60000 seconds (~16 hours) to ensure it doesn't expire during processing
- Page size is set to 100 documents per API call for optimal performance
- History is retrieved with a page size of 500 to capture complete document history in one call
- All dates in the CSV are in ISO 8601 format (YYYY-MM-DDTHH:mm:ss)

## License

This script is provided as-is for use with Nintex Process Manager.
