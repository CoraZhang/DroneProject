#!/usr/bin/python

import sys
import time
import json
import requests

if len(sys.argv) != 4:
    print "ERROR: Require sensor data to post."
    print "Sensor data order: DoorMagnetPosition TiltSensorPosition Temperature "
    sys.exit(1)

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

def post_sensor_data(sensor_URN, new_sensor_value):
    
    # TestTruck from the APP IoT 2.0 Gateway ticket.
    #httpSAS = 'SharedAccessSignature sr=https%3a%2f%2fiotabusinesslab.servicebus.windows.net%2fdatacollectoroutbox%2fpublishers%2fb1f81aca-0924-49d1-a5bd-fc985740b8b0%2fmessages&sig=jlwPrYLo5O9Sl7NBHHEAUACFbDTe0Pw%2b3GEybRIDkeA%3d&se=4694177373&skn=SendAccessPolicy'
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

# TestTruck Gateway From APP IoT 
#gateway_id = 'b1f81aca-0924-49d1-a5bd-fc985740b8b0'

# APP IoT Mailbox URL for passing in sensor data.
url = 'https://iotabusinesslab.servicebus.windows.net/datacollectoroutbox/publishers/%s/messages' % (adal_obj['gatewayId'])

# Create headers (http://docs.appiot.io/?page_id=43134)
header_data = { 'DataCollectorId': adal_obj['gatewayId'],
            'Authorization': adal_obj['httpSAS'],
            'PayloadType': 'application/senml+json',
            'Content-Type': 'application/json' }

# Associate command-line inputs with target sensor.
sensor_inputs = { "DoorMagnetPositionURN":sys.argv[1], "TiltSensorPositionURN":sys.argv[2], "TemperatureValueURN":sys.argv[3] }

for sensor_name,sensor_URN in adal_sensors.iteritems():
    if "URN" in sensor_name:
        print ("sensor_name: %s, sensor_URN: %s") % (sensor_name,sensor_URN)
        new_sensor_value = sensor_inputs[sensor_name]
        print ("New Sensor value: %s") % (new_sensor_value)
        (sensor_data) = post_sensor_data(sensor_URN, new_sensor_value) 
        print ("sensor_data: %s") % (sensor_data)
        print ("header_data: %s") % (header_data)
        response = requests.post(url, data=sensor_data, headers=header_data)
    
        if str(response.status_code) != "201":
            print "Error: Post Response: "+ str(response.status_code)
            sys.exit(1)

        print "Posted %s: %s" % (sensor_name, sensor_data)
        print "Post Response Status: " + str(response.status_code)
