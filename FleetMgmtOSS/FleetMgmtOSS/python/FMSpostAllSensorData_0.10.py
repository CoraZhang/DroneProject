#!/usr/bin/python

##############################################################################
# FMSpostAllSensorData.py
# By Fredrik Bolzek (fredrik.bolzek@ericsson.com), 
#    Solutions&Engagements
#    Linkoping, Sweden
# (c) Ericsson AB
#
# Synopsis:
# --------
# Post sensor data for the Test device with a temperature sensor.
# Sensor data for Temperaturevalue, MaxTemperature, MinTemperature
#
# Version History:
# ---------------
# v0.1 2018/10/06 Fredrik Bolzek
# - Original version.  Based on get_all_sensor_data.py by David Thomas J, Ericsson
#   Canada Inc.
##############################################################################

import sys
import time
import json
import requests

if len(sys.argv) != 4:
    print "ERROR: Require sensor data to post."
    print "Sensor data order: Temperature MaxTemperature MinTemperature  "
    sys.exit(1)


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

def post_sensor_data(sensor_URN, new_sensor_value):
    #
    # Get current time in seconds. (works with or without trailing milliseconds)
    time_now = int(time.time())
    #
    # Create http body with sensor data.
    # {
    # "bu":"default-unit",
    # "e":[
    #   {
    #     "n":"[Endpoint]/[ObjectID]/[InstanceID]/[ResourceID]",
    #     "u":"default-unit",
    #     "v":null,   (Numeric Value)
    #     "bv":false, (Boolean Value) 
    #     "sv":null,  (String Value)
    #     "t":1538546399 (Timestamp in Seconds)
    #   }
    #   ]
    # }
    sensor_data = '{"bu":"default-unit","e":[{"n":"%s","u":"default-unit","v":%s,"bv":null,"sv":null,"t":%s}]}' % (sensor_URN, new_sensor_value, time_now)
    #
    return(sensor_data)

###############################################################################

# URL for posting sensor data to DDM.
url = adal_config['POSTurlBase']+adal_config['gatewayId']+adal_config['POSTurlEXT']
#print (url)
# Create headers (http://docs.appiot.io/?page_id=43134)
header_data = { 'DataCollectorId': adal_config['gatewayId'],
            'Authorization': adal_config['httpSAS'],
            'PayloadType': 'application/senml+json',
            'Content-Type': 'application/json' }

# Associate command-line inputs with target sensor.
sensor_inputs = { "TemperatureValueURN":sys.argv[1], "MaxTemperatureURN":sys.argv[2], "MinTemperatureURN":sys.argv[3],  }

for sensor_name,sensor_URN in adal_sensors.iteritems():
    if "URN" in sensor_name:
        sys.stdout.write("Posting %s = %s..." % (sensor_name,sensor_inputs[sensor_name]))
        # Debug
        #print ("\nsensor_name: %s, sensor_URN: %s, New Sensor value: %s") % (sensor_name,sensor_URN,sensor_inputs[sensor_name])
        #print ("sensor_data: %s") % (sensor_data)
        #print ("header_data: %s") % (header_data)
        (sensor_data) = post_sensor_data(sensor_URN, sensor_inputs[sensor_name]) 
        response = requests.post(url, data=sensor_data, headers=header_data)
    
        if str(response.status_code) != "201":
            print "Error: ResponseCode: "+ str(response.status_code) + ": \n" + response.text
            sys.exit(1)

        print "Success! ResponseCode: %s" % (str(response.status_code))
