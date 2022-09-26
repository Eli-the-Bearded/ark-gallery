#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBI;
use Digest::MD5 qw( md5_base64 );
# part of standard perl distrib and much faster than Data::Dumper
use Storable qw/ store_fd retrieve /;

require '/home/eli/photo-gallery/web-area/bgformlib.pm';
require '/home/eli/photo-gallery/db-funcs.pm';

use vars qw( $cgi $url $limit $offset $baseurl
	     $rc $count $col $id
	     $dbh $cache $cbase
	     %parts
	     $parts @params $sparam
	     $query $query_order $query_limit
	     $sth $answer @columns
	     );

# at top for more(1) or less(1)
sub usage {
  if ($cgi) {
    print "Content-Type: text/plain\n\n";
  }

  print "find-image general options:\n";
  print "  --newer  / -N 	sort newer first\n";
  print "  --older  / -O 	sort older first\n";
  print "  --random / -R 	random order results\n";
  print "  --limit  / -L 	smaller sample size\n";
  print "\n";
  print "Searching optins:\n";
  print "  --anywhere    TEXT / -A TEXT         description or title or tag\n";
  print "                                          or filename like %TEXT%\n";
  print "  --tag         TEXT / -t TEXT         and clean tag TEXT\n";
  print "  --ortag       TEXT / -o TEXT         or clean tag TEXT\n";
  print "  --taglike     TEXT / -l TEXT         and clean tag like %TEXT%\n";
  print "  --nottag      TEXT / -n TEXT         does not have tag TEXT\n";
  print "  --title       TEXT / -T TEXT         and with TEXT in title\n";
  print "  --description TEXT / -d TEXT         and with TEXT in description\n";
  print "  --filename    TEXT / -f TEXT         and with TEXT in filename\n";
  print "  --after       DATETIME / -a DATETIME after  'YYYY:MM:DD HH:MM:SS'\n";
  print "  --before      DATETIME / -b DATETIME before 'YYYY:MM:DD HH:MM:SS'\n";
  print "\n";
  print "DATETIME can be shortened to YYYY, or YYYY:MM, etc\n";
  exit;
} # end &usage 

# debug print in CLI, but not in CGI (at top due to sub prototype)
sub dbout($) {
  my $out = shift;
  if (!$cgi) { print($out); }
}

# Safely dump text in a div. (at top due to sub prototype)
sub divout($) {
  my $out = shift;
  print '<div>' . FL::safestr($out) . '</div>';
}

# CGI friendly die() alternative (at top due to sub prototype)
sub safedie($) {
  my $out = shift;
  if ($cgi) { print('<h3>Yow!</h3>'); divout($out); exit;   }
  else      { warn($out);                           exit 2; }
}

main();

exit;

##############################################################
# Functions
#
# most of 'em, anyway

# calls everything else
sub main {
  init_vars();

  if($cgi) { cgi_to_argv(); }
  parse_argv();

  prep_cache();
  output_start();

  # this will be used for tag, title, description lookups
  # even if main search is cached
  $dbh = ark::dbconnect();

  if($cache and (-f $cache)) {
    $answer = load_cache($cache);
  } else {
    $answer = run_search($dbh, $query, \@params);
    save_cache($cache, $answer);
  }

  show_answer();

  $rc = $dbh->disconnect;

  output_finish();
} # end &main 

# does what it says on the tin
sub init_vars {

  $cgi = (exists($ENV{GATEWAY_INTERFACE}) and length($ENV{GATEWAY_INTERFACE}));

  # fragments of SQL for building a search query [
  %parts = (
   start => q#
     SELECT a.* FROM `ark_images` a
   #,

   tags_join => q#
           INNER JOIN `ark_images_tags` i ON i.`image_id` = a.`image_id` 
	   INNER JOIN `ark_tags` t        ON t.`tag_id`   = i.`tag_id`
   #,

   # takes four params: %TERM% %TERM% TERM %TERM%
   anywhere_block => q#
	   SELECT a.`image_id` WHERE a.`image_name` LIKE ?
           UNION
	   SELECT l.`image_id` FROM `ark_title` l WHERE l.`title` LIKE ?
           UNION
	   SELECT d.`image_id` FROM `ark_description` d
               WHERE MATCH (d.`description`) AGAINST (?)
           UNION
	   SELECT DISTINCT a.`image_id` FROM `ark_images` a
                 INNER JOIN `ark_images_tags` i ON i.`image_id` = a.`image_id`
                 INNER JOIN `ark_tags` t        ON t.`tag_id`   = i.`tag_id`
               WHERE t.`tag_clean` LIKE ?
   #,

   title_join => q#
           INNER JOIN `ark_title` l ON l.`image_id` = a.`image_id`
   #,

   description_join => q#
           INNER JOIN `ark_description` d ON d.`image_id` = a.`image_id`
   #,

   tags_where => q#
	 WHERE t.`tag_clean` = ?
   #,

   where_in => q#
	 WHERE a.`image_id` IN (
   #,

   where_not_in => q#
	 WHERE a.`image_id` NOT IN (
   #,

   tags_where_like => q#
	 WHERE t.`tag_clean` LIKE ?
   #,

   title_where_like => q#
	 WHERE l.`title` LIKE ?
   #,

   filename_where_like => q#
	 WHERE a.`image_name` LIKE ?
   #,

   description_match => q#
	 WHERE MATCH (d.`description`) AGAINST (?)
   #,

   where_before => q#
	 WHERE a.`image_date` < ?
   #,

   where_after => q#
	 WHERE a.`image_date` > ?
   #,

   and_before => q#
	 AND a.`image_date` < ?
   #,

   and_after => q#
	 AND a.`image_date` > ?
   #,

   sub_start => q#
   	   SELECT DISTINCT a.`image_id` FROM `ark_images` a
   #,

   and_in => q#
	 AND a.`image_id` IN (
   #,

   or_in => q#
	 OR a.`image_id` IN (
   #,

   and_not_in => q#
	 AND a.`image_id` NOT IN (
   #,

   end_in => q#
	 )
   #,

   sort_recent => q#
       ORDER BY a.image_date DESC
   #,
   
   sort_older => q#
       ORDER BY a.image_date
   #,

   random => q#
       ORDER BY RAND()
   #,

   limit => q#
       LIMIT 10
   #,
  ); # ]

  $query = $parts{start};
  $query_order = '';
  $query_limit = 'LIMIT 50'; # blank when done, LIMIT 50 during testing
  $offset = $parts = 0;
  $limit  = 50;

  @columns = qw| image_id width height image_path
                 image_name image_date components bits |;

  # Note that I assume a single purpose computer here and
  # I don't worry about race conditions. Cache could easily
  # be corrupted by a malicious actor or concurrent use.
  $cbase = '/tmp/cache/';
} # end &init_vars 


# ARGV could be a real command line or one created by cgi_to_argv
sub parse_argv {
  while( defined(my $frag = shift @ARGV) ) {
   if($frag eq '--tag' or $frag eq '-t') {
      if($parts) {
        $query .= $parts{and_in} .
		    $parts{sub_start} .
		    $parts{tags_join} .
		    $parts{tags_where} .
		  $parts{end_in} ;
      } else {
        $query .= $parts{tags_join} .
		  $parts{tags_where};

      }

      $parts ++;
      push(@params, shift @ARGV);
      next;
   }

   if($frag eq '--ortag' or $frag eq '-o') {
      if($parts) {
        $query .= $parts{or_in} .
		    $parts{sub_start} .
		    $parts{tags_join} .
		    $parts{tags_where} .
		  $parts{end_in} ;
      } else {
        # or doesn't make sense as first, treat as --tag
        $query .= $parts{tags_join} .
		  $parts{tags_where};
      }

      $parts ++;
      push(@params, shift @ARGV);
      next;
   }

   if($frag eq '--nottag' or $frag eq '-n') {
      if($parts) {
        $query .= $parts{and_not_in} .
		    $parts{sub_start} .
		    $parts{tags_join} .
		    $parts{tags_where} .
		  $parts{end_in} ;
      } else {
        $query .= $parts{where_not_in} .
		    $parts{sub_start} .
		    $parts{tags_join} .
		    $parts{tags_where} .
		  $parts{end_in} ;
      }

      $parts ++;
      push(@params, shift @ARGV);
      next;
   }

   if($frag eq '--taglike' or $frag eq '-l') {
      if($parts) {
        $query .= $parts{and_in} .
		    $parts{sub_start} .
		    $parts{tags_join} .
		    $parts{tags_where_like} .
		  $parts{end_in} ;
      } else {
        $query .= $parts{tags_join} .
		  $parts{tags_where_like};

      }

      $parts ++;
      $frag = shift @ARGV;
      push(@params, "%$frag%");
      next;
   }

   if($frag eq '--title' or $frag eq '-T') {
      if($parts) {
        $query .= $parts{and_in} .
		    $parts{sub_start} .
		    $parts{title_join} .
		    $parts{title_where_like} .
		  $parts{end_in} ;
      } else {
        $query .= $parts{title_join} .
		  $parts{title_where_like};

      }

      $parts ++;
      $frag = shift @ARGV;
      push(@params, "%$frag%");
      next;
   }

   if($frag eq '--description' or $frag eq '-d') {
      if($parts) {
        $query .= $parts{and_in} .
		    $parts{sub_start} .
		    $parts{description_join} .
		    $parts{description_match} .
		  $parts{end_in} ;
      } else {
        $query .= $parts{description_join} .
		  $parts{description_match};

      }

      $parts ++;
      $frag = shift @ARGV;
      push(@params, $frag);
      next;
   }

   if($frag eq '--filename' or $frag eq '-f') {
      if($parts) {
        $query .= $parts{and_in} .
		    $parts{sub_start} .
		    $parts{filename_where_like} .
		  $parts{end_in} ;
      } else {
        $query .= $parts{filename_where_like};

      }

      $parts ++;
      $frag = shift @ARGV;
      push(@params, "%$frag%");
      next;
   }


   if($frag eq '--anywhere' or $frag eq '-A') {
      if($parts) {
        $query .= $parts{and_in} .
		    $parts{anywhere_block} .
		  $parts{end_in} ;
      } else {
        $query .= $parts{where_in} .
		    $parts{anywhere_block} .
		  $parts{end_in};

      }

      $frag = shift @ARGV;
      push(@params, "%$frag%", "%$frag%", $frag, "%$frag%");
      $parts += 3;
      next;
   }

   if($frag eq '--after' or $frag eq '-a') {
      if($parts) {
        $query .= $parts{and_after};
      } else {
        $query .= $parts{where_after};
      }

      $parts ++;
      push(@params, shift @ARGV);
      next;
   }

   if($frag eq '--before' or $frag eq '-b') {
      if($parts) {
        $query .= $parts{and_before};
      } else {
        $query .= $parts{where_before};
      }

      $parts ++;
      push(@params, shift @ARGV);
      next;
   }

   if($frag eq '--newer' or $frag eq '-N') {
      $query_order = $parts{sort_recent};
      next;
   }

   if($frag eq '--older' or $frag eq '-O') {
      $query_order = $parts{sort_older};
      next;
   }

   if($frag eq '--random' or $frag eq '-R') {
      $query_order = $parts{random};
      next;
   }

   if($frag eq '--limit' or $frag eq '-L') {
      $query_limit = $parts{limit};
      next;
   }

   print "$0: unknown option $frag\n";
   usage();
  }

  $query .= "$query_order$query_limit;\n";
  $query =~ s,\n\s*\n+,\n,gm;
  $query =~ s,\A\s+,,;

  local $" = ', ';
  $sparam = "@params";
} # end &parse_argv 


# Most of the CGI parameters map directly to command line
# So this builds a command line from them, and does a little
# bit of order of SQL optimization in the process. Non-command
# line options like pagination go to globals.
sub cgi_to_argv {
  # CGI params:
  # Singletons:
  #   limit=\d+				per page limit
  #   offset=\d+			for paging results
  #   before=DATE			date limiter
  #   after=DATE			date limiter
  #   sort=NEWER|OLDER|RANDOM		sorting method
  #   name0 				LIKE filename
  # 
  # Multiples:
  #   tag0 tag1 ...			AND tags
  #   frag0 frag1 ...			LIKE tags
  #   xtag0 xtag1 ...			NOT tags
  #   title0 title1 ...			AND title
  #   desc0 desc1 ...			AND description
  #   anywhere0 anywhere1 ...		AND anywhere

  # for quirky bgformlib interface
  my ( $formmax, %in, %prop, %forminfo, $tainted, $untainted );

  # start building a URL for pagination results
  if ($ENV{REQUEST_URI} =~ m:^(/\w[\w./]+):) {
    $url = "$1?";
  } else {
    $url = '/a/?';
  }
  $baseurl = $url;

  print "Content-Type: text/html\n\n";
  open(STDERR, ">&STDOUT")     || safedie "Can't dup stdout";
  binmode(STDERR, ":utf8");
  binmode(STDOUT, ":utf8");

  # Cap input at 8k (including form encoding overhead)
  $formmax = (1024*8);
  #           data      immediate
  #           parse     exit                    form  form data
  #           limit     threshold   form meta   data  meta
  &FL::doform($formmax, 2*$formmax, \%forminfo, \%in, \%prop);

  # Probably no QUERY_STRING or over $formmax, but could be a total mess
  if ($forminfo{type} eq 'error') {
    safedie "Wow, that sucked.";
  }

  # Now tainted values from %in can be placed in @ARGV
  # in a better order than a user might know to do
  if (defined($tainted = $in{before})) {
    if($tainted =~ /^(\d+[:\d ]*)/) {
      push(@ARGV, '--before', $1);
      $untainted = &FL::urlstr($1);
      $url .= 'before=' . $untainted . '&';
    }
  }

  if (defined($tainted = $in{after})) {
    if($tainted =~ /^(\d+[:\d ]*)/) {
      push(@ARGV, '--after', $1);
      $untainted = &FL::urlstr($1);
      $url .= 'before=' . $untainted . '&';
    }
  }

  if (defined($tainted = $in{name0})) {
    if($tainted =~ m,^([^/]+),) {
      push(@ARGV, '--filename', $1);
      $untainted = &FL::urlstr($1);
      $url .= 'name0=' . $untainted . '&';
    }
  }

  paramloop(\%in, 'title',    '--title');
  paramloop(\%in, 'desc',     '--description');
  paramloop(\%in, 'tag',      '--tag');
  paramloop(\%in, 'xtag',     '--nottag');
  paramloop(\%in, 'frag',     '--taglike');
  paramloop(\%in, 'anywhere', '--anywhere');

  # case insensitive match
  if (defined($tainted = lc($in{sort}))) {
    if($tainted =~ /^(newer|older|random)/) {
      push(@ARGV, "--$1");
      $url .= 'sort=' . $1 . '&';
    }
  }

  if (defined($tainted = $in{limit})) {
    if($tainted =~ /^(\d+)/) {
      $limit = 0+$1;
      $url .= 'limit=' . $1 . '&';
    }
  }
  if (defined($tainted = $in{offset})) {
    if($tainted =~ /^(\d+)/) {
      $offset = 0+$1;
      # don't put in URL
    }
  }

  chop($url);
} # end &cgi_to_argv 


# helper for cgi_to_argv
sub paramloop {
  my $ir   = shift;	# ref to %in
  my $base = shift;	# base parameter name
  my $arg  = shift;	# ARGV name
  my $n = 0;
  my $m = 0;
  my $use;
  my $tainted;

  # $n is never capped, but form submission size was strictly capped
  # The form javascript starts at 0 and goes up on each '[+]' click
  # but it's possible for a person to skip using some. Looping
  # ends when we stop finding them. Values are only copied to URL if
  # non-blank, and renumbered to skip blanks.
  while( defined( $tainted = ${$ir}{"$base$n"} ) ) {
    $n ++;
    if ($tainted =~ /(\S.*)/) { $use = $1; } else { next; }
    $url .= "$base$m=" . FL::urlstr($use) . '&';
    $m ++;
    push(@ARGV, $arg, $use);
  }
} # end &paramloop 


# sets global $cache, creates cache base directory if needed
sub prep_cache {
  my $cacheid = join('!', $query, $sparam);
  $cacheid    =~ s,\s+,,g;
  $cache      = md5_base64($cacheid);
  $cache      =~ s/\W/_/g;
  $cacheid    = $cache;
  $cache      = "$cbase/$cache";

  # directory needs to safely coexist between CGI and command line usage
  # (but note: contents of directory are assumed trusted)
  if(! -d $cbase) { mkdir($cbase) or $cache = ''; chmod(01777, $cbase); }
} # end &prep_cache 


# turn the query into results, used when there is no cache
sub run_search {
  my $dbh    = shift;
  my $query  = shift;
  my $params = shift;

  my $sth = $dbh->prepare($query);
  $sth->execute(@$params);

  return $sth->fetchall_arrayref;
} # end &run_search 


sub output_start {
  if(!$cgi) {
    # these are the ingredients for the md5 filename for cache file, too
    print $query;
    print "Binding params: $sparam\n";
  }
} # end &output_start 

sub output_finish {
  if ($count == 0) {
    print "No results\n";
  } elsif ($cgi) {
    print scalar(@$answer) . " results total<br/>\n";
    $offset += $limit;
    print "Next: $url&offset=$offset\n";
  }
} # end &output_finish 

# CGI or command line
sub show_answer {
  $count = $offset; # zero unless in cgi pagination
  while ( my $row_ref = ${$answer}[$count] ) {
    if ($cgi and $limit == ($count - $offset)) { last; }
    print "Match $count\n"; $count ++;
    if($cgi) { print "<br/>"; }
    if($cgi) {
      my $ipath = $$row_ref[3]; # 3 is image_path, FIXME

      # This is based on how I "alias" directories in apache
      $ipath =~ s,^/data/,/po,; 

      # I have .100 and .200 thumbnails, but I really only ever
      # use larger. The .200 files serve as image/jpeg, and are
      # 200 pixels tall, unlimited width, preserving aspect ratio
      # from originals. This is a panorama friendly thumbnail.
      my $tpath = $ipath;
      $tpath =~ s,^/poi,/pot,;
      $tpath =~ s/[.][^.]*$/.200/;

      print qq(<a href="$ipath"><img src="$tpath" height=200></a><br/>\n);
    }

    # temp during devel
    die if ($parts > 50);

    $col = 0;
    for my $k (@columns) {
      print "$k: $$row_ref[$col]   ";
      if($col == 0) {
	$id = $$row_ref[$col];
      }
      $col ++;
    }
    if($cgi) { print "<br/>"; }
    print "\n";

    print "Tags: " . join("; ", ark::get_tags_for_image($dbh, $id)) . "\n";
    if($cgi) { print "<br/>"; }
    if ( $_ = ark::get_title_for_image($dbh, $id) ) {
      print "Title: $_\n";
      if($cgi) { print "<br/>"; }
    }
    if ( $_ = ark::get_description_for_image($dbh, $id) ) {
      s/\\n/\n/g;
      print "Description: $_\n";
      if($cgi) { print "<br/>"; }
    }

    if($cgi) { print "<hr/>"; }
    print "\n\n";
  }
} # end &show_answer 

# freeze a Storable file
sub save_cache {
  my $file = shift;
  my $answer = shift;
  my $fd;
  if(!open($fd, '>', $file)) { print "Whoops, $!\n"; return; }
  store_fd($answer, $fd);
  close $fd;
} # end &save_cache


# thaw a Storable file
sub load_cache {
  my $file = shift;
  return retrieve($file);
} # end &load_cache

__END__
