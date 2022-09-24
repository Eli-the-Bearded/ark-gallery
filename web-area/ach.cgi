#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBI;
use JSON::PP;

use vars qw( $rc $cgi
	     $dbh $statement
	     $frag $num $tag @tags
	     );

require '/home/eli/photo-gallery/db-funcs.pm';

if (     defined($ENV{'REQUEST_METHOD'})
     and        ($ENV{'REQUEST_METHOD'}  eq 'POST'  )
     and defined($ENV{'CONTENT_LENGTH'})
     and        ($ENV{'CONTENT_LENGTH'}  =~ /(\d+)/ )
   ) {
        my $size = $1;
        if ($size < 1 or $size > 2000) { exit 0; }
	$cgi = 1;

	my $data;
	read(STDIN, $data, $size);

	if (defined($ENV{'CONTENT_TYPE'})
	    and     $ENV{'CONTENT_TYPE'} =~ /multipart/ ) {

	  # grab first part body
          if ($data =~ /\n\r?\n([^\r\n]+)\r?\n--/) {
	     unshift(@ARGV,$1);
	  }
	} elsif ($data =~ /\w+=([^&]+)/) {
	  unshift(@ARGV,$1);
	}
}

$frag = ($ARGV[0] or 'help');
$num  = 10;

$dbh = ark::dbconnect();

@tags = ark::tag_fragment_search($dbh, $frag, $num);
$rc  = $dbh->disconnect;

if($cgi) {
  print "Content-Type: text/plain; charset=UTF-8\n";
  print "\n";
  print encode_json(\@tags);
  print "\n";
} else {
  $" = "\n\t"; # list separator for quoted arrays
  print "Top $num matches:\n\t@tags\n";
}
__END__
REQUEST_METHOD=POST
CONTENT_LENGTH=179
CONTENT_TYPE="multipart/form-data; boundary=---------------------------299144911727878228763415194987"

-----------------------------299144911727878228763415194987
Content-Disposition: form-data; name="search"

jewe
-----------------------------299144911727878228763415194987--
