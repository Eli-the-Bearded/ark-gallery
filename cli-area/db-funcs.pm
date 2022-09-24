# image archive
# insert, search, manage data queries and functions
package ark;

use vars qw(
	$credentials_file
	$dbuser $dbhost $dbpass $dbport $database $dbextra
	$tags_statement
	$tag_search_statement
	$tag_recent_statement
	$tag_find_statement
	$title_find_statement
	$description_find_statement
	$add_images_tags_statement
	$tag_update_usage_statement
	$image_tag_find_statement
	$tag_most_statement
	$img_statement
	$images_statement
	$title_statement
	$description_statement
	$exifother_statement
	$location_statement
	$exif_name_statement
	$exif_value_statement
	$find_exif_name_statement
	$find_exif_value_statement
	$exifother_statement
);

$credentials_file = '/home/eli/photo-gallery/.creds.pm';
# $ cat .creds.pm
# $database = 'dbname';
# $dbuser   = 'username';
# $dbpass   = 'password';
# # optional: $dbhost  = 'localhost';
# # optional: $dbport  = 3306;
# # optional: $dbextra = ":foo=bar"; # extra param for DBI->connect()
# $


#############################################################
# SQL statements


# create a new tag; tag must be unique, tag_clean can be duped
#	PARAMS: tag, tag_clean
#	RETURNS: -
$tags_statement = q!
        INSERT INTO `ark_tags` (`tag`, `tag_clean`)
	VALUES (?, ?);
!;

# search for tags by fragment (for autocomplete)
#	PARAMS: taglike, limit
#	RETURNS: tag (multiple rows)
$tag_search_statement = q!
        SELECT `tag` FROM `ark_tags`
       	WHERE `tag_clean` LIKE ? 
	ORDER BY `uses` DESC LIMIT ?;
!;

# search tags for most recently used (for suggesting tags to add)
#	PARAMS: limit
#	RETURNS: tag (multiple rows)
$tag_recent_statement = q!
        SELECT `tag` FROM `ark_tags`
	ORDER BY `last` DESC LIMIT ?;
!;

# search tags for most used (for suggesting tags to add)
#	PARAMS: limit
#	RETURNS: tag (multiple rows)
$tag_most_statement = q!
        SELECT `tag` FROM `ark_tags`
        WHERE `tag_clean` NOT LIKE '\_%'
	ORDER BY `used` DESC LIMIT ?;
!;

# find display version of tags exactly matching tag_clean
#	PARAMS: tag_clean
#	RETURNS: tag_id, tag (multiple rows)
$tag_find_statement = q!
        SELECT `tag_id`, `tag` FROM `ark_tags` WHERE `tag_clean` = ?;
!;

# Get a title
#	PARAMS: image_id
#	RETURNS: title (single row)
$title_find_statement = q!
        SELECT `title` FROM `ark_title` WHERE `image_id` = ?;
!;

# Get a description
#	PARAMS: image_id
#	RETURNS: description (single row)
$description_find_statement = q!
        SELECT `description` FROM `ark_description` WHERE `image_id` = ?;
!;

# find display versions of tags for a particular image_id
#	PARAMS: image_id
#	RETURNS: tag (multiple rows)
$image_tag_find_statement = q!
	SELECT t.`tag` FROM `ark_tags` t
	INNER JOIN `ark_images_tags` i ON t.`tag_id` = i.`tag_id`
	WHERE i.`image_id` = ?;
!;

# update tag last used date and use count
#	PARAMS: tag_id
#	RETURNS: -
$tag_update_usage_statement = q!
	UPDATE `ark_tags`
	   SET `uses` = `uses` + 1, `last` = ?
	   WHERE `tag_id` = ?;
!;

# associate a tag with an image
#	PARAMS: tag_id, image_id
#	RETURNS: -
$add_images_tags_statement = q!
	INSERT INTO `ark_images_tags` VALUES (?, ?);
!;

# create a new image; image_path must be unique; MINIMAL VERSION
#	PARAMS: image_path, image_name, image_date
#	RETURNS: -
$img_statement =q!
	 INSERT INTO `ark_images` (`image_path`,`image_name`,`image_date`)
	 VALUES (?, ?, ?);
!;

# create a new image; image_path must be unique; COMPLETE VERSION
#	PARAMS: image_path, image_name, width, height, image_date, components, bits
#	RETURNS: -
$images_statement = q!
	INSERT INTO `ark_images`
	(`image_path`, `image_name`, `width`, `height`,
	 `image_date`, `components`, `bits`)
	VALUES ( ?, ?, ?, ?, ?, ?, ? );
!;

# insert a new title
#	PARAMS: image_id, title
#	RETURNS: -
$title_statement = q!
	INSERT INTO `ark_title` VALUES (?, ?);
!;

# insert a new description
#	PARAMS: image_id, description
#	RETURNS: -
$description_statement = q!
	INSERT INTO `ark_description` VALUES (?, ?);
!;

# insert a new EXIF extra metadata field
#	PARAMS: image_id, exif_name_id, exif_value_id
#	RETURNS: -
$exifother_statement = q!
        INSERT INTO `ark_exif_other`
                (`image_id`, `exif_name_id`, `exif_value_id`)
                VALUES (?, ?, ?);
!;

# insert a new EXIF field name
#	PARAMS: exif_name
#	RETURNS: -
$exif_name_statement = q!
        INSERT INTO `ark_exif_names` (`exif_name`) VALUES (?);
!;

# insert a new EXIF field value
#	PARAMS: exif_value
#	RETURNS: -
$exif_value_statement = q!
        INSERT INTO `ark_exif_values` (`exif_value`) VALUES (?);
!;

# insert a new location record
#	PARAMS: image_id, loc_type, location
#	RETURNS: -
# loc_type 0   default catchall 
# loc_type 1   lat,long decimal with compass: 40.748616 N,74.004289 W
# loc_type 2   lat,long minutes, deconds with compass: 40 deg 44' 55.02" N, 74 deg 0' 15.44" W
# loc_type 3   lat,long decimal without compass: 40.748616,-74.004289
# loc_type 10  lat decimal without compass: 40.748616
# loc_type 11  long decimal without compass: -74.004289
# (further types possible)
$location_statement = q!
	INSERT INTO `ark_location` VALUES (?, ?, ?);
!;

# get the id for an exif field name
#	PARAMS: exif_name
#	RETURNS: exif_name_id (single row)
$find_exif_name_statement = q!
        SELECT `exif_name_id` FROM `ark_exif_names` WHERE `exif_name` = ?;
!;

# get the id for an exif field value
#	PARAMS: exif_value
#	RETURNS: exif_value_id (single row)
$find_exif_value_statement = q!
        SELECT `exif_value_id` FROM `ark_exif_values` WHERE `exif_value` = ?;
!;

#############################################################
# Psuedo-constants

sub TAGS() { return $tags_statement; }
sub TAG_SEARCH() { return $tag_search_statement; }
sub TAG_RECENT() { return $tag_recent_statement; }
sub TAG_FIND() { return $tag_find_statement; }
sub TITLE_FIND() { return $title_find_statement; }
sub DESCRIPTION_FIND() { return $description_find_statement; }
sub ADD_IMAGES_TAGS() { return $add_images_tags_statement; }
sub TAG_UPDATE_USAGE() { return $tag_update_usage_statement; }
sub IMAGE_TAG_FIND() { return $image_tag_find_statement; }
sub TAG_MOST() { return $tag_most_statement; }
sub IMG() { return $img_statement; }
sub IMAGES() { return $images_statement; }
sub TITLE() { return $title_statement; }
sub DESCRIPTION() { return $description_statement; }
sub EXIFOTHER() { return $exifother_statement; }
sub LOCATION() { return $location_statement; }
sub EXIF_NAME() { return $exif_name_statement; }
sub EXIF_VALUE() { return $exif_value_statement; }
sub FIND_EXIF_NAME() { return $find_exif_name_statement; }
sub FIND_EXIF_VALUE() { return $find_exif_value_statement; }
sub EXIFOTHER() { return $exifother_statement; }

#############################################################
# Functions

# connect to database; takes no options
# gets paramaters from $credentials_file
# dies on failure
sub dbconnect {
  my $connect = 'dbi:mysql:';
  my $rc = do $credentials_file;
  if(!defined($rc)) { die "Failed to load creds file\n"; }

  if (!defined($database) or !length($database)) {
    die "Failed to find database in creds file\n";
  }
  $connect .= "database=$database";

  if (defined($dbhost) and length($dbhost)) {
    $connect .= ":host=$dbhost";
  }
  if (defined($dbport) and length($dbport)) {
    $connect .= ":port=$dbport";
  }

  if (defined($dbextra) and length($dbextra)) {
    $connect .= $dbextra;
  }

  $_ = DBI->connect(
	$connect, $dbuser, $dbpass
  ) ||
  die "Can't connect to mysql $database database: $DBI::errstr\n";

  $_;
} # end &dbconnect 

# helper function to turn display version of a tag to clean version
# 	PARAMS: tag
#	RETURNS: tag_clean
sub clean_tag {
  my $in = shift;

  # always drop whitespace
  $in =~ s/\s+//g;

  # always fold ASCII capitals down
  $in =~ tr:QWERTYUIOPASDFGHJKLZXCVBNM:qwertyuiopasdfghjklzxcvbnm:;

  # save point
  my $out = $in;
  
  # drop most ASCII punctuation; - / _ allowed
  $out =~ s/[!"#\$%&'()*+,.:;<=>?@`\\\[\]^`{|}~]+//g;

  if($out eq '') { 
    # revert if completely gone
    $out = $in;
  }

  $out;
} # end &clean_tag

# helper function to convert lat or long in degrees minutes seconds
# (eg <<12 deg 25' 36.78" N>> to decimal form (eg: <<12.426883 N>>)
# 	PARAMS: lat_or_long_dms
#	RETURNS: lag_or_long_dec
sub decimalizedegrees {
   my $dms     = shift;
   my $degrees;
   my $minutes;
   my $seconds;
   my $news;

   ($degrees, $minutes, $seconds, undef) = ($dms =~ /([\d.]+)\D+/g);
   ($news) = ($dms =~ /\b([NEWS])\s*$/);

   $degrees ||= 0;
   $minutes ||= 0;
   $seconds ||= 0;

   my $decimal = sprintf("%1.6f", $degrees + ($minutes * (1/60)) + ($seconds * (1/3600)));

   # now to tweak north east west south output (either letter or sign)  
   if ($dms =~ /^\s*-/) { $decimal *= -1; }
   if ($news) { $news = " $news"; } else { $news = ''; }

   return "$decimal$news";
} # end &decimalizedegrees 

# add a new (or find an existing) tag_id for a tag (display value version)
# probably called from add_tags_to_image()
#	PARAMS: dbh, tag
#	RETURNS: tag_id
sub find_or_create_tag {
  my $dbh = shift;
  my $tag = shift;

  my $clean = clean_tag( $tag );
  my $find   = $dbh->prepare( $tag_find_statement );
  
  $find->execute( $clean );
  my $result = $find->fetchall_arrayref();

  for my $row (@$result) {
    if ($tag eq $$row[1]) {
      return $$row[0];
    }
  }

  my $insert = $dbh->prepare( $tags_statement );
  $insert->execute( $tag, $clean );

  # "For some drivers the $catalog, $schema, $table, and $field parameter
  # are required, for others they are ignored (e.g., mysql)"
  my $id = $dbh->last_insert_id( undef, undef, undef, undef );

  return $id;
} # end &find_or_create_tag 

# add a new (or find an existing) exif_name_id for an exif field name
# probably called from add_exif_to_image()
# exif names and values not subject to cleaning
#	PARAMS: dbh, exif_name
#	RETURNS: exif_name_id
sub find_or_create_exif_name {
  my $dbh = shift;
  my $name = shift;

  my $find   = $dbh->prepare( $find_exif_name_statement );
  
  $find->execute( $name );
  my $result = $find->fetchall_arrayref();

  if ($result and $$result[0]) { return $$result[0][0]; }

  my $insert = $dbh->prepare( $exif_name_statement );
  $insert->execute( $name );

  # "For some drivers the $catalog, $schema, $table, and $field parameter
  # are required, for others they are ignored (e.g., mysql)"
  my $id = $dbh->last_insert_id( undef, undef, undef, undef );

  return $id;
} # end &find_or_create_exif_name 

# add a new (or find an existing) exif_value_id for an exif field value
# probably called from add_exif_to_image()
# exif names and values not subject to cleaning
#	PARAMS: dbh, exif_value
#	RETURNS: exif_value_id
sub find_or_create_exif_value {
  my $dbh = shift;
  my $value = shift;

  my $find   = $dbh->prepare( $find_exif_value_statement );
  
  $find->execute( $value );
  my $result = $find->fetchall_arrayref();

  for my $row (@$result) {
    if ($value eq $$row[1]) {
      return $$row[0];
    }
  }

  my $insert = $dbh->prepare( $exif_value_statement );
  $insert->execute( $value );

  # "For some drivers the $catalog, $schema, $table, and $field parameter
  # are required, for others they are ignored (e.g., mysql)"
  my $id = $dbh->last_insert_id( undef, undef, undef, undef );

  return $id;
} # end &find_or_create_exif_value 

# add a exif data to an image
# exif names and values not subject to cleaning
#	PARAMS: dbh, image_id, exif_name, exif_value
#	RETURNS: -
sub add_exif_to_image {
  my $dbh      = shift;
  my $image_id = shift;
  my $name     = shift;
  my $value    = shift;

  my $name_id  = find_or_create_exif_name($dbh,  $name);
  my $value_id = find_or_create_exif_value($dbh, $value);

  my $insert = $dbh->prepare( $exifother_statement );
  $insert->execute( $image_id, $name_id, $value_id );
} # end &add_exif_to_image 

# set a new date and use count on a tag
# probably called from add_tags_to_image()
#	PARAMS: dbh, tag_id, tag_use_date
#	RETURNS: -
sub update_tag_usage {
  my $dbh      = shift;
  my $tag_id   = shift;
  my $use_date = shift;

  my $sth = $dbh->prepare( $tag_update_usage_statement );
  $sth->execute($use_date, $tag_id);
} # end &update_tag_usage 

# add one or more tags (display value) to an image
#	PARAMS: dbh, image_id, tag_use_date, ref_to_tag_array
#	RETURNS: -
sub add_tags_to_image {
  my $dbh         = shift;
  my $image_id    = shift;
  my $image_date  = shift;
  my $tag_arr_ref = shift;

  my $tag_id;
  my $tag;
  my $sth = $dbh->prepare( $add_images_tags_statement );

  for $tag (@$tag_arr_ref) {
    $tag_id = find_or_create_tag($dbh, $tag);

    update_tag_usage($dbh, $tag_id, $image_date);
    $sth->execute($tag_id, $image_id);
  }
} # end &add_tags_to_image 

# add GPS location to an image
# examines gps_data to determine correct loc_type
# if in degrees minutes seconds, will also convert and add decimal
#	PARAMS: dbh, image_id, gps_data
#	RETURNS: -
sub add_location_to_image {
  my $dbh      = shift;
  my $image_id = shift;
  my $location = shift;
  my $format = 0;

  my $gps = $dbh->prepare( $location_statement );

  # format type 2, urg.
  # 40 deg 44' 55.02" N, 74 deg 0' 15.44" W
  if ($location =~ /^([-+]?\s*[\d]+[ degrs]+\d+'\s*[\d.]+"\s*[NS]?)[, ]*([-+]?\s*[\d]+[ degrs]+\d+'\s*[\d.]+"\s*[EW])\s*$/) {

    my $lat  = $1;
    my $long = $2;

    # save it before editing
    $gps->execute($image_id, 2, $location);

    $location = decimalizedegrees($lat) . ',' . decimalizedegrees($long);
  }

  if ($location =~ /^[-+]?\s*[\d.]+\s*[NS]?,\s*[-+]?\s*[\d.]+\s*[EW]\s*$/) {
    $format = 1;
  }

  # this might be a second save
  $gps->execute($image_id, $format, $location);
} # end &add_location_to_image 

# A new image for the database.
#	PARAMS: dbh, hash_reg (see example)
#	RETURNS: image_id
# Example:
#    add_image($dbh, { image_path => '/required/path/to/image',
#                      image_name => 'image',
#                      image_date => 'YYYY:MM:DD HH:MM:SS',
#                      width => 1234, height => 4321,
#                      bits => 8, components => 3,
#                      location => $gps_lat_long,
#                      tags => \@tag_array,
#                      exif => \%extra_hash,
#                    } );
#
# 'image_path' is required, everything else optional
#
# bits is per sample, not per pixel; 8 bits x 3 components = 24 bits per pixel
#      16 bits x 4 components = 64 bits per pixel
#
# exif data are in 'Exiftool name' => 'Value' format
#
# tags are display (raw), not clean
sub add_image {
  my $dbh = shift;
  my $params = shift;

  my $path     = $$params{image_path};
  my $name     = $$params{image_name};
  my $date     = ($$params{image_date} or '1973:11:03');
  my $w        = ($$params{width} or 1);
  my $h        = ($$params{height} or 1);
  my $bits     = ($$params{bits} or 8);
  my $comp     = ($$params{components} or 8);
  my $location = $$params{location};
  my $tags_r   = $$params{tags};
  my $exif_r   = $$params{exif};
  my $ename;
  my $evalue;

  if(!defined($path) or !length($path)) {
    warn "add_image: Missing image_path\n";
    return undef;
  }
  if(!defined($name) or !length($name)) {
    $name = $path;
    $name =~ s,^.*/,,;
    $name =~ s,[.][^.]*$,,;
  }

  # print STDERR "Trying insert for $name\n";  
  my $image_sth = $dbh->prepare( $images_statement );

  $image_sth->execute( $path, $name, $w, $h, $date, $comp, $bits );
  my $image_id = $dbh->last_insert_id( undef, undef, undef, undef );

  if(!defined($image_id) or $image_id < 1) { return undef; }

  if($location) { add_location_to_image($dbh, $image_id, $location); }

  if(@$tags_r) { add_tags_to_image($dbh, $image_id, $date, $tags_r); }
  
  while( ($ename, $evalue) = each (%$exif_r)) {
    # $ename likely always good, $evalue not so much
    if(defined($ename) and defined($evalue) and length($evalue)) {
      add_exif_to_image($dbh, $image_id, $ename, $evalue);
    }
  }

  $image_id;
} # end &add_image 

# get the display version of the tags for an image
#	PARAMS: dbh, image_id
#	RETURNS: tag_array_ref
sub get_tags_for_image {
  my $dbh      = shift;
  my $image_id = shift;
  my $tags_sth = $dbh->prepare( $image_tag_find_statement );

  $tags_sth->execute($image_id);
  my $result = $tags_sth->fetchall_arrayref();

  return (map { $$_[0] } @$result);
}

# get the title for an image
#	PARAMS: dbh, image_id
#	RETURNS: title
sub get_title_for_image {
  my $dbh      = shift;
  my $image_id = shift;
  my $title_sth = $dbh->prepare( $title_find_statement );

  $title_sth->execute($image_id);
  my $result = $title_sth->fetchrow_array();

  return $result;
} # end &get_title_for_image 

# get the description for an image
#	PARAMS: dbh, image_id
#	RETURNS: description
sub get_description_for_image {
  my $dbh      = shift;
  my $image_id = shift;
  my $desc_sth = $dbh->prepare( $description_find_statement );

  $desc_sth->execute($image_id);
  my $result = $desc_sth->fetchrow_array();

  return $result;
} # end &get_description_for_image 

# search clean tags by fragment return display tags ordered by most used
# intended for autocomplete during searching
#	PARAMS: dbh, frag, limit
#	RETURNS: tag_array
sub tag_fragment_search {
  my $dbh   = shift;
  my $frag  = shift;
  my $limit = shift;

  $frag = clean_tag($frag);
  my $sth = $dbh->prepare( $tag_search_statement );
  $sth->execute( "%$frag%", $limit );

  # fetchall_arrayref returns a one element array for every row
  # the map removes the inner arrays
  my $result = $sth->fetchall_arrayref();
  @tags = map { $$_[0] } @$result;
}

1;
