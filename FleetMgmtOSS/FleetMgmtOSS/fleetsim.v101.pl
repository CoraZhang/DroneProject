#!/usr/bin/perl

# #!/opt/tools/tools/perl/5.12.2/bin/perl

##############################################################################
# fleetsim.pl
# By Chris Spencer (christopher.b.spencer@ericsson.com), 
#    DURA LMR TDS
#    Ottawa, Ontario, CANADA
# (c) Ericsson Canada Inc.
#
# Synopsis:
# --------
# Generate a simulated run of 3 trucks following routes on Google Maps, using
# real-time sensor data for temperature, tilt (accident), and doors for Truck 0.
#
# Version History:
# ---------------
# v0.10 2016/10/14 Chris Spencer
# - Original version.  Generate JSON data files for each 'truck' in the fleet,
#   to provide simulated demo data for the IoT CAT-M fleet management demo.
# v0.20 2016/10/21 Chris Spencer
# - Removed possibilities for problems in all but the first (0th) truck, per
#   SPM & Marketing requests.
# v0.30 2016/10/26 Chris Spencer
# - Added online demo support, via AppIoT.  Converted Python code supplied by
#   David Thomas J.
# - Added -offline flag, so that offline and online demos could be performed
#   from the same script.
# v0.40 2016/11/04 Chris Spencer
# - Added -chance option.
# - Enhanced getTemperature() routine.
# v0.50 2016/11/18 Chris Spencer
# - Added support for the following geilds/instructions to truck route*.dat files:
#   route:, dest:, name:, driver:, delivery, door, accident, rollover, and 
#   temperature:.
# - Added 'Not Left' to Delivery Status.
# - Warehouse location defaults to truck 0's starting point if no warehouse.dat 
#   file is found.
# - If trucks 1-3 don't have routes, then leave them at the warehouse.
# - Increased simulation's default duration to one hour.
# - Automatically increase the simulations duration so that each truck route
#   can be completed at least once.
# - General improvements and code cleanup.
# v0.60 2016/11/25 Chris Spencer
# - Added support for zero percent/chance of random events.
# v0.70 2016/12/09 Chris Spencer
# - Added TempAdjust.
# - Added log file, to help with future troubleshooting.  A new timestamped log 
#   file is created each time the script is run.  Currently, no effort is made
#   to clean-up old log files.
# v0.80 2016/12/23 Chris Spencer
# - Fixed problem with traffic camera image used as door photo, as it will
#   not be downloaded by the script (permissions issue?).  Probably need to
#   find something better.
# v0.90 2017/02/03 Chris Spencer
# - Added -tempadj command-line option.
# v0.91 2017/02/07 Chris Spencer
# - Added some missed changes required for -tempadj option.
# v1.00 2017/02/10 Chris Spencer
# - Moved URLs to global variables.
# - Added -nocamera option.
# v1.01 2017/02/24 Chris Spencer
# - Bug fixes to appIoTQuerySensor.
##############################################################################
$| = 1;

##############################################################################
# libraries
##############################################################################
use File::Basename;
use Time::Local;
use Time::HiRes qw(sleep time);
use Text::Wrap;
use Cwd;
use LWP::Simple qw(!head);  # head() exists in several mods; don't need the LWP version.
use REST::Client;
use JSON;
use Data::Dumper;
use MIME::Base64;
use URI::Encode qw(uri_encode uri_decode);

##############################################################################
# globals
##############################################################################
my $VERSION = '1.01a';
my($SCRIPT, $PATH, $EXT) = fileparse($0, '.pl');
my $DEBUG = 0; # set by -d command-line option

# Change the following Author values as needed.
my $AuthorName = 'Chris Spencer B.';
my $AuthorEmail = 'christopher.b.spencer@ericsson.com';
my $AuthorDept = 'DURA LMR TDS';
my $AuthorCompany = 'Ericsson Canada Inc.';
my $AuthorLocation = 'Ottawa, ON, Canada';

my $OUTEXT = '.json'; # output file extension

my $LogFile = undef; 

my $CmdLine = undef;

##############################################################################
# date/time globals
##############################################################################
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

my $REFRESH_SECS = 5;
my $REFRESH_MS = int($REFRESH_SECS * 1000);

my $maxSecs = $HOUR; # maximum demo duration in seconds
my $startTm = time();

##############################################################################
# Truck info
##############################################################################
my $RouteDir = 'routes/';
my $JsonDir = 'json/';

my $MaxTrucks = 4;
my @Routes = (); # route coordinates for each truck
my @RouteNames = (); # current route name for each truck
my @Index = (); # route index for each truck
my @Dests = (); # current destination for each truck
my @DeliveryStatus = (); # indicate if each truck is late, ontime, or early
my @Drivers = (
    "Homer Simpson",
    "Bender",
    "Peter Griffin",
    "Bugs Bunny"
   );
my @Trucks = (
    "Maximum Homerdrive",
    "Old Bessie",
    "Freakin' Sweet",
    "The Roadrunner"
   );

my %JSON = (); # JSON data by truck number

my $warehouseCoords = undef;
my $warehouseName = "Warehouse"; # default

my $Truck0Only = 0; # If true, only truck 0 can have alarms

my @Accident = (); # truck accident flags
my @Door = (); # truck door flags
my @Temperature = ();

my $OfflineMode = 0;

my $Percent = 1; # percentage chance of an event (accident, door)
my $MinPercent = 0; # no random accidents/door-openings
my $MaxPercent = 50;
my $Chance = int(100/$Percent); # 1-in-N chance of accident or doors open in offline mode
my $AccidentDelay = 1 * $MINUTE; # offline mode only
my $DoorDelay = 30; # offline mode only

my $LoTemp = 18; # celsius
my $HiTemp = 22;
my $TempAdjust = 0; # degrees Celsius
my $NominalTemp = sprintf("%0.1f", ($HiTemp + $LoTemp)/2);

# accident states
my $NOACCIDENT = 0;
my $ACCIDENT = 1;

# door states
my $OPEN = 1;
my $CLOSED = 0;
my $DefaultClosedDoorPhoto = "images/MovingTruck.png";
my $DefaultOpenDoorPhoto = "images/OpenDoors.png";

# delivery states
my $LATE = -1;
my $ONTIME = 0;
my $EARLY = 1;
my $NOTLEFT = 2;

my $UnknownDest = "Top Secret";

##############################################################################
# AppIoT info
##############################################################################
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

my $AppIotApiUrl = 'https://eappiot-api.sensbysigma.com/api/v2/sensors/'; 

my %Config = ();
my $Client = undef;
my $AccessToken = undef;
my $AuthErrors = 0;
my $MaxAuthErrors = 3;

my %Sensor = (); # sensor info moved to json/sensor.json; loaded by readSensorConfig()
   
##############################################################################
# Web/Internet globals
##############################################################################
my $WebCam = 1; # assume webcam connected in online mode
#my $OfflinePhotoUrl = "http://traffic.ottawa.ca/map/camera?id=28";
#my $OnlinePhotoUrl = "http://ces2017.skibsville.com/images/truck0.jpg";
my $OfflinePhotoUrl = "http://www.iot-demo.se/EricssonTruck222/OpenDoors.png";
my $OnlinePhotoUrl = "http://www.iot-demo.se/EricssonTruck222/EricssonTruck222-0.jpg";

##############################################################################
# main
##############################################################################
$SIG{INT} = \&ctrlC; # Ctrl-C interrupt handler

&stderr("$SCRIPT$EXT v$VERSION");
&stderr('-' x length("$SCRIPT$EXT"));

&parseArgs;
&openLogFile;
&runSimulation;

&quit;

##############################################################################
# subroutines
##############################################################################

##############################################################################
sub quit
{
 &closeLogFile;
 &displayRunDuration;
 exit(0);
}
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

 $CmdLine = join(' ', @ARGV);
 
 while(@ARGV)
   {
    $arg = shift(@ARGV);

    if($arg eq '-h' || $arg eq '-?') # help
      {
       &help;
       exit;
      }
    elsif($arg eq '-d') # debug
      { 
       $DEBUG = 1;  # debug mode is enabled
       &debug("Debug mode enabled.");
      }
    elsif($arg eq '-chance' || $arg eq '-c' || $arg eq '-percent')
      {
       my $temp = shift(@ARGV);
       if($temp >= $MinPercent and $temp <= $MaxPercent)
         { 
          $Percent = $temp;
          if($Percent)
            { $Chance = int(100/$temp); }
          else # no chance
            { $Chance = 0; }
          &stderr("Accident rate: Percent = $Percent, Chance = $Chance");
         }
       else   
         { &warning("Percentage chance must be between 1 & $MaxPercent"); }
     }
    elsif($arg eq '-offline' || $arg eq '-off')
      { 
       $OfflineMode = 1; 
       &stderr("Offline simulation. No actual sensors will be scanned.");
      }
    elsif($arg eq '-online' || $arg eq '-on')
      { 
       $OfflineMode = 0; 
       &stderr("Online simulation. Actual sensor data will be retrieved from the cloud.");
      }
    elsif($arg eq '-nocamera' || $arg eq '-nocam' || $arg eq '-nowebcam') # no web camera
      {
       $WebCam = 0;
       &stderr("Web camera will NOT be used for Truck 0 in online mode.") unless $OfflineMode;
      }
    elsif($arg eq '-time' || $arg eq '-t') # test duration
      { 
       my $dur  = shift(@ARGV);
       if($dur >= 0 && $dur <= $DAY)
         { 
          $maxSecs = $dur; 
          &stderr("Simulation runtime changed to $maxSecs seconds.");
         }
       else 
         { &warning("Invalid simulation duration specified: $dur"); }
      }
   elsif($arg eq '-tempadj' || $arg eq '-ta') # temperature adjustment
     {
      my $ta = shift(@ARGV);
      if($ta < -273.15)
        { &warning("Temperature adjustment cannot be below Absolute Zero!"); }
      elsif($ta > 1000) 
        { &warning("You are not transporting lava!"); }
      else
        { 
	 $TempAdjust = $ta; 
	 $LoTemp += $TempAdjust;
	 $HiTemp += $TempAdjust;
         $NominalTemp = sprintf("%0.1f", ($HiTemp + $LoTemp)/2);

	 &stderr("Temperature Adjustment: $TempAdjust C");
	 &stderr("Unalarmed Temperature Range: $LoTemp - $HiTemp C");
	 &stderr("Nominal Temperature: $NominalTemp C");
	}
     }
  } # end while argv 
}

##############################################################################
sub help
{
 print STDERR <<EOH;

Syntax: $SCRIPT$EXT {options} 

Generate JSON data for the IoT CAT-M Fleet Management demo.

Options:
-time <secs>: Simulation time, in seconds. Default: $maxSecs secs. Alias: -t
-chance <n> : percentage chance of doors opening and/or accident occurring.  
   Offline mode only.  <n> must be between $MinPercent and $MaxPercent.  Default: $Percent
   Aliases: -c, -percent
-offline : Run simulation in offline mode.  All sensor data will be simulated.
   Alias: -off
-online : Run simulation by querying sensor data from the cloud in real-time.
   This is the default mode of operation.  Alias: -on
-nocamera : No web camera connected to demo. Only relevant in online mode. 
   Default: camera connected. Aliases: -nocam, -nowebcam
-tempadj <c> : Number of degrees Celsius by which to adjust value reported by 
   temperature sensor for truck 0 in online mode only.  Also, adjustment to
   low and high temperatures used to initialize temperatures for all trucks, 
   regardless of online or offline.  Can be positive or negative. 
   Default: $TempAdjust C.  Default temperature range: $LoTemp - $HiTemp C. Alias: -ta
-h : This help.
-d : Debug mode.

By $AuthorName ($AuthorEmail), $AuthorDept
   $AuthorCompany, $AuthorLocation
EOH
 &stderr("(c) 2016 - ".&getYear());
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
sub stderr
{
 my($msg) = join(" ", @_);
 print STDERR "$msg\n";
 &log($msg);
}

##############################################################################
sub log
{
 my($msg) = join(" ", @_);
 if(fileno(LOG))
   { print LOG "$msg\n"; }
}

##############################################################################
sub getDttm
{
 # For given epoch tm, return all-numeric date and time stamp.
 my($tm) = @_;
 $tm = time() unless $tm;
 my($ss, $mi, $hh, $dd, $mo, $yy) = localtime($tm);
 
 if($yy < 1900)
   { $yy += 1900; }
 return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $yy, $mo+1, $dd, $hh, $mi, $ss);
}
##############################################################################
sub getTimestamp
{
 # For given epoch tm, return all-numeric date and time stamp.
 my($tm) = @_;
 $tm = time() unless $tm;
 my($ss, $mi, $hh, $dd, $mo, $yy) = localtime($tm);
 
 if($yy < 1900)
   { $yy += 1900; }
 return sprintf("%04d%02d%02dT%02d%02d%02d", $yy, $mo+1, $dd, $hh, $mi, $ss);
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
sub openLogFile
{
 # Open a log file.  If the file already exists (unlikely), overwrite it.
 $LogFile = $PATH.'logs/'.$SCRIPT.'.'.&getTimestamp($runTm).'.log';
 &stderr("Log File is: '$LogFile'");
 if(open(LOG, ">$LogFile"))
   { 
    LOG->autoflush(1);
    print LOG '=' x 78, "\n";
    print LOG "$SCRIPT$EXT v$VERSION\n";
    print LOG "Command line: $CmdLine\n";
    print LOG "Run Date/Time: ".&getDttm($startTm)."\n";
   }
 else
   { &warning("Log file '$LogFile' could not be open.  Session is not being recorded."); }
}

##############################################################################
sub closeLogFile
{
 if(fileno(LOG))
   { close(LOG); }
}

##############################################################################
sub displayRunDuration
{
 my $duration = time() - $runTm;
 if($duration > 7200) # 2 hours
   { &stderr(sprintf("Run Duration: %0.2f hours", $duration/3600)); }
 elsif($duration > 120) # 2 mins
   { &stderr(sprintf("Run Duration: %0.1f minutes", $duration/60)); }
 else
   { &stderr(sprintf("Run Duration: %d seconds", $duration)); }
}

##############################################################################
sub runSimulation
{
 &stderr("Running simulation.  Type 'Ctrl C' at anytime to end simulation.");
 my $diff = 0;
 my $now;
  
 # read route data for each truck
 &getTruckInfo;

 # get the warehouse info. Must be called after getTruckIno().
 &readWarehouseInfo;
 &updateWarehouseJsonFile;

 # sets trucks to their starting positions.
 &initTrucks;
 
 unless($OfflineMode)
   {
    &readSensorConfig;
    &readAppIoTConfig;
    &appIoTLogin; 
   }
   
 # countdown to the start of the simulation
 &stderr("Simulation starts in:");
 
 for(my $sec = 5; $sec > 0; $sec--)
   {
    &stderr("$sec seconds...");
    sleep(1);
   }
   
 &stderr("$MaxTrucks Trucks are on the way!");
 
 if($maxSecs)
   {
    &stderr("Truck data will update every $REFRESH_SECS seconds for a maximum of $maxSecs seconds " .
      sprintf("(~%d samples/truck)...", $maxSecs/$REFRESH_SECS));
   }
 else
   { &stderr("Truck data will update every $REFRESH_SECS seconds until the script is halted by Ctrl-C."); }
   
 # start truck simulation
 $startTm = time();
 
 while($diff < $maxSecs || $maxSecs == 0)
   {
    sleep($REFRESH_SECS);

    foreach my $truck (0..$MaxTrucks-1)
      {
       # &stderr("Truck $truck index = $Index[$truck]");
       
       ($JSON{$truck}{LAT}, $JSON{$truck}{LNG}) = split(/,/, &getTruckNextPoint($truck), 2);             
       $JSON{$truck}{ACCIDENT} = &getAccident($truck);
       $JSON{$truck}{DOOR} = &getDoor($truck);
       $JSON{$truck}{TEMPERATURE} = &getTemperature($truck);
       $JSON{$truck}{STATUS} = &getDeliveryStatus($truck, $accident, $door);
       
       # check for door state change
       if($JSON{$truck}{DOOR} != $JSON{$truck}{PREVDOOR})
         {
          if($JSON{$truck}{DOOR} == $OPEN) # door opened
            { $JSON{$truck}{PHOTO} = &getPhoto($truck); }
          else # door closed
            { $JSON{$truck}{PHOTO} = $DefaultClosedDoorPhoto; }
         }       
       
       # update the JSON file for this truck
       &updateTruckJsonFile($truck);
          
       # ensure truck stops moving if an accident or open door
       unless($JSON{$truck}{ACCIDENT} || $JSON{$truck}{DOOR})
          { &incIndex($truck); }
          
       $JSON{$truck}{PREVDOOR} = $JSON{$truck}{DOOR};
      }
        
    $now = time();
    $diff = $now - $startTm;
    
    if(($diff + $MIN) > $maxSecs && $maxSecs > 0)
      { &warning("Simulation ending in ".int($maxSecs-$diff)." seconds..."); }
   } # end while diff
   
 &stderr("Simulation done.  Time expired ($maxSecs seconds).");
}

##############################################################################
sub getTruckInfo
{
 &stderr("Reading truck route info ...");
   
 foreach my $truck (0..$MaxTrucks-1)
   { &readTruckRoute($truck); }
}

##############################################################################
sub readTruckRoute
{
 # Read the route file for the given truck.  Routes files contain series of GPS
 # coordinattes which represent a smoothed path of the trucks route.  
 my($truck) = @_;
 
 return if($truck < 0 || $truck !~ /^\d+$/ || $truck > $MaxTrucks - 1);
 
 my $routeFile = $RouteDir."route".$truck.".dat"; 
 if(open(DAT, $PATH.$routeFile))
   {
    my $count = 0; # coordinates count
    while(<DAT>)
      {
       chomp;
       if(/^\s*$/ || /^\s*\#/) 
         { next; } # ignore blank and comment lines
       elsif(/^[\s\d\-\.\,]+$/) # coordinate pair
         {
          s/\s//g; # remove whitespace
          push(@{$Routes[$truck]}, sprintf("%0.5f,%0.5f", split(/\,/, $_, 2)));
          $count++;
         }
       elsif(/^(dest|destination): /i) # destination string
         { push(@{$Routes[$truck]}, $_); }
         
       elsif(/^(delivery|door)/i) # delivery = door open
         { push(@{$Routes[$truck]}, $_); }
       elsif(/^(accident|rollover)/i) # accident
         { push(@{$Routes[$truck]}, $_); }
       elsif(/^temperature:/i) # set temperature
         { push(@{$Routes[$truck]}, $_); }
         
       elsif(/^name: /i || /^route: /i) # route name string
         { $RouteNames[$truck] = (split(/:\s*/, $_, 2))[1]; }
       elsif(/^driver: /i) # driver name
         { $Drivers[$truck] = (split(/:\s*/, $_, 2))[1]; } 
       elsif(/^truck: /i) # truck name
         { $Trucks[$truck] = (split(/:\s*/, $_, 2))[1]; }          
      }
    close(DAT);
    
    # adjust simulation duration to ensure we get at least one loop of the route
    if($count * $REFRESH_SECS > $maxSecs && $maxSecs > 0)
      { $maxSecs = $count * $REFRESH_SECS; }
   }
 else 
   { 
    &warning("Could not read route file: $routeFile"); 
    if($truck)
      { push(@{$Routes[$truck]}, &getTruckStartingPoint(0)); }
    else # truck 0
      { &error("Truck 0 MUST have a valid route0.dat file."); }
   }
}

##############################################################################
sub readWarehouseInfo
{
 # Read the warehouse.txt file in the routes directory for the location of the
 # warehouse.  Otherwise, use the coordinates of the 0th position for truck 0.
 # This subroutine must be called after readTruckRoute is called for truck 0.
 &stderr("Reading warehouse info...");
 my $warehouseFile = $RouteDir."warehouse.dat";
 if(-e $warehouseFile)
   {
    if(open(WH, $warehouseFile))
      {
       while(<WH>)
         {
          chomp;
          if(/^\s*$/ || /^\s*\#/) # ignore blank and comment lines.
            { next; }
          elsif(/\,/)
            {
             my($lat,$lng,$name) = split(/\s*\,\s*/, $_, 3);
             $warehouseCoords = join(',', $lat, $lng);
             $warehouseName = $name if $name;
            }
         } # end while wh
       close(WH);
      }
   } # end if warehousefile
   
 return if(defined($warehouseCoords));
 
 # No warehouse file, or invalid warehouse file, so assume warehouse is at 
 # Truck 0's starting point.
 $warehouseCoords = &getTruckStartingPoint(0); 
}

##############################################################################
sub incIndex
{
 # increment the index for the given truck, looping as necessary.
 my($truck) = @_;
 
 $Index[$truck]++;
 if($Index[$truck] > $#{$Routes[$truck]})
   { $Index[$truck] = 0; }
}

##############################################################################
sub getTruckStartingPoint
{
 # For the given truck, get the first set of coords in its route.
 my($truck) = @_;
 
 return undef unless @{$Routes[$truck]};
 
 foreach my $val (@{$Routes[$truck]})
   {
    if($val =~ /^Dest:/i)
      { next; }
    elsif($val =~ /^\s*\-?\d+\.?\d*\,\s*\-?\d+\.?\d*\s*$/)
      { return $val; }
   }
 &warning("Truck $truck does not appear to have any valid coordinates in its route.");
 return undef;
}

##############################################################################
sub getTruckNextPoint
{
 # For the given truck, get the next set of coords in its route.  Update the truck's
 # next destination as necessary.
 my($truck) = @_;
 
 return undef unless @{$Routes[$truck]};
 
 my $max = scalar(@{$Routes[$truck]});
 my $count = 0;
 
 while(${$Routes[$truck]}[$Index[$truck]] !~ /^\-?\d+\.?\d*\,\-?\d+\.?\d*$/ && $count < $max)
   {
    if(${$Routes[$truck]}[$Index[$truck]] =~ /^(dest|destination): /i)
      { $Dests[$truck] = (split(/\:\s*/, ${$Routes[$truck]}[$Index[$truck]], 2))[1]; }
      
    elsif(${$Routes[$truck]}[$Index[$truck]] =~ /^(delivery|door)/i && $OfflineMode)
      { $Door[$truck] = $DoorDelay; }
    elsif(${$Routes[$truck]}[$Index[$truck]] =~ /^(accident|rollover)/i && $OfflineMode)
      { $Accident[$truck] = $AccidentDelay; }
    elsif(${$Routes[$truck]}[$Index[$truck]] =~ /^temperature:\s*(\d+\.?\d*\s*[cf]?)/i && $OfflineMode)
      { 
       my $temp = $1;
       if($temp =~ /f$/i) # farenheit
         {
          $temp =~ s/\s*f//i;        
          $temp = &f2c($temp); 
         }
       else # already in celsius
         { $temp =~ s/\s*c//i; }
       $Temperature[$truck] = $temp;
      }

    &incIndex($truck);
    $count++;
   } # end while not coordinates
 
 if($count >= $max)
   { 
    &warning("Truck $truck doe snot appear to have any valid coordinates in its route.");
    return $warehouseCoords;
   }
   
 return ${$Routes[$truck]}[$Index[$truck]];
}

##############################################################################
sub getTruckCurrentPoint
{
 # For the given truck, get the current set of coords in its route.  
 my($truck) = @_;
 return undef unless @{$Routes[$truck]};
 return ${$Routes[$truck]}[$Index[$truck]];
}
 
##############################################################################
sub atWarehouse
{
 # Return true if truck is currently at the warehouse.  False otherwise.
 my($truck) = @_;
 # &stderr("Truck $truck: " . &getTruckCurrentPoint($truck) . ' =?= ' . $warehouseCoords);
 if(&getTruckCurrentPoint($truck) eq $warehouseCoords)
   { return 1; }
 return 0;
}

##############################################################################
sub getTruckStartingDest
{
 # For the given truck, get the first destination on its route.
 my($truck) = @_;
 return unless @{$Routes[$truck]};
 foreach my $val (@{$Routes[$truck]})
   {
    if($val =~ /^Dest:/i)
      { return (split(/:/, $val, 2))[1]; }
    else
      { next; }
   }
 &warning("Truck $truck does not appear to have any named destinations in its route.");
 return $UnknownDest;
}

##############################################################################
sub initTrucks
{
 &stderr("Resetting all trucks...");
 
 foreach my $truck (0..$MaxTrucks-1)
   { 
    ($JSON{$truck}{LAT}, $JSON{$truck}{LNG}) = split(/\,/, &getTruckStartingPoint($truck), 2);
    
    if(!defined($JSON{$truck}{LAT}) && !defined($JSON{$truck}{LNG}) && $truck)
      { 
      ($JSON{$truck}{LAT}, $JSON{$truck}{LNG}) = split(/\,/, &getTruckStartingPoint($truck), 2);
       push(@{$Routes[$truck]}, "$JSON{$truck}{LAT},$JSON{$truck}{LNG}");
      }    

    $JSON{$truck}{ROUTE}  = $RouteNames[$truck];
    $JSON{$truck}{DRIVER} = $Drivers[$truck];
    $JSON{$truck}{NAME} = $Trucks[$truck];
    $JSON{$truck}{DESTINATION} = &getTruckStartingDest($truck);
    
    $JSON{$truck}{ACCIDENT} = 0;
    $JSON{$truck}{DOOR} = 0;
    $JSON{$truck}{TEMPERATURE} = $NominalTemp;
    $JSON{$truck}{STATUS} = $NOTLEFT;
    $JSON{$truck}{PHOTO} = $DefaultClosedDoorPhoto;
    
    $Temperature[$truck] = $NominalTemp;
    $Door[$truck] = $CLOSED;
    $Accident[$truck] = $NOACCIDENT;
    
    &updateTruckJsonFile($truck);     
   }
}

##############################################################################
sub readSensorConfig
{
 # The sensor config from the sensor.json file in the JsonDir.
 &stderr("Reading sensor config file...");
 my $sensorFile = $JsonDir."sensor.json";
 if(open(CONF, $sensorFile))
   {
    while(<CONF>)
      {
       chomp;
       if(/^\s*\"([^\"]*)\"\s*:\s*\"([^\"]*)\"/)
         { 
          $Sensor{$1} = $2; 
          &debug("$1 sensor ID = $Sensor{$1}");
         }
      } # end while conf
    close(CONF);
   }
 else
   { &warning("Cannot read sensor config file: $sensorFile"); }
}

##############################################################################
sub readAppIoTConfig 
{
 &stderr("Reading AppIoT config file...");
 my $jsonFile = $JsonDir.'adal.config.json';
 if(open(CONF, $jsonFile))
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
    
    # ensure we have a grant_type
    $Config{grant_type} = 'password' unless $Config{grant_type};
    
    # The clientSecret may use reserved characters, so encode it
    $Config{clientSecret} = uri_encode($Config{clientSecret}, { encode_reserved => 1 });
    &debug("encoded ClientSecret: ".$Config{clientSecret});
   } # end if open config file
 else
   { &warning("Cannot read AppIoT config file: $jsonFile"); }
}

##############################################################################
sub appIoTLogin
{
 &stderr("Logging in to AppIoT $Config{authorityHostUrl}"); 
 
 unless(%Config)
   { &error("No AppIoT config data found."); }

 my $headers = \%Config;
 my $body = 'grant_type=password' .
   '&username='.$Config{username} .
   '&password='.$Config{password} .
   '&resource='.$Config{webApiResourceId} .
   '&client_id='.$Config{clientId} .
   '&client_secret='.$Config{clientSecret};
   
 $Client = REST::Client->new(timeout=>25);
 $Client->POST($Config{authorityHostUrl} .'/'. $Config{tenantId}.'/oauth2/token', $body, $headers);

 if($Client->responseCode() == 200)
   {
    my $response = from_json($Client->responseContent());
    &debug("response = ".Dumper($response));
    $AccessToken = $response->{access_token};
    &debug("Success! AppIoT Access Token: $AccessToken");
    $AuthErrors = 0;
   }
 else # problem
   { &error("AppIoT login failed: ".$Client->responseCode().': '.$Client->responseContent()); }
}

##############################################################################
sub appIoTQuerySensor
{
 my($sensorname) = @_;
 my $rc = 0;
 my $body = undef;
 
 if($Sensor{$sensorname})
   {
    my $headers = {
         'Authorization' => 'Bearer ' . uri_encode($AccessToken, { encode_reserved => 1 }),
         'X-DeviceNetwork' => $Config{deviceNetworkId},
         'Content-type'=> 'application/json'
        };
    my $url = $AppIotApiUrl . $Sensor{$sensorname} . '/latestmeasurement';

    # &debug("AppIoT URL: $url");
    # &debug("command: $command");
    # &debug("headers = ".Dumper($headers));
    
    $Client->GET($url, $headers);
    if($Client->responseCode() == 200)
      {
        my $response = from_json($Client->responseContent());
        my $type = ref($response);
        if($type eq 'HASH') 
          { 
           &debug("$sensorname response = ".Dumper($response));
           &debug("$sensorname = " . ${$response}{Values}[0] );
           $rc = ${$response}{Values}[0];
          }
        else # what the?
          { &warning("Unknown response type for sensor $sensorname: refType=$type"); }
      }
    elsif($Client->responseCode() == 401 && $Client->responseContent() =~ /Authorization has been denied for this request/)
      {
       # AppIoT authorization expired, so we need to reconnect
       $AuthErrors++;
       if($AuthErrors > $MaxAuthErrors)
         {
          &warning("AppIoT authorization unsuccessful after $MaxAuthErrors attempts.  Exiting....")         ;
          &quit; 
         }
       &appIoTLogin;
      }
    elsif($Client->responseCode() == 408 || # request time-out
          $Client->responseCode() == 500 )  # Internal Server Error
      {
       # not sure what to do here yet
      }
    else # problem
      { &warning("Query sensor $sensorname failed: ".$Client->responseCode().': '.$Client->responseContent()); }
   }
 else
   { &warning("Sensor $sensorname not defined."); }
   
 return $rc;
}

##############################################################################
sub getAccident
{
 my($truck) = @_;
 
 return 0 if($truck && $Truck0Only); # only truck 0 is allowed to have an accident (Marketing)
 
 # only truck 0 has sensors
 if($OfflineMode || $truck)
   {
     # in offline mode, accidents have a set duration
     if($Accident[$truck] > 0)
       { $Accident[$truck] -= $REFRESH_SECS; }
     elsif(!&atWarehouse($truck) && $Door[$truck] <= 0) # not at warehouse and door not open
       { 
        if($Chance)
          {
           unless(int(rand($Chance)))
             { $Accident[$truck] = $AccidentDelay; }  
          }
       }
       
     if($Accident[$truck] < 0)
      { $Accident[$truck] = 0; }

     if($Accident[$truck])
       { return $ACCIDENT; } # accident/rollover
     return $NOACCIDENT; # no accident/rollover
   }
 else # online - only truck 0 has sensors
   { return &appIoTQuerySensor("Accident"); }
}

##############################################################################
sub getDoor
{
 my($truck) = @_;
 
 return 0 if($truck && $Truck0Only && $Door[$truck] <= 0); # only truck 0 is allowed to have an open door

 # only truck 0 has sensors
 if($OfflineMode || $truck)
   {
     # in offline mode, open doors delay the truck for a set period.
     if($Door[$truck] > 0)
       { $Door[$truck] -= $REFRESH_SECS; }
     elsif(!&atWarehouse($truck)) # door not open, so there's a chance that it will randomly open if not at warehouse
       { 
        if($Chance)
          {
           unless(int(rand($Chance)))
             { $Door[$truck] = $DoorDelay; }  
          }
       }
       
     if($Door[$truck] < 0)
      { $Door[$truck] = 0; }

     if($Door[$truck])
       { return $OPEN; } # Door open       
    return $CLOSED; # door closed
   }
  else # online - only truck 0 has sensors
   { return &appIoTQuerySensor("Door"); }
}

##############################################################################
sub getTemperature
{
 my($truck) = @_;
 my $factor;
 
 return $Temperature[$truck] if($truck && $Truck0Only); # only truck 0 can have temperature issues
 
 # only truck 0 has sensors
 if($OfflineMode || $truck)
   {
    if($Chance)
      {
       $factor = int(rand(10)); # random value from 0..9
       
       if($Door[$truck] > 0)    
         { $Temperature[$truck] += 0.1 if $Temperature[$truck] <= ($HiTemp + 3); }
       
       elsif($Temperature[$truck] > ($HiTemp + 2))
         { $Temperature[$truck]--; }
       elsif($Temperature[$truck] > $HiTemp)
         { $Temperature[$truck] -= sprintf("%0.1f", rand(1)) if($factor <= 5); }
       elsif($Temperature[$truck] < ($LoTemp - 2))
         { $Temperature[$truck]++; }
       elsif($Temperature[$truck] < $LoTemp)
         { $Temperature[$truck] += sprintf("%0.1f", rand(1)) if($factor <= 5); }
         
       else
         {
           if($factor == 1)
             { $Temperature[$truck] -= sprintf("%0.1f", rand(1)); }
           elsif($factor == 9)
             { $Temperature[$truck] += sprintf("%0.1f", rand(1)); }
         } 
       }
     return sprintf("%0.1f", $Temperature[$truck]); 
   }
 else # online - only truck 0 has sensors
   { return (&appIoTQuerySensor("Temperature") + $TempAdjust); }
}

##############################################################################
sub getDeliveryStatus
{
 my($truck, $accident, $door) = @_;
 my $status = $ONTIME;
 
 if(&atWarehouse($truck))
   { $status = $NOTLEFT; }
 else 
   { 
    # Determine truck's delivery status
    if($accident)
     { $DeliveryStatus[$truck] -= $REFRESH_SECS; }      
    elsif($door)
     { $DeliveryStatus[$truck] -= $REFRESH_SECS; }      
    else # truck might be able to make-up time
     {
      if($DeliveryStatus[$truck] < 0)
        { $DeliveryStatus[$truck] += int(rand($REFRESH_SECS)); }
      else
        { 
         unless(int(rand(10))) 
           { $DeliveryStatus[$truck] += int(rand($REFRESH_SECS)); }
        }
     }

    if($DeliveryStatus[$truck] < 0)
     { $status = $LATE; } # late
    elsif($DeliveryStatus[$truck] > 0)
     { $status = $EARLY; }
    else
     { $status = $ONTIME; }
  }
  
 return $status;
}

##############################################################################
sub getPhoto
{
 my($truck) = @_;
 my($rc, $photo);
 
 # only truck 0 gets photos taken
 if($truck || $Offline || !$WebCam)
   {
    # $photo = "photos/truck".$truck.".jpg";
    # &stderr("Truck $truck photo: $photo");
    # $rc = getstore("http://traffic.ottawa.ca/map/camera?id=28", $photo);
    # if(is_error($rc))
      # {
       # &warning("Truck $truck photo failed: rc=$rc")      ;      
       # $photo = $DefaultOpenDoorPhoto; 
      # }
    $photo = $OfflinePhotoUrl;
   }
 else # truck 0 online w/webcam
   {
    $photo = "photos/truck".$truck."-".&getTimestamp().".jpg";
    &stderr("Truck $truck photo: $OnlinePhotoUrl --> $photo");
    $rc = getstore($OnlinePhotoUrl, $photo);
    if(is_error($rc))
      {
       &warning("Truck $truck photo failed: rc=$rc");
       $photo = $DefaultOpenDoorPhoto; 
      }
   }
   
 return $photo;
}

##############################################################################
sub updateWarehouseJsonFile
{
 return unless $warehouseCoords;
 
 my $jsonFile = $JsonDir."warehouse".$OUTEXT;
 my($lat,$lng) = split(/,/, $warehouseCoords, 2);

 if(open(DAT, ">$jsonFile"))
   {
    print DAT "{ ",
       "\"name\": \"$warehouseName\", ",
       "\"lat\": $lat, ",
       "\"lng\": $lng ",
       "}";
    close(DAT);
   }
  else
   { &warning("Could not open data file for writing: $jsonFile"); }
  &log("Warehouse Name: $warehouseName; Lat: $lat; Long: $lng")
}

##############################################################################
sub updateTruckJsonFile
{
 my($truck) = @_;
 
 return unless(defined($truck) && ($truck >= 0 && $truck <= $MaxTrucks-1));
 my $jsonFile = $JsonDir."truck".$truck.$OUTEXT;

 if($truck > 0)
   { &log("Truck $truckno: $JSON{$truck}{LAT},$JSON{$truck}{LNG}; Accident=$JSON{$truck}{ACCIDENT}; Door=$JSON{$truck}{DOOR}; TempC=$JSON{$truck}{TEMPERATURE}"); }
 else   
   { &stderr("Truck $truckno: $JSON{$truck}{LAT},$JSON{$truck}{LNG}; Accident=$JSON{$truck}{ACCIDENT}; Door=$JSON{$truck}{DOOR}; TempC=$JSON{$truck}{TEMPERATURE}"); }
 
 if(open(DAT, ">$jsonFile"))
   {
    print DAT "{ ",
       "\"truck\": \"$truck\", ",
       "\"lat\": $JSON{$truck}{LAT}, ",
       "\"lng\": $JSON{$truck}{LNG}, ",
       "\"route\": \"$JSON{$truck}{ROUTE}\", ",
       "\"name\": \"$JSON{$truck}{NAME}\", ",
       "\"driver\": \"$JSON{$truck}{DRIVER}\", ",
       "\"destination\": \"$JSON{$truck}{DESTINATION}\", ",
       "\"accident\": $JSON{$truck}{ACCIDENT}, ",
       "\"door\": $JSON{$truck}{DOOR}, ",
       "\"temp\": $JSON{$truck}{TEMPERATURE}, ",
       "\"status\": $JSON{$truck}{STATUS}, ",
       "\"photo\": \"$JSON{$truck}{PHOTO}\"",
       "}";
    close(DAT);
   }
 else
   { &warning("Could not open data file for writing: $jsonFile"); }
}

