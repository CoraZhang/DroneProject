# Runs with Python 2
# By Austin Greisman
# To be placed in Adafruit_PCA9685/examples folder on Raspberry PI
#
# Used on Raspberry Pi as the Server for computer to connect to.
# More information on PWM board @ https://learn.adafruit.com/16-channel-pwm-servo-driver?view=all

import socket
import Adafruit_PCA9685
import time
import re
import sys
import select

pwm = Adafruit_PCA9685.PCA9685()
# Determinded via testing
MIN_VALUE = 230
ZERO_VALUE = 325

pwm.set_pwm_freq(100)
# Output file
current_output_name = time.strftime("%Y-%m-%d_%H:%M:%S", time.gmtime())

# Creates log of events everytime script runs. Saves in the current directory
output_file = open("%s.log" % (current_output_name), 'w')

def disconnected(c, s):
    printboth("Cannot Send... Must be disconnected from Controller... Resetting Speeds...")
    talktopi(ZERO_VALUE, ZERO_VALUE, ZERO_VALUE, ZERO_VALUE)
    time.sleep(1)
    talktopi(ZERO_VALUE, ZERO_VALUE, MIN_VALUE, ZERO_VALUE)
    c.close()
    s.close()

def printboth(line):
    sys.stdout.write("%s\n" % (line))
    output_file.write("%s\n" % (line))

#A = Roll, E = Pitch, T = Throttle, R = Yaw
def talktopi(aileron, elevator, throttle, rudder):
    #printboth("Roll: %s, Pitch: %s, Yaw: %s, Throttle: %s, "%(aileron, elevator, rudder, throttle))
    
    pwm.set_pwm(0, 0, int(aileron)) #A
    pwm.set_pwm(3, 0, int(elevator))  # E
    pwm.set_pwm(4, 0, int(throttle))  # T
    pwm.set_pwm(7, 0, int(rudder))  # R
    time.sleep(0.01)

def Main():

    printboth("\n\n\n New Execution @%s....\n\n\n"%(time.strftime("%Y-%m-%d_%H:%M:%S", time.gmtime())))
    values = []
    # Auto grab host name
    ip = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    ip.connect(("8.8.8.8", 80))
    host = ip.getsockname()[0]
    port = 6970

    #Listing properties
    printboth("Server IP: %s"%(host))
    printboth("Server PORT: %d"%(port))

    s = socket.socket()
    s.bind((host, port))

    s.listen(1)
    c, addr = s.accept()
    c.settimeout(3)
    printboth("Connection from: " + str(addr))
    while True:
        #Trys to send data to Controller to maintain sync
        try:
            c.send('1')
        except:
            disconnected()
            break
        #Recieves data from Controller to grab current values
        try:
            data = c.recv(60).decode('utf-8') #60 bits of utf-8
        except socket.error, e:
            err = e.args[0]
            if err == 'timed out':
                disconnected(c, s)
                break
            else:
                printboth(e)
                break
        # A = Roll, E = Pitch, T = Throttle, R = Ya
        values = re.split(",+", data)
        try:
            talktopi(values[0], values[1], values[2], values[3])
        except IndexError:
            printboth("Index Error... Most likely connection down..")
            disconnected(c, s)
            break
    c.close()
    s.close()

    #Go again
    #Main()

if __name__ == '__main__':
    # Ensures that there is a network connection for the script to run properly
    while True:
        try:
            Main()
            time.sleep(5)
        except socket.error, e:
            err = e.args[0]
            if err == 101:
                printboth("Network is unreachable.. Connecting..")
                time.sleep(10)
            elif err == 98:
                printboth("Socket is unavailable... Waiting")
                time.sleep(10)
            else:
                printboth(">%s< &%s "%(err, e))
                break
    output_file.close()
    print("Output file closed...")



