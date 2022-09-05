#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBI;
use JSON::PP;

use vars qw( $rc
	     $dbh $statement
	     $ark_tag_search_statement
	     $frag $tag @tags
	     );

$rc = do '/home/eli/photo-gallery/db-funcs.pm';
if(!defined($rc)) { die "Content-Type: text/plain\n\nFailed to load db functions file\n"; }

if (     defined($ENV{'REQUEST_METHOD'})
     and        ($ENV{'REQUEST_METHOD'}  eq 'POST'  )
     and defined($ENV{'CONTENT_LENGTH'})
     and        ($ENV{'CONTENT_LENGTH'}  =~ /(\d+)/ )
   ) {
        my $size = $1;
        if ($size < 1 or $size > 2000) { exit 0; }

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

$frag = clean_tag($ARGV[0] or 'help');

$dbh = dbconnect();

$statement = $dbh->prepare( $ark_tag_search_statement );
$statement->execute( "%$frag%", 10 );
# fetchall_arrayref returns a one element array for every row
# the map removes the inner arrays
my $result = $statement->fetchall_arrayref();
@tags = map { $$_[0] } @$result;

$rc  = $dbh->disconnect;
print "Content-Type: text/plain; charset=UTF-8\n";
print "\n";
print encode_json(\@tags);
print "\n";

__END__
REQUEST_METHOD=POST
CONTENT_LENGTH=179
CONTENT_TYPE=multipart/form-data; boundary=---------------------------299144911727878228763415194987

-----------------------------299144911727878228763415194987
Content-Disposition: form-data; name="search"

jewe
-----------------------------299144911727878228763415194987--
