#!/bin/perl
#!c:\bin\perl\bin\perl
# ======================================================================
# cache_clean.pl
# Script to monitor and control space usage by a P4Proxy cache
#
# usage: cache_clean.pl -c cache_dir -l limit_size -o output_file [-m max_empty] [-i]
#   see usage section in script below
#
#
# [jt] Downloaded from here: https://swarm.workshop.perforce.com/view/guest/stanton_stevens/cache_clean.pl
#
# $Id: //esi/perforce/scripts/tools/cleanup/cache_clean.pl#2 $
# $Author: sstevens $
# $Date: 2007/05/23 $
# ======================================================================

# Get system modules.
use strict;
use Getopt::Long;
use Time::Local;

my $LimitSize = 0;
my $CacheDir = "";
my $OutputFile = "";
my $MaxEmpty = 0;
my $DoNothing = 0;
my $Help = 0;

my $Total = 0; 
my $Used = 0;
my $Avail = 0;
my $CurSize = 0;

# If access date is before most recent file deleted last run, it is due to a Perforce bug. Some files written
#  to the cache do not have the correct access time set, it can be anywhere in the Unix epoch.
#  But if the access date is earlier than the last file cleaned out last time cache_clean.pl was run, 
#  it's bogus, reset it to the current date. Each time the script is run, the last date is saved to file. 
#  The date below is used if no date is saved so far.
#  This may be a Solaris only bug
#
my $start_date = "1/1/2005";
# edit this path as appropriate, it is where to store the files saving dates
my $date_file_folder = "/data/scripts";

#
# main routine starts here
#
GetOptions ("help|?" => \$Help,
	    "c=s" => \$CacheDir,
	    "l=i" => \$LimitSize,
	    "o:s" => \$OutputFile,
	    "m:i" => \$MaxEmpty,
	    "i"   => \$DoNothing,
           );

if($Help || ($CacheDir eq "") || ($LimitSize == 0))
{

   print "# usage: cache_clean.pl -c cache_dir -l limit_size [-m max_empty] [-n min_empty]
   -c cache_dir - where cache files are stored, such as /perforce/1710/cache
       it can also use a wildcard, like /perforce/*/cache, and will draw from all folders that match
       But - all these folders must be on the same partition. And you may have to use \* rather than *,
       in Unix shells.
   -l limit_size - maximum size in MB of the area monitored, delete files by access time to get here
   -m max_empty  If this number of MB is already free in the partition, skip most of the script
       This is a speed optimization.
       For example: if set to 50000, and 50 GB are free, no need to trim cache, don't bother with du command
   -i do nothing, just list what would be deleted 
   -o output_file   - print output to this file, rather than stdout

   NOTE: cygwin is required for Windows machines, this script may need to be modified to use the correct path to cygwin commands.\n";
   exit(1);
}   

# take care of output
if($OutputFile)
{
    if (!open(OUT, ">>$OutputFile"))
    {
        print "Unable to open $OutputFile for appending, using STDOUT\n";
    }
    else
    {
        select(OUT);
    }
}

# look for a saved date for the oldest files deleted, use to fix Perforce access date errors
my $cachepath = $CacheDir;
$cachepath =~ s/\//\./g;
$cachepath =~ s/\*/\./g;
my $DateFile = "$date_file_folder/$cachepath.cache_clean_date.keep";
if (-e $DateFile)
{
    if (open(DATEFILE, "<$DateFile"))
    {
	while (<DATEFILE>)
	{
	    if(/Cutoff Date: (\S+)/)
	    {
		$start_date = $1;	
	    }
	}
	close (DATEFILE);
    }
    else
    {
        print "cache_clean.pl: Unable to open $DateFile to get cutoff date, though it exists. Aborting.\n";
	exit  (1);
    }
}
else
{
    print "Using default cutoff date of $start_date, no saved cutoff date.\n";
}

# set to the most recent date deleted, to be picked up next time the script is run
my $last_date = ""; 

my ($m, $d, $y) = split (/\//, $start_date);
my $cutoff_time = timelocal(0, 0, 0, $d, $m-1, $y);
my $current_time = time;
    
if($MaxEmpty)
{
    print "Will do nothing if more than $MaxEmpty MB is free\n";
}
if($DoNothing)
{
    print "Reporting on what would be cleaned from cache folder(s) $CacheDir\n";
    `date`;
    print "Space usage would be reduced to $LimitSize MB.\n";
}
else
{
    print  "Cleaning cache folder(s) $CacheDir\n";
    `date`;
    print "Space usage will be reduced to $LimitSize MB.\n";
}

# convert megabytes to kilobytes.
$MaxEmpty = $MaxEmpty * 1000;
$LimitSize = $LimitSize * 1000;

my @Results = "";
my $Command = "";

# Deal with platform specific stuff. I'm sure there's a better way, but this works for many cases
# Cygwin must be installed: http://www.cygwin.com/
my $ucmd_path = "";
my $uname_results = `uname -a`;
if($uname_results =~ /CYGWIN/)
{
   $ucmd_path = "c:\\cygwin\\bin\\";
}

# do a df, if more space available than MaxEmpty, we're done, exit
$Command = "df -k $CacheDir";
@Results = `$Command`;
chomp(@Results);
if ($#Results == -1)
{
    print  "Unable to run df to check partition size, check cache dir path\n";
    die;
}

shift @Results;  # first line is just a header
foreach my $Line (@Results)
{
    $Line =~ /\S+\s+(\w+)\s+(\w+)\s+(\w+).*/;
    $Total = $1; $Used = $2; $Avail = $3;
    last;
}

if($MaxEmpty && ($Avail > $MaxEmpty))
{
    # plenty of room, get out
    my $AvailMB = $Avail / 1000;
    my $MaxMB = $MaxEmpty / 1000;
    print  "Done: $AvailMB MB available, more than $MaxMB MB, plenty of room, skipping rest of check\n";
    exit(0);
}

# may be a limited space situation, use du to get current cache size
$Command = "du -Lks $CacheDir";
my @Results = `$Command`;
if ($#Results == -1)
{
    print "Unable to run du to check cache size, check cache dir path\n";
    die;
}

foreach my $Line (@Results)
{
    print  $Line;
    $Line =~ /(\w+).*/;
    $CurSize = $CurSize + $1;
}
print  "Total cache size is currently $CurSize KB\n";

my $DelSize = 0;

# determine if cache size must be reduced
if($LimitSize < $CurSize)
{
    # yes, must reduce space. 
    $DelSize = $CurSize - $LimitSize;
}

# do we have DelSize indicating that we should do something?
if($DelSize == 0)
{
    print  "Done: No need to trim cache for its size or to ensure minimum free space\n";
    exit(0);
}

# if we're here, both Limit and DelSize refer to how to delete from the cache
# gather a list of all files, in a hash by access time
$Command = $ucmd_path . "find $CacheDir -type f -follow";
@Results = `$Command`;
if ($#Results == -1)
{
    print  "Unable to run find to check each file, check cache dir path\n";
    die;
}
chomp(@Results);

my %Fdata;
foreach my $Line (@Results)
{
   $Fdata{$Line} = (stat($Line))[8];
   if(!$DoNothing && ($Fdata{$Line} < $cutoff_time))
   {
       # reset the access time to now, it was bogus
       my ($s, $mi, $h, $d, $m, $y) = localtime($Fdata{$Line});
       printf  ("Fixing bad date: %02d/%02d/%d %02d:%02d,  $Line\n", $m + 1, $d, $y + 1900, $h, $mi);
       `touch \"$Line\"`;
       $Fdata{$Line} = $current_time;
   }
}

# for the following, work with bytes
$DelSize = $DelSize * 1000;
my $i = 0;	
my $FileSize;

foreach my $File (sort {$Fdata{$a} <=> $Fdata{$b} } keys %Fdata)
{
   my ($s, $mi, $h, $d, $m, $y) = localtime($Fdata{$File});
   $FileSize = (stat($File))[7];
   printf  ("%02d/%02d/%d %02d:%02d, %d K - $File\n", $m + 1, $d, $y + 1900, $h, $mi, int($FileSize)/1000);

   if(!$DoNothing)
   {
       my $Results = unlink($File);
       if($Results != 1)
       {
           print  "unable to rm file $File\n";
       }
   }
   $DelSize = $DelSize - $FileSize;
   $i++;
   if($DelSize <= 0)
   {
      # enough has been deleted
      $last_date = sprintf("%s/%s/%s", $m + 1, $d, $y + 1900);
      last;
   }
}

if($DelSize > 0)
{
    print  "Error, unable to free up space\n";
    exit (1);
}
my $LimitMB = $LimitSize / 1000;
if($DoNothing)
{
    print  "Files accessed before $last_date would be deleted.\n";
    print  "\nWould reduce cache size to $LimitMB MB, $i files would be deleted.\n\n\n\n";
}
else
{
    if (open(DATEFILE, ">$DateFile"))
    {
	print DATEFILE "Cutoff Date: $last_date"; 
	close (DATEFILE);
    }
    else
    {
        print "cache_clean.pl: Unable to open $DateFile to set cutoff date.\n";
    }
    print  "Files accessed before $last_date were deleted.\n";
    print  "Reduced cache size to $LimitMB MB, $i files deleted, done.\n\n";
}
exit (0);
