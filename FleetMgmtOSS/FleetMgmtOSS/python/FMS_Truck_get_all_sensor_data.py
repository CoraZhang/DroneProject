#!/usr/bin/python

import sys
import json
import requests

# Read in authentication related parameters from JSON config file.
parameters_file = "adal.config.json"
sensor_file = "sensor.json"

if parameters_file:
    with open(parameters_file, 'r') as f:
        parameters = f.read()
    adal_obj = json.loads(parameters)
else:
    raise ValueError('Please provide parameter file with account information.')

if sensor_file:
    with open(sensor_file, 'r') as g:
        sensors = g.read()
    adal_sensors = json.loads(sensors)
else:
    raise ValueError('Please provide sensor file with sensor information.')

headers = { 'Authorization': adal_obj['AccessToken'],
            'X-DeviceNetwork': adal_obj['deviceNetworkId'],
            'Accept': 'text/plain' }

for sensor_name,sensor_id in adal_sensors.iteritems():
    if "ID" in sensor_name:
        url = 'https://lab.api.iot-accelerator.ericsson.net/ddm/api/v3/resources/%s' % (sensor_id)
        response = requests.get(url, headers=headers, proxies="")
        json_response = json.loads(response.content)
        #print response.content
        json_LatestMeasurement = json_response.get('LatestMeasurement')
    
        print "%s: " % (sensor_name)
        #print "Name: %s, Values: %s" % (json_response.get("Name"),json_response.get("LatestMeasurement"))
        #print "Name: %s, Values: %s" % (json_response.get("Name"),json_LatestMeasurement.get("Values"))
        print "Name: %s, Values: %s" % (json_response.get("Name"),json_LatestMeasurement.get("v"))
     
