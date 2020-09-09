#!/usr/bin/python

import sys
import json
import requests

# Read in authentication related parameters from JSON config file.
parameters_file = "adal.config.json"

if parameters_file:
    with open(parameters_file, 'r') as f:
        parameters = f.read()
    adal_obj = json.loads(parameters)
else:
    raise ValueError('Please provide parameter file with account information.')

headers = { 'Authorization': adal_obj['AccessToken'],
            'X-DeviceNetwork': adal_obj['deviceNetworkId'],
            'Accept': 'text/plain' }
            
sensors = { "Temp_ValueID":"ae8847bd-200f-48e1-a8e6-9b9763a93ab6", 
            "Temp_MaxID":"f9282688-7148-4b25-a5b7-01a74d10ef6e",
            "Temp_MinID":"ec33205f-61ec-49a7-8a55-44af748b293e" }

for sensor_name,sensor_id in sensors.iteritems():
    url = 'https://lab.api.iot-accelerator.ericsson.net/ddm/api/v3/resources/%s' % (sensor_id)
    response = requests.get(url, headers=headers, proxies="")
    json_response = json.loads(response.content)
    #print response.content
    json_LatestMeasurement = json_response.get('LatestMeasurement')

    print "%s: " % (sensor_name)
    print "Name: %s, Values: %s" % (json_response.get("Name"),json_LatestMeasurement.get("v"))
     

