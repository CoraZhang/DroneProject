#!/usr/bin/python

##############################################################################
# FMSgetAllSensorData.py
# By Fredrik Bolzek (fredrik.bolzek@ericsson.com), 
#    Solutions&Engagements
#    Linkoping, Sweden
# (c) Ericsson AB
#
# Synopsis:
# --------
# Get sensor data for the Test device with a temperature sensor.
# Sensor data for Temperaturevalue, MaxTemperature, MinTemperature
#
# Version History:
# ---------------
# v0.1 2018/10/06 Fredrik Bolzek
# - Original version.  Based on get_all_sensor_data.py by David Thomas J, Ericsson
#   Canada Inc.
##############################################################################

import sys
import json
import requests

# Read in authentication related parameters from JSON config file.
jsondir = ""
parameters_file = "adal.config.json"
parameters = ""
sensors_file = "sensors.json"
sensors = ""

sys.stdout.write("Reading IoT Accelerator DDM config file...")
try:
    with open(jsondir+parameters_file, 'r') as f:
        for line in f:
         	  if not line.startswith("#"):
     		        parameters += line
    print"Success!"
    #print parameters
except IOError:
    print("ERROR!!!")
    print("DDM JSON configuration file %s does not seem to exist") % (jsondir+parameters_file)
    exit()
adal_config = json.loads(parameters)

sys.stdout.write("Reading sensor config file...")
try:
    with open(jsondir+sensors_file, 'r') as g:
        for line in g:
         	  if not line.startswith("#"):
     		        sensors += line
    print"Success!"
    #print sensors
except IOError:
    print("ERROR!!!")
    print("DDM JSON sensor file %s does not seem to exist") % (jsondir+sensors_file)
    exit()
adal_sensors = json.loads(sensors)

headers = { 'Authorization': adal_config['AccessToken'],
            'X-DeviceNetwork': adal_config['deviceNetworkId'],
            'Accept': 'text/plain' }

for sensor_name,sensor_id in adal_sensors.iteritems():
    if "ID" in sensor_name:
        sys.stdout.write("Reading sensor value from DDM for %s..." % sensor_name)
        url = adal_config['GETurlBase']+(sensor_id)
        response = requests.get(url, headers=headers, proxies="")
        if response.status_code == 200:
            json_response = json.loads(response.content)
            #print response.content
            json_LatestMeasurement = json_response.get('LatestMeasurement')
            print "Success! ResponseCode: %s Value: %s" % (str(response.status_code),json_LatestMeasurement.get("v"))
        else:
            print "ERROR!!!"
            print "ERROR: ResponseCode: "+ str(response.status_code) + ": \n" + response.text
     
