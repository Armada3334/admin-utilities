import requests
import xml.etree.ElementTree as ET
import csv
import bz2

# Step 1: Define the URL for Ubuntu 18.04 OVAL definitions
version = "bionic"  # Ubuntu 18.04 codename
url = f'https://security-metadata.canonical.com/oval/com.ubuntu.{version}.usn.oval.xml.bz2'

# Download and decompress the OVAL file
response = requests.get(url)
if response.status_code != 200:
    print("Failed to download the OVAL file")
    exit()

# Decompress the content
oval_content = bz2.decompress(response.content)

# Step 2: Parse the XML
root = ET.fromstring(oval_content)

# Prepare the CSV data
csv_data = [["ID", "Title", "Description", "Severity", "References"]]

for definition in root.findall('.//{http://oval.mitre.org/XMLSchema/oval-definitions-5}definition'):
    # Extract information for each vulnerability
    title = definition.find('.//{http://oval.mitre.org/XMLSchema/oval-definitions-5}title').text
    description = definition.find('.//{http://oval.mitre.org/XMLSchema/oval-definitions-5}description').text
    
    # Attempt to extract severity. Adjust the path as needed based on the actual XML structure
    severity = "Unknown"  # Default value if severity is not found
    metadata = definition.find('.//{http://oval.mitre.org/XMLSchema/oval-definitions-5}metadata')
    if metadata is not None:
        severity_element = metadata.find('.//{http://oval.mitre.org/XMLSchema/oval-common-5}severity')
        if severity_element is not None:
            severity = severity_element.text
    
    references = [ref.get('ref_url') for ref in definition.findall('.//{http://oval.mitre.org/XMLSchema/oval-definitions-5}reference')]
    references_str = ", ".join(references)
    
    csv_data.append([definition.get('id'), title, description, severity, references_str])

# Step 3: Write data to a CSV file
csv_file_path = 'ubuntu_18_04_vulnerabilities.csv'
with open(csv_file_path, mode='w', newline='', encoding='utf-8') as file:
    writer = csv.writer(file)
    writer.writerows(csv_data)

print(f"CSV file has been created: {csv_file_path}")
