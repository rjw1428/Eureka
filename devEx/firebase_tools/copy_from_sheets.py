import os
import time
from datetime import datetime
from google.oauth2 import service_account
from googleapiclient.discovery import build
from google.cloud import firestore

# Configuration
SHEETS_CREDENTIALS_FILE = "google_service_account.json" # Google Service Account JSON path
FIREBASE_CREDENTIALS_FILE = "firebase_service_account.json" # Firebase Service Account JSON path
FIRESTORE_COLLECTION = 'ledger/41Rfjjro4zy9Xr3gs557'
SPREADSHEET_ID = '17E7kurH65VGB88jWJk2_KQaRsqR_lWCOLJV6c3KZRA4'  # From Google Sheets URL
RANGE_NAME = 'Data!$A$1:$D' #Include Headers

def date_str(date_string):
    try:
        dt_object = datetime.strptime(date_string, '%m/%d/%Y %H:%M:%S')
        return dt_object.isoformat()
    except ValueError:
        print(f'date string incorrectly formatted: {date_string}')
        return None

def iso_to_year_month(iso_string):
    try:
        dt_object = datetime.fromisoformat(iso_string)
        year = dt_object.year
        month_str = dt_object.strftime('%b').upper()
        return f"{year}_{month_str}"
    except ValueError:
        print(f'date string incorrectly formatted: {iso_string}')
        return None

def get_sheets_data(spreadsheet_id, range_name):
    """
    Retrieve data from a Google Sheet.
    
    Args:
        spreadsheet_id (str): The ID of the spreadsheet (from the URL)
        range_name (str): Range of cells to retrieve (e.g., "Sheet1!A1:D10")
        
    Returns:
        list: List of dictionaries containing the sheet data with headers as keys
    """
    # Set up credentials
    SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly']
    credentials = service_account.Credentials.from_service_account_file(
        SHEETS_CREDENTIALS_FILE, scopes=SCOPES)
    
    # Build the Sheets API service
    service = build('sheets', 'v4', credentials=credentials)
    
    # Call the Sheets API to get values
    sheet = service.spreadsheets()
    result = sheet.values().get(spreadsheetId=spreadsheet_id, range=range_name).execute()
    values = result.get('values', [])
    
    if not values:
        print('No data found in the spreadsheet.')
        return []
    
    # Convert to list of dictionaries with headers as keys
    headers = [item.lower() if isinstance(item, str) else item for item in values[0]]
    data = []
    for row in values[1:]:
        # Pad row if it's shorter than headers
        padded_row = row + [''] * (len(headers) - len(row))
        data.append(dict(zip(headers, padded_row)))
    
    return data


def upload_to_firestore(collection_name, data):
    """
    Upload data to Firestore collection.
    
    Args:
        collection_name (str): Name of the Firestore collection
        data (list): List of dictionaries to upload
    """
    # Initialize Firestore client
    db = firestore.Client.from_service_account_json(FIREBASE_CREDENTIALS_FILE)

    
    # Add each item to Firestore
    # batch = db.batch()  # Use batch write for better performance
    count = 0
    sum = {}
    for item in data:
        collection_key = iso_to_year_month(item['date'])
        collection_ref = db.collection(collection_name + '/' + collection_key)
        # Create a document reference with an auto-generated ID
        doc_ref = collection_ref.add(item)
        # batch.set(doc_ref, item)
        doc_ref
        count += 1
        if collection_key in sum:
            sum[collection_key] += item['amount']
        else:
            sum[collection_key] = item['amount']
        time.sleep(1)
        
    #     # Commit in batches of 500 (Firestore limit)
    #     if count >= 500:
    #         batch.commit()
    #         batch = db.batch()
    #         count = 0
    
    # # Commit any remaining documents
    # if count > 0:
    #     batch.commit()
    
    print(f"Successfully uploaded {len(data)} items to '{collection_name}' collection.")
    print(f"SUMMARY:")
    for key, val in sum.items():
        print(f"{key}: ${val}")

def main():
    
    # Check for credentials files
    required_files = [FIREBASE_CREDENTIALS_FILE, SHEETS_CREDENTIALS_FILE]
    for file in required_files:
        if not os.path.isfile(file):
            print(f"Error: Required file '{file}' not found.")
            print(f"Make sure to download your service account credentials and save as '{file}'")
            return
    
    try:
        # Get data from Google Sheets
        print(f"Retrieving data from Google Sheet...")
        sheet_data = get_sheets_data(SPREADSHEET_ID, RANGE_NAME)
        
        if not sheet_data:
            print("No data to upload. Exiting.")
            return
            
        print(f"Retrieved {len(sheet_data)} rows from the sheet.")

        sheetCategory = 'hobbies/career - r'
        firestoreCategory = 'RYAN\'S HOBBIES'
        
        # Upload data to Firestore
        print(f"Uploading data to Firestore collection '{FIRESTORE_COLLECTION}'...")
        # print(f"{sheet_data[1]}")
        filtered_data = [data for data in sheet_data if data['catagory'].lower() == sheetCategory]
        print(f"ROW: \n{filtered_data[0]}\n LEN: {len(filtered_data)}") 
        
        transformed_data = list(map(lambda item: {'amount': round(float(item['value']),2), 'categoryId': firestoreCategory, 'note': None if not item['note'] else item['note'], 'date': date_str(item['timestamp'])}, filtered_data))
        # upload_to_firestore(FIRESTORE_COLLECTION, transformed_data)
        print("Process completed successfully!")

        
        
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    main()