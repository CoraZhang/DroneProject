#!/usr/bin/python

from urlparse import urlparse, parse_qs

import os
import sys
import json
import urllib
import requests

# Read in authentication related parameters from JSON config file.
parameters_file = "adal.config.json"

if parameters_file:
    with open(parameters_file, 'r') as f:
        parameters = f.read()
    adal_obj = json.loads(parameters)
else:
    raise ValueError('Please provide parameter file with account information.')

url = "https://login.microsoftonline.com/" + adal_obj['tenantId'] + "/oauth2/token"

params = { "client_id": adal_obj['clientId'],
           "client_secret": adal_obj['clientSecret'],
           "resource": adal_obj['webApiResourceId'],
           "username": adal_obj['username'],
           "password": adal_obj['password'],
           "grant_type": "password" }

headers = { "Cache-Control": "no-cache",
            "Content-Type": "application/x-www-form-urlencoded" }

try:
    response = requests.post(url, data=urllib.urlencode(params), headers=headers, proxies="")
except requests.exceptions.Timeout as e:
    # Maybe set up for a retry, or continue in a retry loop
    print "Time out exception thrown: %s" % (e)
    sys.exit(1)
except requests.exceptions.TooManyRedirects as e:
    # Tell the user their URL was bad and try a different one
    print "Too many re-directs exception thrown: %s" % (e)
    sys.exit(1)
except requests.exceptions.HTTPError as e:
    print "ERROR: HTTPError exception thrown: %s" % (e)
    sys.exit(1)
except requests.exceptions.RequestException as e:
    # catastrophic error. bail.
    print "Requests exception thrown: %s" % (e)
    sys.exit(1)

print "Response Status: " + str(response.status_code)

json_data = json.loads(response.text)

accessToken = json_data.get("access_token")

#print "AccessToken: " + accessToken
#print

auth = 'Bearer ' + accessToken

headers = { 'Authorization': auth,
            'X-DeviceNetwork': adal_obj['deviceNetworkId'],
            'Content-type': 'application/json' }

sensors = { "Temperature":"d51d3b56-28e6-48a6-8992-95609d137760",
            "Is_Open":"6e01f16b-f7f7-4fd0-b0e7-3f6c796807ab",
            "Is_Tilted":"e3183f59-4eaa-4523-b0c1-f3b53d3d60a5" }

for sensor_name,sensor_id in sensors.iteritems():

    url = 'https://eappiot-api.sensbysigma.com/api/v2/sensors/%s/latestmeasurement' % (sensor_id)
    try:
        response = requests.get(url, headers=headers, proxies="")
    except requests.exceptions.Timeout as e:
        # Maybe set up for a retry, or continue in a retry loop
        print "ERROR: Time out exception thrown: %s" % (e)
        sys.exit(1)
    except requests.exceptions.TooManyRedirects as e:
        # Tell the user their URL was bad and try a different one
        print "ERROR: Too many re-directs exception thrown: %s" % (e)
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print "ERROR: HTTPError exception thrown: %s" % (e)
        sys.exit(1)
    except requests.exceptions.RequestException as e:
        # catastrophic error. bail.
        print "ERROR: Requests exception thrown: %s" % (e)
        sys.exit(1)

    print "%s: " % (sensor_name),
    print response.content
