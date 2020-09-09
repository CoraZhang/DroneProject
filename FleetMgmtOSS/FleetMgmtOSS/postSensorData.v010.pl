#!/usr/bin/perl

# #!/opt/tools/tools/perl/5.12.2/bin/perl

##############################################################################
# postSensorData.pl
# By Chris Spencer (christopher.b.spencer@ericsson.com), 
#    DURA LMR TDS
#    Ottawa, Ontario, CANADA
# (c) Ericsson Canada Inc.
#
# Synopsis:
# --------
# Post manually-provided sensor data for the fleetsim.pl demo.
# Sensor data for temperature, tilt (accident), and doors for Truck 0.
#
# Version History:
# ---------------
# v0.10 2016/11/02 Chris Spencer
# - Original version.  Based on post_sensor_data.py by David Thomas J, Ericsson
#   Canada Inc.
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
my $VERSION = '0.10a';
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
# AppIoT info
##############################################################################
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

my $HttpSAS = 'SharedAccessSignature sr=https%3a%2f%2feappiotsens.servicebus.windows.net%2fdatacollectoroutbox%2fpublishers%2ffffb8fc8-6eae-4368-86c2-6eb75c3ff015%2fmessages&sig=jCs12Zn4hYYHZmaPN8wjVLmawTJJnombeD4MKMgQ2X8%3d&se=4632434417&skn=SendAccessPolicy';
my $GatewayId = 'fffb8fc8-6eae-4368-86c2-6eb75c3ff015';
my $Url = 'https://eappiotsens.servicebus.windows.net/datacollectoroutbox/publishers/'.$GatewayId.'/messages';

my %Config = ();
my $Client = undef;

my %Sensor = (
    # "Temperature" => "ed6abeaf-37b8-4af6-af0e-d9d377cfcf82",
    # "Door" => "8d77241f-07cc-4990-b7f5-e07ff3b773f2",
    # "Tilt" => "5a0cc0cf-5bcc-4106-95c8-be52855eb145",
    "Temperature" => "d51d3b56-28e6-48a6-8992-95609d137760",
    "Door" => "6e01f16b-f7f7-4fd0-b0e7-3f6c796807ab",
    "Tilt" => "e3183f59-4eaa-4523-b0c1-f3b53d3d60a5"
   );

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
&stderr('-' x length("$SCRIPT$EXT"));

&parseArgs;

$Client = REST::Client->new(timeout=>25);

foreach my $sensor (sort(keys(%Sensor)))
  {
   &stderr("Posting $sensor = $Data{$sensor}");

   my $ms = int($runTm * 1000);
   my $data = '[{"id":"' . $Sensor{$sensor} . '","v":[{"m":[' . $Data{$sensor} . '],"t":' . $ms . '}]}]';
   &stderr("$sensor data = $data");
   my $header = { 
       'Authorization' => $HttpSAS,
       'DataCollectorId' => $GatewayId,
       'PayloadType' => 'Measurements',
       'Timestamp' => $ms,
       'Cache-Control' => 'no-cache',
       'Content-Length' => length($data) 
      };

   $Client->POST($Url, $data, $header);
   if($Client->responseCode() == 201)
     { &stderr("- $sensor post successful: $Data{$sensor}"); }
   else # problem
     { &error("- $sensor post failed: ".$Client->responseCode().': '.$Client->responseContent()); }
  } # end foreach sensor

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
    $arg = shift(@ARGV);
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
      }
    elsif(defined($Data{Door}))
      { $Data{Tilt} = "$arg"; }
    elsif(defined($Data{Temperature}))
      { $Data{Door} = "$arg"; }
    else # temperature
      { $Data{Temperature} = "$arg"; }
  } # end while argv 

  unless(defined($Data{Temperature}) && defined($Data{Door}) && defined($Data{Tilt}))
    { &error("Provide temperature ($Data{Temperature}), door (bool - $Data{Door}), and tilt (bool - $Data{Tilt}) on command line."); }
}

##############################################################################
sub help
{
 print STDERR <<EOH;

Syntax: $SCRIPT$EXT <TempF> <Door_bool> <Tilt_bool>

Generate JSON data for the IoT CAT-M Fleet Management demo.

Options:
-h : This help.
-d : Debug mode.

By $AuthorName ($AuthorEmail), $AuthorDept
   $AuthorCompany, $AuthorLocation
EOH
 &stderr("(c) ".&getYear());
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
sub readAppIoTConfig 
{
 my $jsonFile = 'json/adal.config.json';
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


