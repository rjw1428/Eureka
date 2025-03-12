from google.oauth2 import service_account
from googleapiclient.discovery import build

SHEETS_CREDENTIALS_FILE = "google_service_account.json" # Google Service Account JSON path
SPREADSHEET_ID = '17E7kurH65VGB88jWJk2_KQaRsqR_lWCOLJV6c3KZRA4'  # From Google Sheets URL

# Set up credentials
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']
credentials = service_account.Credentials.from_service_account_file(
    SHEETS_CREDENTIALS_FILE, scopes=SCOPES)

# Build the Sheets API service
service = build('sheets', 'v4', credentials=credentials)

# Print the service account email (to verify for sharing)
print(f"Service account email: {credentials.service_account_email}")

# Try to access metadata about the spreadsheet (to test permissions)
try:
    response = service.spreadsheets().get(spreadsheetId=SPREADSHEET_ID).execute()
    print("Successfully accessed the spreadsheet!")
    print(f"Title: {response.get('properties', {}).get('title')}")
except Exception as e:
    print(f"Error: {str(e)}")