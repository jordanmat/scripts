import requests
from datetime import datetime, date
import webbrowser

def fetch_rightmove_properties(base_url, min_available_date):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'application/json',
        'Referer': 'https://www.rightmove.co.uk/',
        'Accept-Language': 'en-US,en;q=0.9'
    }

    all_filtered_properties = []

    try:
        # Convert min_available_date to datetime object if it's a string
        if isinstance(min_available_date, str):
            if min_available_date.lower() == 'now':
                min_available_date = date.today()
            else:
                min_available_date = datetime.strptime(min_available_date, '%Y-%m-%d').date()

        # First, fetch the initial page to get pagination information
        response = requests.get(base_url, headers=headers, timeout=10)
        response.raise_for_status()
        initial_data = response.json()

        # Get pagination options
        pagination_options = initial_data.get('pagination', {}).get('options', [])
        
        # If no pagination options, use only the base URL
        if not pagination_options:
            pagination_options = [{'value': 0}]

        # Iterate through all pagination options
        for page_option in pagination_options:
            # Construct URL with current page index
            current_url = base_url.replace('index=0', f'index={page_option["value"]}')
            
            # Fetch the page
            response = requests.get(current_url, headers=headers, timeout=10)
            response.raise_for_status()
            data = response.json()

            # Filter properties based on letAvailableDate
            filtered_properties = [
                prop for prop in data.get('properties', []) 
                if prop.get('letAvailableDate') and 
                   datetime.strptime(prop['letAvailableDate'], '%Y-%m-%dT%H:%M:%SZ').date() >= min_available_date
            ]

            # Add filtered properties from this page
            all_filtered_properties.extend(filtered_properties)

            # Print debug information
            print(f"Fetching page index {page_option['value']}")

        # Sort properties by available date in descending order
        sorted_properties = sorted(
            all_filtered_properties, 
            key=lambda prop: datetime.strptime(prop['letAvailableDate'], '%Y-%m-%dT%H:%M:%SZ'), 
            reverse=True
        )

        return sorted_properties

    except requests.RequestException as e:
        print(f"An error occurred: {e}")
        return []

def main():
    # Base Rightmove URL (without price parameters)
    base_url_template = (
        "https://www.rightmove.co.uk/api/property-search/listing/search"
        "?locationIdentifier=USERDEFINEDAREA%5E%7B%22id%22%3A6430801%7D"
        "&sortType=6&savedSearchId=49957794"
        "&minBedrooms=2&radius=0&maxDaysSinceAdded=7"
        "&includeLetAgreed=false&letType=longTerm"
        "&furnishTypes=furnished&unfurnished&index=0"
        "&channel=RENT&transactionType=LETTING"
    )

    # Prompt for maximum price with a default value of £1900
    while True:
        try:
            max_price_input = input("Enter the maximum price (£) [Default: 1900]: ").strip()
            if not max_price_input:  # Use default value if input is blank
                max_price = 1900
            else:
                max_price = int(max_price_input)
            break
        except ValueError:
            print("Invalid input. Please enter a valid number or leave blank for the default.")


    # Prompt for minimum available date with a default value of 2025-02-01
    while True:
        try:
            min_date_input = input("Enter the minimum available date (YYYY-MM-DD or 'now') [Default: 2025-02-01]: ").strip()
            if not min_date_input:  # Use default if blank
                min_date = datetime.strptime('2025-02-01', '%Y-%m-%d').date()
                min_date_input = '2025-02-01'  # Keep for output reference
                break
            elif min_date_input.lower() == 'now':
                min_date = date.today()
                break
            else:
                min_date = datetime.strptime(min_date_input, '%Y-%m-%d').date()
                break
        except ValueError:
            print("Invalid date format. Please use YYYY-MM-DD, 'now', or leave blank for the default.")


    # Update the base URL with the maximum price
    base_url = f"{base_url_template}&maxPrice={max_price}"

    # Fetch and filter properties from all pages
    filtered_properties = fetch_rightmove_properties(base_url, min_date_input)

    # Print out details of filtered properties
    if filtered_properties:
        print(f"\nProperties with a maximum price of £{max_price} available on or after {min_date_input}:")
        property_urls = []
        for prop in filtered_properties:
            # Construct direct URL to the property
            property_url = f"https://www.rightmove.co.uk/properties/{prop.get('id')}"
            property_urls.append(property_url)

            let_available_date = prop.get('letAvailableDate', '')
            date_only = let_available_date.split('T')[0] if 'T' in let_available_date else let_available_date

            print(f"Property ID: {prop.get('id')}")
            print(f"Address: {prop.get('displayAddress')}")
            print(f"Let Available Date: {date_only}")
            print(f"Price: £{prop.get('price', {}).get('amount')}")
            print(f"Added/Reduced: {prop.get('addedOrReduced')}")
            print(f"Direct URL: {property_url}")
            print("---")

        print(f"Total properties found: {len(filtered_properties)}")

        # Prompt user to open all links in the browser
        open_in_browser = input("Would you like to open all property links in the browser? (yes/no): ").strip().lower()
        if open_in_browser in ['yes', 'y']:
            for url in property_urls:
                webbrowser.open_new_tab(url)
    else:
        print(f"No properties found with a maximum price of £{max_price} available on or after {min_date_input}")

if __name__ == "__main__":
    main()
