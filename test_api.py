import requests
import json
import argparse

BASE_URL = "https://api.winsoftsc.com"

def login(dairy_code, phone):
    print(f"[*] Logging in to obtain Auth Token...")
    url = f"{BASE_URL}/api/passbook/meminfo"
    params = {
        "dairycode": 2253,
        "phone": 9096707031
    }
    
    try:
        response = requests.get(url, params=params)
        print(f"[HTTP GET] {response.url} - Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(response.text)
            token = data.get("authtoken")
            soc_code = data.get("socCode")
            mem_code = data.get("membCode")
            
            if not token:
                print("[-] Error: Login succeeded but no auth token returned.")
                return None
            
            print(f"[+] Login Successful!")
            print(f"    - Auth Token: {token[:15]}...{token[-15:]}")
            print(f"    - Society Code: {soc_code}")
            print(f"    - Member Code: {mem_code}")
            return {
                "token": token,
                "soc_code": soc_code,
                "mem_code": mem_code
            }
        else:
            print(f"[-] Login failed: {response.text}")
            return None
    except Exception as e:
        print(f"[-] Connection Error during login: {e}")
        return None

def test_miltrn_list(auth_data, endpoint="/api/miltrn/list"):
    if not auth_data:
        print("[-] Skipping API test due to login failure.")
        return
    
    token = auth_data["token"]
    soc_code = auth_data["soc_code"]
    mem_code = auth_data["mem_code"]
    
    url = f"{BASE_URL}{endpoint}"
    params = {
        "socitycode": soc_code,
        "memcode": mem_code
    }
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    print(f"[*] Testing Endpoint: {url}...")
    try:
        response = requests.get(url, headers=headers, params=params)
        print(f"[HTTP GET] {response.url} - Status: {response.status_code}")
        
        if response.status_code == 200:
            print("[+] Success! Response Data:")
            print(json.dumps(response.json(), indent=4, ensure_ascii=False))
        elif response.status_code == 404:
            print(f"[-] Endpoint {endpoint} returned 404.")
            if endpoint != "/api/passbook/list":
                print("[*] Trying fallback '/api/passbook/list'...")
                test_miltrn_list(auth_data, endpoint="/api/passbook/list")
        else:
            print(f"[-] API test failed (Status {response.status_code}): {response.text}")
    except Exception as e:
        print(f"[-] Connection Error during API test: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test /api/miltrn/list API in Python")
    parser.add_argument("--dairycode", default="9999", help="Dairy cooperative code")
    parser.add_argument("--phone", default="9999999999", help="Registered phone number")
    parser.add_argument("--endpoint", default="/api/miltrn/list", help="API endpoint to test")
    
    args = parser.parse_args()
    
    auth = login(args.dairycode, args.phone)
    if auth:
        test_miltrn_list(auth, endpoint=args.endpoint)