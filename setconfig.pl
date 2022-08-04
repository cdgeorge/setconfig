#!/usr/bin/perl -w
# Copyright christian@thegeorge.dk
use strict;
use File::Basename;
use Time::HiRes qw( gettimeofday );

sub Dprint {
    if( 1 ) {
        my ($sec, $usec) = gettimeofday;
        printf STDERR ("%d.%06d:%s\n",$sec,$usec,@_);
    }
}
sub ExitError {
    Dprint "ExitError:@_\n";
    print STDERR "setconfig.pl error:@_\n";
    exit 20;
}

sub MkDirP {
    my ($dir)=@_;
    Dprint "mkdir -p '$dir'\n";
    use File::Path;
    eval { mkpath($dir) };
    if ($@) {
        ExitError "Couldn't create $dir: $@";
    }
}

sub LazyWriteFile {
    my ($file,$data)=@_;
    if( -e $file) {
        open(IFILE, "<", $file) or ExitError("Can't read file:'$file' $!");
        my $orgdata = do { local $/; <IFILE> };;
        close IFILE;
        if( $orgdata eq $data ) {
            Dprint("File ${file} is the same");
            return 0;
        }
        Dprint("File ${file} is changed");
    } else {
        Dprint("File ${file} not found -> writing");
    }
    open(OFILE, ">", "$file.new") or die("Can't write '$file.new' $!");
    print OFILE $data;
    close OFILE;
    rename("$file.new", $file);
    return 1;
}


my $cfgFile;
my $setConfigFile;
my $tagChangeText='# Changed by setconfig.pl';
my $MKDIR=0;
my $indent="";
my $useSections=0;
my $commentSign="#";

sub Usage {
    my ($error)=@_;
    print  "$error\n";
    print  "setconfig.pl [-options] <inputfiles>+\n";
    print  "   --format|cfg-format <config-file-format>  The config file file-format\n";
    print  "   --tag-change <text>                Text to tag all changes with\n";
    print  "   --cfg-file <config-file>           The Config file to change\n";
    print  "   --set-from <file>                  File contanint all the changes that should be applied\n";
    print  "   --help\n";
    exit 1;
}

sub UsageFormats {
    my ($error)=@_;
    print  "$error\n";
    print  "support formats:\n";
    print  "   smb - used for /etc/samba/smb.conf\n";
    exit 1;
}

sub SetFormat {
    my ($format)=@_;
    if($format eq 'smb') {
        $indent="   ";
        $useSections=1;
        $commentSign="#"
    } else {
        UsageFormats "Unsupport format:$format";
    }
}

sub UsageCommands {
    my ($error)=@_;
    print  "$error\n";
    print  "set ([^=]*)=(.*)\n";
    print  "section (.*)\n";
    print  "(global )?location (last|end)\n";
    print  "(global )?location (start|begining)\n";
    print  "(global )?location find (.*)\n";
    print  "precomment <comment> - Add a comment before the 'set line'\n";
    exit 1;
}

while (@ARGV) {
    my $arg = shift(@ARGV);
    if ( $arg eq "--format" || $arg eq "--cfg-format" ) {
        my $format=shift(@ARGV) or die "missing arg";
        SetFormat($format);
    } elsif ( $arg eq "--tag-change" ) {
		$tagChangeText=shift(@ARGV) or die "missing arg";
    } elsif ( $arg eq "--file" || $arg eq "--cfg-file" ) {
		$cfgFile=shift(@ARGV) or die "missing arg";
	} elsif ( $arg eq "--set-from" ) {
		$setConfigFile=shift(@ARGV) or die "missing arg";
    } elsif ( $arg =~ /^--help$/ ) {
        Usage("");
    } elsif ( $arg =~ /^-/ ) {
        Usage("Unsupported args:$arg");
    } else {
        Usage("Unsupported args:$arg");
	}
}
if(!$cfgFile) {
    Usage("Missing config file");
}
if(!$setConfigFile) {
    Usage("Missing set from file");
}

my $handle;
unless (open $handle, "<:encoding(utf8)", $cfgFile) {
   ExitError ("Could not open file '$cfgFile': $!");
}
chomp(my @lines = <$handle>);
unless (close $handle) {
   # what does it mean if close yields an error and you are just reading?
   print STDERR "Don't care error while closing '$cfgFile': $!\n";
}

unless (open $handle, "<:encoding(utf8)", $setConfigFile) {
   ExitError ("Could not open file '$setConfigFile': $!");
}
chomp(my @sflines = <$handle>);
unless (close $handle) {
   # what does it mean if close yields an error and you are just reading?
   print STDERR "Don't care error while closing '$setConfigFile': $!\n";
} 
my $section='';
my $location;
my @pre_comment=();
my @pre_section_comment=();

sub findSection {
    my ($global)=@_;
    if(!defined $global){$global="";}
    Dprint "findSection section:'$section' global:$global";
    if($global) { # if 'location' is mark as global, delete the currrent section
        $section='';
    }
    if($section eq '') {
        return ($0,$#lines+1,1);
    }
    my $start=0;
    my $inSection=0;
    my $i=0;
    for(;$i<=$#lines;$i++) {
        #Dprint "findSection in$inSection \[$section\] $i:$lines[$i]";
        if(!$inSection && $lines[$i]=~/^\[$section\]/){
            $start=$i+1;
            $inSection=1;
        } elsif($inSection && $lines[$i]=~/^\[.*\]/){
            return ($start,$i,1);
        }
    }
    if($inSection) {
        return ($start,$i,1);
    } else {
        return ($i,$i,0);
    }
}

sub tagChange {
    my ($lineIdxBegin,$lineIdxEnd)=@_;
    #return;
    if($tagChangeText eq '') {
        return;
    }
    Dprint "tagChange $lineIdxBegin-$lineIdxEnd (section:$section location:$location)";
    my $tagEnd="$tagChangeText - end";
    my $tagStart="$tagChangeText - start";
    if($lineIdxBegin >=0 && $lines[$lineIdxBegin-1] eq $tagEnd) {
        splice @lines, $lineIdxBegin-1, 1;
        $lineIdxEnd--;
        splice @lines, $lineIdxEnd, 0, $tagEnd;
        if($location>=$lineIdxBegin && $location<$lineIdxEnd) {
            $location--;
        }
        Dprint "tagChange at end $lineIdxBegin-$lineIdxEnd (section:$section location:$location)";
        return;
    }
    my $endFound=0;
    for(my $i=$lineIdxEnd;$i<=$#lines;$i++) {
        if($lines[$i] eq $tagEnd) {
            $endFound=1;
            last;
        }
        if($lines[$i] eq $tagStart) {
            last;
        }
    }
    my $startFound=0;
    for(my $i=$lineIdxBegin;$i>=0;$i--) {
        if($lines[$i] eq $tagStart) {
            $startFound=1;
            last;
        }
        if($lines[$i] eq $tagEnd) {
            last;
        }
    }
    if(!$startFound) {
        Dprint "tagChange add start $lineIdxBegin-$lineIdxEnd (section:$section location:$location)";
        splice @lines, $lineIdxBegin, 0, $tagStart;
        if($location>=$lineIdxBegin) {
            $location++;
        }
        $lineIdxEnd++;
        $lineIdxBegin++;
        foreach my $c (@pre_comment) {
            splice @lines, $lineIdxBegin, 0, "$commentSign$c";
            if($location>=$lineIdxBegin) {
                $location++;
            }
            $lineIdxEnd++;
            $lineIdxBegin++;
        }
        @pre_comment=();
    }
    if(!$endFound) {
        Dprint "tagChange add end $lineIdxBegin-$lineIdxEnd (section:$section location:$location)";
        splice @lines, $lineIdxEnd, 0, $tagEnd;
        if($location>=$lineIdxEnd) {
            $location++;
        }
    }
}
    
sub set {
    my ($var,$value)=@_;
    my ($b,$e,$sectionExists)=findSection();
    Dprint "set $var=$value (section:$section $b-$e exists:$sectionExists location:$location)";
    for(my $i=$b;$i<$e;$i++) {
        if($lines[$i]=~/^(\s*)\Q$var\E(\s*=)\s*/){
            $lines[$i]="$1$var$2$value";
            tagChange($i,$i+1);
            return;
        }
    }
    my $tb=$location;
    if(!$sectionExists) {
        foreach my $c (@pre_section_comment) {
            splice @lines, $location, 0, "$commentSign$c";
            $location++;
        }
        @pre_section_comment=();
        splice @lines, $location, 0, "[$section]";
        $location++;
    }
    foreach my $c (@pre_comment) {
        splice @lines, $location, 0, "$commentSign$c";
        $location++;
    }
    @pre_comment=();
    splice @lines, $location, 0, "$indent$var=$value";
    $location++;
    tagChange($tb,$location);
}
sub location_end {
    my ($global)=@_;
    my ($b,$e,$sectionExists)=findSection($global);
    Dprint "location_end (section:$section $b-$e exists:$sectionExists)";
    $location=$e;
}
sub location_start {
    my ($global)=@_;
    my ($b,$e,$sectionExists)=findSection($global);
    Dprint "location_start (section:$section $b-$e exists:$sectionExists)";
    $location=$b;
}
sub location_find {
    my ($global,$find)=@_;
    my ($b,$e,$sectionExists)=findSection($global);
    Dprint "location_find $find (section:$section $b-$e exists:$sectionExists)";
    for(my $i=$b;$i<$e;$i++) {
        if (index($lines[$i], $find) != -1) {
            $location=$i+1;
            return;
        }
    }
    $location=$e;
}

foreach my $scl (@sflines) {
    if($scl=~/^\s*;/ ) { # comment
    } elsif($scl=~/^set ([^=]*)=(.*)$/ ) {
        my ($var,$value)=($1,$2);
        set($var,$value);
    } elsif($scl=~/^section\s*(.*)$/ || $scl=~/^\[(.*)\]$/) {
        ($section)=($1);
        Dprint "section $section";
        @pre_section_comment=@pre_comment;
        @pre_comment=();
    } elsif($scl=~/^(global )?(location )?(last|end)$/ ) {
        location_end($1);
    } elsif($scl=~/^(global )?(location )?(start|begin.*)$/ ) {
        location_start($1);
    } elsif($scl=~/^(global )?(location )?find (.*)$/ ) {
        my ($global,$find)=($1,$3);
        location_find($global,$find);
    } elsif($scl=~/^(precomment|comment) (.*)$/ ) {
        my ($comment)=($2);
        push(@pre_comment,$comment);
    } elsif($scl=~/^\s*$/ ) {
    } elsif($scl=~/^\s*#/ ) {
    } else {
        UsageCommands("Unsupport command:$scl");
    }
}

my $NEWCONTENT=join("\n", @lines)."\n";

if ( $MKDIR ) {
    my $dirname  = dirname($cfgFile);
    MkDirP($dirname);
}

my $ret=LazyWriteFile($cfgFile,$NEWCONTENT);
exit $ret; # 1=file changed
