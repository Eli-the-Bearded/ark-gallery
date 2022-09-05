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
	$ark_title_statement
	$ark_description_statement
	$ark_exifother_statement
	$ark_location_statement
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
$ark_img_statement =
	'INSERT INTO `ark_images` (`image_path`,`image_name`,`image_date`)
	 VALUES (?, ?, ?); ';

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
1;
