#!/usr/bin/perl

##############################################################################
# FMSgetSensorData.pl
# By Fredrik Bolzek (fredrik.bolzek@ericsson.com), 
#    Solutions&Engagements
#    Linköping, Sweden
# (c) Ericsson AB
#
# Synopsis:
# --------
# Get sensor data for the fleetsim.pl demo.
# Sensor data for temperature, tilt (accident), and doors for Truck 0.
#
# Version History:
# ---------------
# v0.20 2018/10/06 Fredrik Bolzek
# - Original version.  Based on postSensorData.pl by Chris Spencer, Ericsson
#   Canada Inc.
# v0.20a 2018/10/06 Fredrik Bolzek
# - adapted for sensor with data for TemperatureValue, maxTemperature, and 
#   MinTemperature.
##############################################################################
$| = 1;

##############################################################################
# libraries
##############################################################################
use File::Basename;
#use Time::Local;
#use Time::HiRes qw(sleep time);
#use Text::Wrap;
#use Cwd;
#use LWP::Simple qw(!head);  # head() exists in several mods; don't need the LWP version.
use REST::Client;
use JSON;
use Data::Dumper;
#use MIME::Base64;
#use URI::Encode qw(uri_encode uri_decode);

##############################################################################
# globals
##############################################################################
my $VERSION = '0.20a';
my($SCRIPT, $PATH, $EXT) = fileparse($0, '.pl');
my $DEBUG = 0; # set by -d command-line option

# Change the following Author values as needed.
my $AuthorName = 'Fredrik Bolzek';
my $AuthorEmail = 'fredrik.bolzek@ericsson.com';
my $AuthorDept = 'Solutions&Engagements';
my $AuthorCompany = 'Ericsson AB';
my $AuthorLocation = 'Linköping, Sweden';

# date/time globals
my $runTm = time();
my @MONS = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
my @WEEKDAYS = qw(SUN MON TUE WED THU FRI SAT);
my $MINUTE = 60; # seconds
my $HOUR = 60 * $MINUTE; 
my $DAY = 24 * $HOUR; 
my $WEEK = 7 * $DAY; 
my $MONTH = 30 * $DAY;
my $QUARTER = 91 * $DAY;
my $YEAR = 365 * $DAY;
my $MODTIME = 9; # index of file modtime in stat() output
my $COPYRIGHTYEAR = &getYear();

##############################################################################
# Configuration Data
##############################################################################
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

my $JsonDir = '';
my $JsonConfig = 'adal.config.json';
my $JsonSensors = 'sensors.json';

# Initiate variable to store DDM configuation data
my %Config = ();
my $Client = undef;
my $Url = undef;

# Initiate variable to store DDM sensor data
my %Sensor = ();
my %Data = ();
my %Success = ();

my $CLOSE = 0; # door closed
my $OPEN = 1; # door open
my $UPRIGHT = 0; # truck upright
my $TILTED = 1; # truck tilted/rolled-over

##############################################################################
# main
##############################################################################
$SIG{INT} = \&ctrlC; # Ctrl-C interrupt handler

&stderr("$SCRIPT$EXT v$VERSION");
&stderr('-' x length("$SCRIPT$EXT v$VERSION"));

&parseArgs;
&readIoTAcceleratorDDMConfig;
&readSensorConfig;
&getSensorDataToDDM;
 
exit;

##############################################################################
# subroutines
##############################################################################

##############################################################################
sub ctrlC
{
 &warning("User typed Ctrl-C.  Exiting.");
 &quit;
}

##############################################################################
sub parseArgs
{
 # Process all command-line arguments
 my $arg;

 while(@ARGV)
   {
    $arg = shift(@ARGV); # take first argument and shift @ARGV
    &debug("parseArgs: arg = $arg");

    if($arg eq '-h' || $arg eq '-?') # help
      {
       &help;
       exit;
      }
    elsif($arg eq '-d') # debug
      { 
       $DEBUG = 1;  # debug mode is enabled
       &debug("Debug mode enabled.");
       &debug("parseArgs: @ARGV");
      }
  } # end while argv 
}

##############################################################################
sub help
{
 print STDERR <<EOH;

Syntax: $SCRIPT$EXT [-d|-h]

Generate JSON data for the IoT CAT-M/NB-IoT Fleet Management demo.

Options:
-h : This help.
-d : Debug mode.

By $AuthorName ($AuthorEmail), $AuthorDept
   $AuthorCompany, $AuthorLocation
EOH
 &stderr("Copyright (c) Ericsson AB ".&getYear());
}

##############################################################################
sub stderr
{
 my($msg) = join(" ", @_);
 print STDERR "$msg\n";
}

##############################################################################
sub error
{
 my($err) = join(" ", @_);
 &stderr("FATAL ERROR: $err");
 exit;
}

##############################################################################
sub warning
{
 my($msg) = join(" ", @_);
 &stderr("Warning: $msg"); 
}

##############################################################################
sub debug
{
 my($msg) = join(" ", @_);
 &stderr("DEBUG: $msg") if $DEBUG;
}

##############################################################################
sub getYear
{
 # Return the 4-digit year for the given epoch-time (tm).
 my($tm) = @_;
 $tm = time() unless $tm;
 my $year = (localtime($tm))[5];
 $year += 1900 if($year < 1900);
 return $year;
}

##############################################################################
sub f2c
{
 # convert farenheit to celsius
 my($f) = @_;
 return sprintf("%0.1f", ($f - 32)/1.8);
}

##############################################################################
sub readIoTAcceleratorDDMConfig 
{
 # The IoT Accelerator DDM config from the sensor.json file in the JsonDir
 print("Reading IoT Accelerator DDM config file...");

 my $jsonConfigFile = $JsonDir.$JsonConfig;
 &debug("JSON IoT Accelerator DDM config file: $jsonConfigFile");
 &debug("Paremter => Value");
 &debug("=================");
 if(open(CONF, $jsonConfigFile))
   {
    while(<CONF>)
      {
      chomp;
       if(/^\s*\"([^\"]*)\"\s*:\s*\"([^\"]*)\"/)
         { 
          &debug("$1 => $2");
          $Config{$1} = $2; 
         }
      } # end while conf
    close(CONF);
    &debug("=================");
    $Url = $Config{GETurlBase};
    &debug("URL: ".$Url);
   } # end if open config file
 else
   { &error("Cannot read IoT Accelerator config file: $jsonConfigFile"); }
 &stderr("Success!");
}

##############################################################################
sub readSensorConfig
{
 # The sensor config from the sensor.json file in the JsonDir.
 print("Reading sensor config file...");
 my $jsonSensorFile = $JsonDir.$JsonSensors;
 &debug("JSON sensor file: $jsonSensorFile");
 &debug("Sensor => Sensor ID");
 &debug("=================");
 if(open(CONF, $jsonSensorFile))
   {
    while(<CONF>)
      {
       chomp;
       if(/^\s*\"([^\"]*)ID\"\s*:\s*\"([^\"]*)\"/)
         { 
          $Sensor{$1} = $2; 
          &debug("$1 sensor ID = $Sensor{$1}");
         }
      } # end while conf
    close(CONF);
    &debug("=================");
   }
 else
   { &error("Cannot read sensor config file: $jsonSensorFile"); }
 &stderr("Success!");
}

##############################################################################
sub getSensorDataToDDM
{ 
 # Get sensor Data from DDM.
 #&debug("Sensor:".Dumper(%Sensor));
 foreach my $check (keys(%Sensor))
   { &debug("Sensor: $check: $Sensor{$check}"); }

 foreach my $sensor (sort(keys(%Sensor)))
   {
    ($Data{$sensor},$Success{$sensor}) = &DDMQuerySensor($sensor);
   } # end foreach sensor
 
 # Debug information
 foreach my $checkdata (keys(%Data))
  { &debug("Data: $checkdata: $Data{$checkdata}"); }
 foreach my $checksuccess (keys(%Success))
  { 
  	&debug("Success: $checksuccess: $Success{$checksuccess}"); 
    if ($Success{$checksuccess} == 0)
      { exit; }
  }

}

##############################################################################
sub DDMQuerySensor
{
 # Read sensor data from DDM
 my($sensorname) = @_;
 print("Reading sensor value from DDM for $sensorname...");
 my $rc = 0;
 my $body = undef;
 my $success = undef;

 &debug("");
 &debug("Creating URL for $sensorname with ID: $Sensor{$sensorname}...");
 my $SensorUrl = $Url.$Sensor{$sensorname};
 &debug("SensorUrl: $SensorUrl");

 my $header = {
          'Authorization' => $Config{AccessToken},
          'X-DeviceNetwork' => $Config{deviceNetworkId},
          'Accept'=> 'text/plain'
          };

 # Debug information
 &debug("Header:".Dumper($header));
 $Client = REST::Client->new(timeout=>25);
 $Client->GET($SensorUrl, $header);
 if($Client->responseCode() == 200)
   {
     my $response = from_json($Client->responseContent());
     my $type = ref($response);
     if($type eq 'HASH') 
       { 
        #&debug("json response from Client: ".Dumper($response)); #json decode of the data content
        $rc = $response->{LatestMeasurement}->{v};
        &debug("ResourceName = " .$response->{Url});
        &debug("Value: $rc");
        &stderr("Success! ResponseCode: ".$Client->responseCode()." Value: $rc");
        $success = 1
       }
     else # what the?
       { &warning("Unknown response type for sensor $sensorname: refType=$type"); }
    }
 elsif($Client->responseCode() == 408 ) # request time-out
   {
    &warning("RepsonsCode: ".$Client->responseCode().". Request Time out");
   }
 elsif ($Client->responseCode() == 500 )  # Internal Server Error
   {
    &warning("RepsonsCode: ".$Client->responseCode().". Intenral Server Error");
   }
 else # problem
   { 
   	 &warning("Query sensor failed: ".$Client->responseCode().': '.$Client->responseContent()); 
   }
  if($Client->responseCode() != 200)
   {
   	 $success = 0
   }
 &debug("Success: $success");  
 return ($rc,$success);
}
