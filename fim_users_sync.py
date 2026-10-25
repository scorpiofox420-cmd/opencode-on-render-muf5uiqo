import base64
import json
import requests

# --- CONFIGURATION ---
APP_ID = "backend!"  # Your Fleetmatics App ID
USERNAME = "YOUR_FIM_USERNAME"  # Your integration username
PASSWORD = "YOUR_FIM_PASSWORD"  # Your integration password

# Exact specifications from your OpenAPI/Swagger schema
TOKEN_URL = "https://fim.api.us.fleetmatics.com/token"
USERS_API_URL = "https://fim.api.us.fleetmatics.com:443/cmd/v1/users"

def get_fim_token():
    """Generates the FIM authentication token using Base64 Basic Auth"""
    print("🔑 Requesting FIM Token...")
    raw_credentials = f"{USERNAME}:{PASSWORD}"
    encoded_creds = base64.b64encode(raw_credentials.encode("utf-8")).decode("utf-8")
    
    headers = {
        "Authorization": f"Basic {encoded_creds}",
        "Accept": "json"
    }
    
    response = requests.get(TOKEN_URL, headers=headers)
    response.raise_for_status()
    
    token = response.text.strip().replace('"', '')
    print("✅ FIM Token acquired successfully!")
    return token

def fetch_users():
    """Fetches users from the REVEAL account using the required Atmosphere header"""
    token = get_fim_token()
    
    # Mandatory compound Atmosphere + Bearer structure
    auth_header = f"Atmosphere atmosphere_app_id={APP_ID}, Bearer {token}"
    
    headers = {
        "Authorization": auth_header,
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    print(f"📦 Fetching users from: {USERS_API_URL}")
    try:
        response = requests.get(USERS_API_URL, headers=headers)
        response.raise_for_status()
        
        print("\n=== SUCCESS: USERS RETRIEVED ===")
        print(json.dumps(response.json(), indent=2))
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to fetch users: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response Details: {e.response.text}")

if __name__ == "__main__":
    fetch_users()
