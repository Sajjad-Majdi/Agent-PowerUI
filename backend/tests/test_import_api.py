"""
Test the model import API endpoint directly
"""
import requests
import json

# Test file path
TEST_FILE = r"C:\Users\Sajjad\.lmstudio\models\lmstudio-community\gemma-3-270m-it-qat-GGUF\gemma-3-270m-it-qat-Q4_0.gguf"

# API endpoint
API_URL = "http://localhost:5000/api/models/import"


def test_import_model():
    print("=" * 60)
    print("Testing Model Import API")
    print("=" * 60)
    print(f"\nTest file: {TEST_FILE}")
    print(f"API endpoint: {API_URL}")

    # Check if file exists locally
    import os
    if os.path.isfile(TEST_FILE):
        print(f"✓ File exists locally")
        print(
            f"  File size: {os.path.getsize(TEST_FILE) / (1024*1024):.2f} MB")
    else:
        print(f"✗ File does NOT exist locally!")
        return

    # Prepare request
    payload = {
        "path": TEST_FILE
    }

    print(f"\nSending POST request...")
    print(f"Payload: {json.dumps(payload, indent=2)}")

    try:
        # Send request
        response = requests.post(
            API_URL,
            headers={"Content-Type": "application/json"},
            json=payload,
            timeout=30
        )

        print(f"\n--- Response ---")
        print(f"Status Code: {response.status_code}")
        print(f"Response Body:")

        try:
            response_data = response.json()
            print(json.dumps(response_data, indent=2))

            if response.status_code == 200:
                print("\n✓ SUCCESS: Model imported successfully!")
                if 'destination' in response_data:
                    print(f"  Destination: {response_data['destination']}")
            else:
                print(
                    f"\n✗ FAILED: {response_data.get('error', 'Unknown error')}")

        except json.JSONDecodeError:
            print(response.text)

    except requests.exceptions.RequestException as e:
        print(f"\n✗ Request failed: {e}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    test_import_model()
