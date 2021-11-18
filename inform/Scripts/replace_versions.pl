#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use File::Copy;
use File::Basename;

my $dirname = dirname(__FILE__);

my $app_version_number = "1.68";
my $app_version_build_number = "$app_version_number.1";
my $inform_source_version = "6M62";
my $full_version_prefix = "$app_version_number/6.33/";
my $full_version = "";
#my $inform_core="$dirname/../../../Inform Core";

sub read_version {
    my ($file) = shift;

    if (-e $file) {
        local $/ = undef;
        open FILE, $file or die "Couldn't open file: $!";
        binmode FILE;
        $inform_source_version = <FILE>;
        close FILE;

        $full_version = "$full_version_prefix$inform_source_version";
    } else {
        print "WARNING: Could not read new version number from $file\n";
        exit 0
    }
}

sub replace_in_plist_file {
    my $infile = shift;
    my $find = shift;
    my $replace = shift;

    my $newfile = $infile . ".new";
    open(my $in,"<$infile") || die "$!";
    open my $out, ">$newfile" or die "$!"; 

    my $state = 0;

    while (<$in>) {  
        if (/<key>$find<\/key>/) {  
            print $out $_;  
            $state = 1;
        }
        elsif ($state == 1) {
            print $out "\t<string>$replace</string>\n";
            $state = 0;
        } else {
            print $out $_;
        }
    }  
    close($out) || die;
    close($in) || die;
    
    move($newfile, $infile) or die "The move operation failed: $!";
}

sub replace_in_UTF16_strings_file {
    my $infile = shift;
    my $find = shift;
    my $replace = shift;

    my $newfile = $infile . ".new";
    open(my $in,"<:encoding(UTF-16)","$infile") || die "$!";
    open my $out, ">:encoding(UTF-16BE)","$newfile" or die "$!";
    print $out "\x{FEFF}";

    while (<$in>) {  
        if (/$find/) {  
            print $out "$find = \"$replace\";\n";  
        } else {
            print $out $_;
        }
    }
    close($out) || die "$!";
    close($in) || die "$!";
    
    move($newfile, $infile) or die "The move operation failed: $!";
}

sub replace_in_UTF8_strings_file {
    my $infile = shift;
    my $find = shift;
    my $replace = shift;

    my $newfile = $infile . ".new";
    open(my $in,"<:encoding(UTF-8)","$infile") || die "$!";
    open my $out, ">:encoding(UTF-8)","$newfile" or die "$!"; 

    while (<$in>) {  
        if (/$find/) {  
            print $out "$find = \"$replace\";\n";  
        } else {
            print $out $_;
        }
    }
    close($out) || die "$!";
    close($in) || die "$!";

    move($newfile, $infile) or die "The move operation failed: $!";
}

print "Replace versions: Updating app version in plists\n";

replace_in_plist_file("$dirname/../Inform-Info.plist", "CFBundleVersion", $app_version_build_number);
replace_in_plist_file("$dirname/../Inform-Info.plist", "CFBundleShortVersionString", $app_version_number);

print "Replace versions: Updating to four character version ('$inform_source_version') in strings\n";

# if the directory Inform-Source exists
#if ( -d "$inform_core" ) {
    # Read Inform-Source version string
    # print "Replace versions: Found '$inform_core'\n";
    # read_version("$inform_core/build_number.txt");
    replace_in_UTF16_strings_file("$dirname/../en.lproj/InfoPlist.strings", "CFBundleGetInfoString", "Inform version $full_version");
    replace_in_UTF8_strings_file("$dirname/../en.lproj/Localizable.strings", "\"Build Version\"", "$inform_source_version");
    print "Version number updated to $full_version successfully\n";
#}
print "Replace versions: Finished\n";
