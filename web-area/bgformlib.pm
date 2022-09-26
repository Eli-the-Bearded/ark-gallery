# Written in 1998 to be a light-weight multipart/form-data aware form
# library. LWP is not light-weight, but it's better than it was in 1998
# by virtue of splitting it into submodules.
#
# Function prototypes were a new feature in Perl then, but are obscure
# now and signatures are preferred. That will lead to odd looking (in
# 2022) declarations.

package FL;
use strict;

# Interface
sub doform ($$\%\%\%);
# Takes a soft and hard maximum form size (bytes) as input and reads the
# form data from the query string or POST as appropriate (both methods
# cannot be used at once, POST wins over GET). If the form size is larger
# than the soft limit, but less than the hard, the form will be read but
# not processed. This allows returning an error message to the user. Above
# the hard limit the form is not read and error pages cannot be returned.
#
# Returns values in three hashes:
# The first is metadata about the form itself key "type" will be
# "error", "get", "post", "mimepost"; key "size" will be form size;
# key "boundary" will be empty on non-mime forms, and the MIME boundary
# on others. The second hash will have key value pairs for the form
# contents. The third hash will have key metadata pairs for MIME
# header info. When the "type" is "error" there will be two other
# metadata keys, "errortext" with generic text about the problem, and
# "debugtext" with debug information about the problem. This function
# calls dump() or parsedata().

sub decode($);
# A function to decode URL encoding of a single value.

sub parsedata (\$\%\%);
# Takes form data (POST content or $QUERY_STRING) ref as input and
# populates two hashes. The first has dataname => value pairs. The
# second has dataname => property pairs. Typically only file uploads
# have properties, and that is the file name. The return value is
# the MIME boundary on a MIME form, a true value for other forms, and
# undef otherwise. This will call either of parsemimeform or
# parsesimpleform as required.

sub dump ($);
# Read up to the supplied number of bytes from stdin, disposing of data.

sub safestr($);
# Returns a string safe for displaying in HTML. (Encodes < & > for
# anti-CSS measures.)

sub urlstr($);
# Returns a string safe for safe for use in a URL. Encodes % & < > = / " '
# and whitespace.

sub debug(\%\%\%);
# Dump the formdata, the form key-value, and the form key-metadata
# hashes as a text/plain output.

sub parsemimeform (\$$\%\%);
# Inputs are a ref to the data, the mime boundary, a ref to the value hash,
# a ref to the properties hash. Returns the boundary or undef.

sub parsesimpleform (\$\%);
# Inputs are a ref to the data, and a ref to the value hash. Returns 1
# or undef.

#############################################################################

sub doform ($$\%\%\%) {
  my $softcap    = shift;
  my $hardcap    = shift;
  my $forminfo_r = shift;
  my $data_r     = shift;
  my $metadata_r = shift;
  my $data;

  ${$forminfo_r}{boundary} = ''; # default

  if (   defined($ENV{'REQUEST_METHOD'})
   and        ($ENV{'REQUEST_METHOD'}  eq 'POST'  )
   and defined($ENV{'CONTENT_LENGTH'})
   and        ($ENV{'CONTENT_LENGTH'}  =~ /(\d+)/ )
   ) {
    my $size = $1;
    my $readsize;

    ${$forminfo_r}{size} = $size;
    if ($size > $softcap) {

      # Unless we read it all, the browser may continue trying to
      # write stuff and not read the results, and we both end up hung.
      # But don't allow a denial of service attack with too large an
      # input.
      if ($size <= $hardcap) {
        &dump($size);
      }

      ${$forminfo_r}{type} = 'error';
      ${$forminfo_r}{errortext} = 'This submission is too large.';
      ${$forminfo_r}{debugtext} = "(cap==$softcap bytes) > this==$size bytes)";
      
      return(${$forminfo_r}{type});
    } # if form too large

    $readsize = read(STDIN, $data, $size);
    if ($size != $readsize) {
      my $debug = 'REQUEST_METHOD: ' . $ENV{'REQUEST_METHOD'}  . "\n".
	    'CONTENT_LENGTH: ' . $ENV{'CONTENT_LENGTH'}        . "\n".
	    'QUERY_STRING: '   . $ENV{'QUERY_STRING'}          . "\n";

      ${$forminfo_r}{type} = 'error';
      ${$forminfo_r}{errortext} = 'This cgi could not get all its arguments.';
      ${$forminfo_r}{debugtext} = $debug;

      return(${$forminfo_r}{type});
    } # if didn't read it all

    ${$forminfo_r}{type} = 'post';
      
  } # if good POST form

  elsif (   defined($ENV{'REQUEST_METHOD'})
	  and        ($ENV{'REQUEST_METHOD'}  eq 'GET'  )
	  and defined($ENV{'QUERY_STRING'})
	  and        ($ENV{'QUERY_STRING'}  =~ /.+/ ))
  {
    ${$forminfo_r}{type} = 'get';
    $data = $ENV{'QUERY_STRING'};
    ${$forminfo_r}{size} = length($data);

  } else {
    ${$forminfo_r}{type} = 'error';
    ${$forminfo_r}{errortext} = 'This cgi script must be used with a form.';
    ${$forminfo_r}{debugtext} = 'No form found.';
    return(${$forminfo_r}{type});
  }

  my $boundary = &parsedata(\$data, $data_r, $metadata_r);

  if (!defined($boundary)) {
    ${$forminfo_r}{type} = 'error';
    ${$forminfo_r}{errortext} = 'This cgi script had an internal problem.';
    ${$forminfo_r}{debugtext} = 'An unknown parse error occured.';
  }
  elsif ($boundary ne '') {
    ${$forminfo_r}{type}     = 'mimepost';
    ${$forminfo_r}{boundary} = $boundary;
  }

  return(${$forminfo_r}{type});

} # end &doform 

##############

# Decides which parsing method to use and invokes the right function.
# Returns the MIME boundary if a MIME form, a true value if a simple
# form that could be parsed, and undef() otherwise.
sub parsedata (\$\%\%) {
  my $data       = shift; # ref to data to parse
  my $in         = shift; # ref to hash to set
  my $properties = shift; # ref to hash to set

  # CONTENT_TYPE is not set for PUT/GET
  if (! defined($ENV{'CONTENT_TYPE'})
      or $ENV{'CONTENT_TYPE'} =~ m,application/x-www-form-urlencoded,i) {
    my $rc = &parsesimpleform($data, $in);
    if ($rc) { 
      return '';
    } else {
      return undef;
    }
  } elsif ($ENV{'CONTENT_TYPE'} =~ m,multipart/form-data \b .* \b
                                     boundary=('[^']*?'|"[^"]*?"|\S+[^;\s=])
                                    ,ix) {
    return &parsemimeform($data, $1, $in, $properties);
  }
  undef;
} # &parsedata

##############

# MIME forms are encoded very similarly to MIME mail, but don't expect
# base64 or quoted-printable encoding: HTTP is supposed to be 8-bit clean.
# This returns the boundary string.
sub parsemimeform (\$$\%\%) {
  my $data       = shift; # ref to form data (parsed here)
  my $boundary   = shift; # MIME boundary string
  my $in         = shift; # ref to hash of input (set here)
  my $properties = shift; # ref to hash of input properties (set here)
  my @parts;
  my $section;
  local ($^W);

  # Normally \n is \012, but this is not necessarily the case, so we use \015 and
  # \012 to mean \r and \n here respectively.

  @parts = split(/(?:\A|\015?\012)--$boundary/,$$data);
  for ($section = 0; $section <= $#parts; $section++) {
    my $heads;
    my $value;
    my $name;
    my $file;
    my $warnings = $^W;

    
    last if $parts[$section] =~ /^--(\015?\012|\Z)/;

    ($heads, $value) = $parts[$section] =~ /^(?:\015?\012)?
                        ( # Expect at least one header of
                          # at least one character
                          (?:[^\015\012]+ \015?\012)+
                        )
                        \015?\012
                        (.*)/sx;
    $heads =~ s/\015\012/\012/g;

    $^W = 0; # disable warnings for a spell (if enabled)

    ($name) = $heads =~ /^Content-disposition:[^\012]* \b
                            name=( " (?: [^\012"]+ | " (?![\012;]) )+ "
                                 | ' (?: [^\012']+ | ' (?![\012;]) )+ '
                                 | \S+[^;\s='"]
                                 )
                            (?=[;\012]) /xim;
    $name =~ s/^(['"])(.*)\1$/$2/;
    if ($heads =~ s/^Content-disposition:[^\012]* \b
		     filename=( " (?: [^\012"]+ | " (?![\012;]) )+ "
			      | ' (?: [^\012']+ | ' (?![\012;]) )+ '
			      | \S+[^;\s='"]
			      )
			 (?=[;\012])
		   /Content-disposition: attachment; filename=$1/xim) {
      $file = $1;
      $file =~ s/^(['"])(.+)\1/$2/;
    } else {
      undef($file);
    }

    if (defined($name)) {
      if ($file) {
        $$properties{$name} = $file; 
      }
      $$in{$name} = $value;
    }

    $^W = $warnings; # restore warnings to previous state
  }
  
  $boundary;
} # &parsemimeform

##############

# Simple forms are 'application/x-www-form-urlencoded' data: the
# standard CGI form.
sub parsesimpleform (\$\%) {
   my $formthing = shift; # ref to form data (parsed here)
   my $in        = shift; # ref to input hash (set here)
   my $field;
   my @fields;
   
   # Expects something like:
   # foo=wow%21&bar=mitzvah&baz=blah

   # Split the string into each of the key-value pairs
   (@fields) = split('&', $$formthing);

   # For each of these key-value pairs, decode the value
   for $field (@fields)   {
     my $name;
     my $value;
     
     # Split the key-value pair on the equal sign.
     ($name, $value) = split('=', $field);

     if(!defined($value)) { $value = ''; }

     # Change all plus signs to spaces. This is an
     # remnant of ISINDEX
     $name  =~ y/\+/ /;
     $value =~ y/\+/ /;

     # Decode the value & removes % escapes.
     $name  =~ s/%([\da-f]{1,2})/pack('C',hex($1))/eig;
     $value =~ s/%([\da-f]{1,2})/pack('C',hex($1))/eig;

     # Create the appropriate entry in the
     # associative array lookup
     if(defined ${$in}{$name})     {
       # If there are multiple values, separate
       # them by newlines
       ${$in}{$name} .= "\n".$value;
     }     else     {
       ${$in}{$name} = $value;
     }
   }

   1;
} # &parsesimpleform

##############

# A function to decode a single value.
sub decode($) {
  my $value = shift;

  # Change all plus signs to spaces. This is an
  # remnant of ISINDEX
  $value =~ y/\+/ /;

  # Decode the value & removes % escapes.
  $value =~ s/%([\da-f]{1,2})/pack('C',hex($1))/eig;

  $value;
} # end &decode

##############

# Reads a whole lot of data, ignoring it.
sub dump ($) {
  my $size = shift;
  my $read = 0;
  my $ignore;
  my $readsize = 1024;

  while(sysread(STDIN,$ignore,$readsize)) {
    $read += $readsize;
    last if $read >= $size;
  }

} # &dump

# Returns a string safe for displaying in HTML. (Encodes < & > for
# anti-CSS measures.)
sub safestr($) {
  my $str = shift;

  if(!defined($str)) { return ''; }
  $str =~ s/&/&amp;/g;
  $str =~ s/</&lt;/g;
  $str =~ s/>/&gt;/g;
  $str;
} # end &safestr

# Returns a string safe for safe for use in a URL. Encodes % ? & < > = / " '
# and whitespace.
sub urlstr($) {
  my $str = shift;

  if(!defined($str)) { return ''; }
  $str =~ s/%/%25/g;
  $str =~ s/\?/%3f/g;
  $str =~ s/&/%26/g;
  $str =~ s/</%3c/g;
  $str =~ s/>/%3e/g;
  $str =~ s/=/%3d/g;
  $str =~ s:/:%2f:g;
  $str =~ s/"/%22/g;
  $str =~ s/'/%27/g;
  $str =~ s/\t/%09/g;
  $str =~ s/\cJ/%0a/g;
  $str =~ s/\cM/%0d/g;
  $str =~ s/ /+/g;
  $str;
} # end &urlstr

# dump the hashes for debuging
sub debug(\%\%\%) {
  my $forminfo_r = shift;
  my $data_r     = shift;
  my $metadata_r = shift;
  my $k;

  print "Content-Type: text/plain\n\n";
  print "\n";

  print "Forminfo:\n";
  for $k (keys %{$forminfo_r}) {
    print "$k => ${$forminfo_r}{$k}\n";
  }

  print "\n";
  print "Form data:\n";
  for $k (keys %{$data_r}) {
    ${$data_r}{$k} =~ s/\n/\n      /g;
    print "$k => ${$data_r}{$k}\n";
    if (defined(${$metadata_r}{$k}) and ${$metadata_r}{$k} ne '') {
      print "$k filename: ${$metadata_r}{$k}\n\n";
    }
  }
 
  exit;
} # end &debug

1;
