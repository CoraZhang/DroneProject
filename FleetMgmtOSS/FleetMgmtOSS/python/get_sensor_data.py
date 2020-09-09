
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

json_data = json.loads(response.text)

accessToken = json_data.get("access_token")

auth = 'Bearer ' + accessToken

headers = {'Authorization': auth, 'X-DeviceNetwork': sample_parameters['deviceNetworkId'], 'Content-type': 'application/json'}

sensor_ids = {"Temperature":"ed6abeaf-37b8-4af6-af0e-d9d377cfcf82",
              "Is_Open":"8d77241f-07cc-4990-b7f5-e07ff3b773f2",
              "Is_Tilted":"5a0cc0cf-5bcc-4106-95c8-be52855eb145"}

for sensor,sensor_id in sensor_ids.iteritems():
    url = 'https://eappiot-api.sensbysigma.com/api/v2/sensors/%s/latestmeasurement' % (sensor_id)
    response = requests.get(url, headers=headers)
    print "%s: " % (sensor),
    pprint.pprint(response.content)
