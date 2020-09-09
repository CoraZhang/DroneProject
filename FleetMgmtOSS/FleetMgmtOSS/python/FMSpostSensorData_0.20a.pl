#!/usr/bin/perl

##############################################################################
# FMSpostSensorData.pl
# By Chris Spencer (christopher.b.spencer@ericsson.com), 
#    DURA LMR TDS
#    Ottawa, Ontario, CANADA
# (c) Ericsson Canada Inc.
#
# Synopsis:
# --------
# Post manually-provided sensor data to DDM.
# Sensor data for TemperatureValue, maxTemperature, and MinTemperature.
#
# Version History:
# ---------------
# v0.10 2016/11/02 Chris Spencer
# - Original version.  Based on post_sensor_data.py by David Thomas J, Ericsson
#   Canada Inc.
# v0.1x 20xx/xx/x Chris Spencer
# - Read sensor data from sensor.json
# v0.20 2018/10/06 Fredrik Bolzek
# - Modifed to work with DDM, Data and device Management
# - Moved all configuration variable to the adal.config.json file.
# - adapted debug parts
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
#use JSON;
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
my $AuthorName = 'Chris Spencer B.';
my $AuthorEmail = 'christopher.b.spencer@ericsson.com';
my $AuthorDept = 'DURA LMR TDS';
my $AuthorCompany = 'Ericsson Canada Inc.';
my $AuthorLocation = 'Ottawa, ON, Canada';

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
&postSensorDataToDDM;

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
    elsif(defined($Data{MaxTemperature})) # Second argument DoorMagnetPosition is handled
      { $Data{MinTemperature} = "$arg"; }
    elsif(defined($Data{TemperatureValue})) # First argument Temperature is handled
      { $Data{MaxTemperature} = "$arg"; }
    else # Handle first argument as temperature
      { $Data{TemperatureValue} = "$arg"; }
  } # end while argv 
  unless(defined($Data{TemperatureValue}) && defined($Data{MaxTemperature}) && defined($Data{MinTemperature}))
    { &error("Provide [-h|-d] Temperature ($Data{TemperatureValue}), MaxTemperature ($Data{MaxTemperature}), and MinTemperature ($Data{MinTemperature}) on command line."); }
}

##############################################################################
sub help
{
 print STDERR <<EOH;

Syntax: $SCRIPT$EXT [-d|-h] <TemperatureValue> <MxTemperature> <MinTemperature>

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
    $Url = $Config{POSTurlBase}.$Config{gatewayId}.$Config{POSTurlEXT};
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
 &debug("Sensor => Sensor URN");
 &debug("=================");
 if(open(CONF, $jsonSensorFile))
   {
    while(<CONF>)
      {
       chomp;
       if(/^\s*\"([^\"]*)URN\"\s*:\s*\"([^\"]*)\"/)
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
sub postSensorDataToDDM
{
 # Post sensor Data to DDM.
 $Client = REST::Client->new(timeout=>25);
 my $header = { 
         'Authorization' => $Config{httpSAS},
         'DataCollectorId' => $Config{gatewayId},
         'PayloadType' => 'application/senml+json',
         'Content-Type' => 'application/json'  
        };

 &debug("Url: $Url");
 &debug("Data: $data");
 &debug("Header:".Dumper($header));

 foreach my $sensor (sort(keys(%Sensor)))
   {
    print("Posting $sensor = $Data{$sensor} ...");
    my $ms = int($runTm);
    &debug("");
    &debug("Time: $ms");
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
    #  ]
    # }
    my $data = '{"bu":"default-unit","e":[{"n":"' . $Sensor{$sensor} . '","u":"default-unit","v":' . $Data{$sensor} . ',"bv":null,"sv":null,"t":' . $ms . '}]}';
    &debug("$sensor data = $data");
    $Client->POST($Url, $data, $header);
    if($Client->responseCode() == 201)
      { &stderr("Success! ResponseCode: " . $Client->responseCode()); }
    else # problem
      { &error("- $sensor post failed: ".$Client->responseCode().': '.$Client->responseContent()); }
   } # end foreach sensor
}