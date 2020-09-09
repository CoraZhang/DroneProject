
try:
    from urllib.parse import urlparse, parse_qs, urlencode
except ImportError:
    from urlparse import urlparse, parse_qs

import json
import os
import random
import string
import sys
import requests
import urllib
import time
import pprint

#from adal import AuthenticationContext

def turn_on_logging():
    logging.basicConfig(level=logging.DEBUG)

def jdefault(o):
    if isinstance(o, set):
        return list(o)
    return o.__dict__

parameters_file = (sys.argv[1] if len(sys.argv) == 2 else 
                   os.environ.get('ADAL_SAMPLE_PARAMETERS_FILE'))

if parameters_file:
    with open(parameters_file, 'r') as f:
        parameters = f.read()
    sample_parameters = json.loads(parameters)
else:
    raise ValueError('Please provide parameter file with account information.')

# **************************
url = "https://login.microsoftonline.com/" + sample_parameters['tenantId'] + "/oauth2/token"

params = {
			"client_id": sample_parameters['clientId'],
			"client_secret": sample_parameters['clientSecret'],
			"resource": sample_parameters['webApiResourceId'],
			"username": sample_parameters['username'],
			"password": sample_parameters['password'],
			"grant_type": "password"
		}

headers = {
   			"Cache-Control": "no-cache",
			"Content-Type": "application/x-www-form-urlencoded"
}

response = requests.post(url, data=urllib.urlencode(params), headers=headers)

#print "Response Status: " + str(response.status_code)

json_data = json.loads(response.text)

accessToken = json_data.get("access_token")

#print "AccessToken: " + accessToken
#print

url = 'https://eappiotsens.servicebus.windows.net/datacollectoroutbox/publishers/fffb8fc8-6eae-4368-86c2-6eb75c3ff015/messages'

auth = 'Bearer ' + accessToken

# From the Gateway ticket.
httpSAS = 'SharedAccessSignature sr=https%3a%2f%2feappiotsens.servicebus.windows.net%2fdatacollectoroutbox%2fpublishers%2ffffb8fc8-6eae-4368-86c2-6eb75c3ff015%2fmessages&sig=jCs12Zn4hYYHZmaPN8wjVLmawTJJnombeD4MKMgQ2X8%3d&se=4632434417&skn=SendAccessPolicy'
# From APPIoT 
gatewayID = 'fffb8fc8-6eae-4368-86c2-6eb75c3ff015'

time_now = int(time.time())

# Sensor ID and data.
temperature = '[{"id":"ed6abeaf-37b8-4af6-af0e-d9d377cfcf82","v":[{"m":[21.43],"t":%d}]}]' % (time_now)

headers = { 'Authorization': httpSAS, 'DataCollectorId': gatewayID, 'PayloadType': 'Measurements', 'Timestamp': time_now, 'Cache-Control': 'no-cache', 'Content-Length': len(temperature) }

response = requests.post(url, data=temperature, headers=headers)

print "Response Status: " + str(response.status_code)
