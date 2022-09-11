use vars qw(
	$dbuser $dbhost $dbpass $dbport $database
	$rc
	$ark_tags_statement
	$ark_tag_search_statement
	$ark_tag_recent_statement
	$ark_tag_find_statement
	$ark_add_images_tags
	$ark_tag_update_usage
	$ark_image_tag_find_statement
	$ark_tag_most_statement
	$ark_img_statement
	$ark_images_statement
	$ark_title_statement
	$ark_description_statement
	$ark_exifother_statement
	$ark_location_statement
	$ark_exif_name_statement
	$ark_exif_value_statement
	$ark_find_exif_name
	$ark_find_exif_value
	$ark_exifother_statement
);

$rc = do '/home/eli/photo-gallery/.creds.pm';

if(!defined($rc)) { die "Failed to load creds file\n"; }

# create a new tag; tag must be unique, tag_clean can be duped
$ark_tags_statement = 
       'INSERT INTO `ark_tags` (`tag`, `tag_clean`)
	VALUES (?, ?); ';

# search for tags by fragment (for autocomplete)
$ark_tag_search_statement = 
       'SELECT `tag` FROM `ark_tags`
       	WHERE `tag_clean` LIKE ? 
	ORDER BY `uses` DESC LIMIT ?; ';

# search tags for most recently used (for suggesting tags to add)
$ark_tag_recent_statement = 
       'SELECT `tag` FROM `ark_tags`
	ORDER BY `last` DESC LIMIT ?; ';

# search tags for most used (for suggesting tags to add)
$ark_tag_most_statement = qq!
        SELECT `tag` FROM `ark_tags`
        WHERE `tag_clean` NOT LIKE '\_%'
	ORDER BY `used` DESC LIMIT ?; !;

# find display version of tags exactly matching tag_clean
$ark_tag_find_statement = 
       'SELECT `tag_id`, `tag` FROM `ark_tags` WHERE `tag_clean` = ?; ';

# find display versions of tags for a particular image_id
#$ark_image_tag_find_statement = '
#	SELECT `tag` FROM `ark_tags` WHERE `tag_id` IN
#	   (SELECT `tag_id` FROM `ark_images_tags`
#	     WHERE `ark_images_tags`.`image_id` = ?) ' ;

$ark_image_tag_find_statement = '
	SELECT t.`tag` FROM `ark_tags` t
	INNER JOIN `ark_images_tags` i ON t.`tag_id` = i.`tag_id`
	WHERE i.`image_id` = ?; ';

# update tag last used date and use count
$ark_tag_update_usage = '
	UPDATE `ark_tags`
	   SET `uses` = `uses` + 1, `last` = ?
	   WHERE `tag_id` = ?; ';

# associate a tag with an image
$ark_add_images_tags = '
	INSERT INTO `ark_images_tags` VALUES (?, ?); ';

# create a new image; image_path must be unique; 1973:11:03 used for nodate
# minimal version
$ark_img_statement =
	'INSERT INTO `ark_images` (`image_path`,`image_name`,`image_date`)
	 VALUES (?, ?, ?); ';

# create a new image; image_path must be unique; 1973:11:03 used for nodate
# complete version
$ark_images_statement = '
	INSERT INTO `ark_images`
	(`image_path`, `image_name`, `width`, `height`,
	 `image_date`, `components`, `bits`)
	VALUES ( ?, ?, ?, ?, ?, ?, ? );
	';

# insert a new title
$ark_title_statement = 
	' INSERT INTO `ark_title` VALUES (?, ?); ';

# insert a new description
$ark_description_statement = 
	' INSERT INTO `ark_description` VALUES (?, ?); ';

# insert a new EXIF extra metadata field
$ark_exifother_statement = 
	' INSERT INTO `ark_exif_other` VALUES (?, ?, ?); ';

# insert a new location record
# image_id, loc_type, location
#    type 0   default catchall 
#    type 1   40.748616 N,74.004289 W
#    type 2   40 deg 44' 55.02" N, 74 deg 0' 15.44" W
#    type 3   40.748616,-74.004289
$ark_location_statement =
	' INSERT INTO `ark_location` VALUES (?, ?, ?); ';

$ark_exif_name_statement = '
        INSERT INTO `ark_exif_names` (`exif_name`) VALUES (?);
        ';

$ark_exif_value_statement = '
        INSERT INTO `ark_exif_values` (`exif_value`) VALUES (?);
        ';

$ark_find_exif_name = '
        SELECT `exif_name_id` FROM `ark_exif_names` WHERE `exif_name` = ?;
        ';

$ark_find_exif_value = '
        SELECT `exif_value_id` FROM `ark_exif_values` WHERE `exif_value` = ?;
        ';

$ark_exifother_statement = '
        INSERT INTO `ark_exif_other`
                (`image_id`, `exif_name_id`, `exif_value_id`)
                VALUES (?, ?, ?);
        ';

sub dbconnect {
  $_ = DBI->connect(
	"dbi:mysql:database=$database",
	$dbuser, $dbpass
  ) ||
  die "Can't connect to mysql $database database: $DBI::errstr\n";

  $_;
}

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
} # &clean_tag

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
}

# return a tag_id for an existing or new tag
sub find_or_create_tag {
  my $dbh = shift;
  my $tag = shift;

  my $clean = clean_tag( $tag );
  my $find   = $dbh->prepare( $ark_tag_find_statement );
  
  $find->execute( $clean );
  my $result = $find->fetchall_arrayref();

  for my $row (@$result) {
    if ($tag eq $$row[1]) {
      return $$row[0];
    }
  }

  my $insert = $dbh->prepare( $ark_tags_statement );
  $insert->execute( $tag, $clean );

  # "For some drivers the $catalog, $schema, $table, and $field parameter
  # are required, for others they are ignored (e.g., mysql)"
  my $id = $dbh->last_insert_id( undef, undef, undef, undef );

  return $id;
}

# return a exif_name_id for an existing or new exif field
sub find_or_create_exif_name {
  my $dbh = shift;
  my $name = shift;

  my $find   = $dbh->prepare( $ark_find_exif_name );
  
  $find->execute( $name );
  my $result = $find->fetchall_arrayref();

  if ($result and $$result[0]) { return $$result[0][0]; }

  my $insert = $dbh->prepare( $ark_exif_name_statement );
  $insert->execute( $name );

  # "For some drivers the $catalog, $schema, $table, and $field parameter
  # are required, for others they are ignored (e.g., mysql)"
  my $id = $dbh->last_insert_id( undef, undef, undef, undef );

  return $id;
}

# return a exif_value_id for an existing or new exif value
sub find_or_create_exif_value {
  my $dbh = shift;
  my $value = shift;

  my $find   = $dbh->prepare( $ark_find_exif_value );
  
  $find->execute( $value );
  my $result = $find->fetchall_arrayref();

  for my $row (@$result) {
    if ($value eq $$row[1]) {
      return $$row[0];
    }
  }

  my $insert = $dbh->prepare( $ark_exif_value_statement );
  $insert->execute( $value );

  # "For some drivers the $catalog, $schema, $table, and $field parameter
  # are required, for others they are ignored (e.g., mysql)"
  my $id = $dbh->last_insert_id( undef, undef, undef, undef );

  return $id;
}

sub add_exif_to_image {
  my $dbh      = shift;
  my $image_id = shift;
  my $name     = shift;
  my $value    = shift;

  my $name_id  = find_or_create_exif_name($dbh,  $name);
  my $value_id = find_or_create_exif_value($dbh, $value);

  my $insert = $dbh->prepare( $ark_exifother_statement );
  $insert->execute( $image_id, $name_id, $value_id );
}

# set a new date and use count on a tag
sub update_tag_usage {
  my $dbh      = shift;
  my $tag_id   = shift;
  my $use_date = shift;

  my $sth = $dbh->prepare( $ark_tag_update_usage );
  $sth->execute($use_date, $tag_id);
}

sub add_tags_to_image {
  my $dbh         = shift;
  my $image_id    = shift;
  my $image_date  = shift;
  my $tag_arr_ref = shift;

  my $tag_id;
  my $tag;
  my $sth = $dbh->prepare( $ark_add_images_tags );

  for $tag (@$tag_arr_ref) {
    $tag_id = find_or_create_tag($dbh, $tag);

    update_tag_usage($dbh, $tag_id, $image_date);
    $sth->execute($tag_id, $image_id);
  }
}

sub add_location_to_image {
  my $dbh      = shift;
  my $image_id = shift;
  my $location = shift;
  my $format = 0;

  my $gps = $dbh->prepare( $ark_location_statement );

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
}

# A new image for the database.
#    add_image($dbh, { image_path => '/required/path/to/image',
#                      image_name => 'image',
#                      image_date => 'YYYY:MM:DD HH:MM:SS',
#                      width => 1234, height => 4321,
#                      bits => 8, components => 3,
#                      location => $gps_lat_long,
#                      tags => \@tag_array,
#                      exif => \%extra_hash,
#                    }
# 'image_path' is required, everything else optional
# bits is per sample, not per pixel; 8 bits x 3 components = 24 bits per pixel
#      16 bits x 4 components = 64 bits per pixel
# exif data are in 'Exiftool name' => 'Value' format
# tags are raw, not clean
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

  if(!defined($path) or !length($path)) {
    warn "add_image: Missing image_path\n";
    return undef;
  }
  if(!defined($name) or !length($name)) {
    $name = $path;
    $name =~ s,^.*/,,;
    $name =~ s,[.][^.]*$,,;
  }

print STDERR "Trying insert for $name\n";  
  my $image_sth = $dbh->prepare( $ark_images_statement );

  $image_sth->execute( $path, $name, $w, $h, $date, $comp, $bits );
  my $image_id = $dbh->last_insert_id( undef, undef, undef, undef );

  if(!defined($image_id) or $image_id < 1) { return undef; }
print STDERR "Worked for $name have $image_id\n";  

  if($location) { add_location_to_image($dbh, $image_id, $location); }

  if(@$tags_r) { add_tags_to_image($dbh, $image_id, $date, $tags_r); }
  
  my $name; my $value;
  while( ($name, $value) = each (%$exif_r)) {
    # $name likely always good, $value not so much
    if(defined($name) and defined($value) and length($value)) {
      add_exif_to_image($dbh, $image_id, $name, $value);
    }
  }

  $image_id;
}

1;
