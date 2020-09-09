#!/usr/bin/env python
import os
import time
import sys
import requests
import RPi.GPIO as GPIO
from w1thermsensor import W1ThermSensor

door_pin = 16
tilt_pin = 13
orange_led_pin = 37
orange_led_state = GPIO.LOW
green_led_pin = 35
sensor_temp = W1ThermSensor()
is_door_open = 0  # False
is_tilted = 0  # False

# From APP IoT 
# gateway_id = 'fffb8fc8-6eae-4368-86c2-6eb75c3ff015'
gateway_id = 'fffb8fc8-6eae-4368-86c2-6eb75c3ff015'
# APP IoT Mailbox URL for passing in sensor data.
# url = 'https://eappiotsens.servicebus.windows.net/datacollectoroutbox/publishers/%s/messages' % (gateway_id)
url = 'https://eappiotsens.servicebus.windows.net/datacollectoroutbox/publishers/%s/messages' % (gateway_id)
# Sensor that we have defined in APP IoT.
# sensors = { "Temperature":"ed6abeaf-37b8-4af6-af0e-d9d377cfcf82",
#             "Is_Open":"8d77241f-07cc-4990-b7f5-e07ff3b773f2",
#             "Is_Tilted":"5a0cc0cf-5bcc-4106-95c8-be52855eb145" }
sensors = { "Temperature":"d51d3b56-28e6-48a6-8992-95609d137760",
            "Is_Open":"6e01f16b-f7f7-4fd0-b0e7-3f6c796807ab",
            "Is_Tilted":"e3183f59-4eaa-4523-b0c1-f3b53d3d60a5" 
          }
# From the APP IoT Gateway ticket.
# httpSAS = 'SharedAccessSignature sr=https%3a%2f%2feappiotsens.servicebus.windows.net%2fdatacollectoroutbox%2fpublishers%2ffffb8fc8-6eae-4368-86c2-6eb75c3ff015%2fmessages&sig=jCs12Zn4hYYHZmaPN8wjVLmawTJJnombeD4MKMgQ2X8%3d&se=4632434417&skn=SendAccessPolicy'
httpSAS = 'SharedAccessSignature sr=https%3a%2f%2feappiotsens.servicebus.windows.net%2fdatacollectoroutbox%2fpublishers%2ffffb8fc8-6eae-4368-86c2-6eb75c3ff015%2fmessages&sig=jCs12Zn4hYYHZmaPN8wjVLmawTJJnombeD4MKMgQ2X8%3d&se=4632434417&skn=SendAccessPolicy'



def post_data(sensor_id, sensor_value, gateway_id):
    #
    # Convert seconds since the Epoch to a date/time: datetime.datetime.fromtimestamp(1172969203)
    # Convert date/time to seconds since the Epoch: now = datetime.datetime.fromtimestamp(1172969203); now.strftime("%s")
    #
    time_now = int(time.time()*1000.0)  # note: need to be in unit of millisecond or second?
    # time_now = int(time.time())  # note: need to be in unit of millisecond or second?
    # print ("time stamp:", time_now)

    sensor_data = '[{"id":"%s","v":[{"m":[%s],"t":%d}]}]' % (sensor_id, sensor_value, time_now)

    headers = { 'Authorization': httpSAS,
                'DataCollectorId': gateway_id,
                'PayloadType': 'Measurements',
                'Timestamp': time_now,
                'Cache-Control': 'no-cache',
                'Content-Length': len(sensor_data) }
    return(headers,sensor_data)

def setup():
    GPIO.setmode(GPIO.BOARD)
    GPIO.setup(door_pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)  # activate input with PullUp
    GPIO.setup(tilt_pin, GPIO.IN, pull_up_down=GPIO.PUD_UP) # Set BtnPin's mode is input, and pull up to high level(3.3V)
    GPIO.setup(orange_led_pin, GPIO.OUT) # setup pin
    GPIO.output(orange_led_pin, GPIO.HIGH) # light the LED
    GPIO.setup(green_led_pin, GPIO.OUT) # setup pin
    GPIO.output(green_led_pin, GPIO.HIGH) # light the LED

def loop():

    is_door_open = 0  # False
    is_tilted = 0  # False
    orange_led_state = GPIO.HIGH

    while True:
        print time.ctime()
        temp_in_celsius = sensor_temp.get_temperature()
        temp_in_fahrenheit = sensor_temp.get_temperature(W1ThermSensor.DEGREES_F)
        if GPIO.input(door_pin):
            sys.stdout.write("DOOR ALARM: ")
            is_door_open = 1  # True
            GPIO.output(green_led_pin, GPIO.HIGH) # light the green LED
        else:
            sys.stdout.write("DOOR CLOSE: ")
            is_door_open = 0  # False
            GPIO.output(green_led_pin, GPIO.LOW) # turn off the green LED
        if not GPIO.input(tilt_pin):
            sys.stdout.write(" Tilt: ")
            is_tilted = 1  # True
            if orange_led_state == GPIO.HIGH:
                GPIO.output(orange_led_pin, GPIO.LOW)
                orange_led_state = GPIO.LOW
            else:
                GPIO.output(orange_led_pin, GPIO.HIGH)
                orange_led_state = GPIO.HIGH
        else:
            sys.stdout.write(" Flat: ")
            is_tilted = 0  # False
            GPIO.output(orange_led_pin, GPIO.LOW) # turn off the orange LED
            orange_led_state = GPIO.LOW

        sys.stdout.write("Temp ")
        sys.stdout.flush()
        print("{0} C / {1} F".format(temp_in_celsius,temp_in_fahrenheit))

        # Associate command-line inputs with target sensor.
        sensor_inputs = { "Temperature":temp_in_fahrenheit, "Is_Open":is_door_open, "Is_Tilted":is_tilted }
        for sensor_name,sensor_id in sensors.iteritems():
            # print "Posting: " + sensor_name
            sensor_value = sensor_inputs[sensor_name]
            print "Posting: " + sensor_name + " = " + str(sensor_value)
            (header_data, sensor_data) = post_data(sensor_id, sensor_value, gateway_id) 
            # print url + ", " + str(sensor_data) + ", " + str(header_data)
            # print "POSTing... awaiting response."

            response = None

            try:
		response = requests.request('POST', url, data=sensor_data, headers=header_data, timeout=10)
            except requests.exceptions.RequestException as e:
		print "  ERROR: RequestException: %s" % e
                continue
	    finally:
		# print "  WARNING: unexpected condition.  POST may not have been successful."

                if str(response.status_code) != "201":
                   print "  ERROR: Post Response: "+ str(response.status_code) + ": " + response.text
                   # sys.exit(1)
                else:
                   # print "Posted %s: %s" % (sensor_name, sensor_data)
                   print "  SUCCESS: Post Status: " + str(response.status_code) + ": " + response.text

        # wait 1 second for each loop
        time.sleep(5.0)

if __name__ == '__main__': # Program start from here
    setup()
try:
    loop()
except KeyboardInterrupt: # When 'Ctrl+C' is pressed, the child program destroy() will be executed.
    GPIO.cleanup()  # Release resource
    pass
finally:
    GPIO.cleanup()  # Release resource
