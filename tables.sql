
-- image basics: id, path, base name, date
CREATE TABLE `ark_images` (
  `image_id` int(11) NOT NULL AUTO_INCREMENT,
  `width` int(11) DEFAULT '0',
  `height` int(11) DEFAULT '0',
  `image_path` varchar(255) NOT NULL,
  `image_name` varchar(47) NOT NULL,
  `image_date` datetime DEFAULT NULL,
  `components` tinyint(4) DEFAULT '3',
  `bits` tinyint(4) DEFAULT '8',
  PRIMARY KEY (`image_id`),
  UNIQUE KEY `image_path` (`image_path`),
  KEY `image_path_2` (`image_path`),
  KEY `image_name` (`image_name`),
  KEY `image_date` (`image_date`)
)

-- find image ids associated with tag ids (tag search mode)
-- find tag ids associated with image ids (image display)
CREATE TABLE `ark_images_tags` (
  `tag_id` int(11) NOT NULL default 0,
  `image_id` int(11),
  INDEX (`tag_id`),
  INDEX (`image_id`)
);

-- for any tag, there's a tag id
-- tag is for display, tag_clean is for match
CREATE TABLE `ark_tags` (
  `tag_id` int(11) NOT NULL AUTO_INCREMENT,
  `uses` int(11) DEFAULT '0',
  `last` datetime DEFAULT NULL,
  `tag` varchar(127) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tag_clean` varchar(127) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`tag_id`),
  KEY `tag_clean` (`tag_clean`)
)

-- Some images have titles
CREATE TABLE `ark_title` (
  `image_id` int(11) NOT NULL default 0,
  `title` varchar(255) character set utf8mb4 COLLATE utf8mb4_unicode_ci default NULL,
  PRIMARY KEY (`image_id`),
  INDEX (`title`)
);

-- Some images have descriptions (2^12 - 2 for two byte pascal string length)
-- note FULLTEXT index uses stop words
CREATE TABLE `ark_description` (
  `image_id` int(11) NOT NULL default 0,
  `description` varchar(4094) character set utf8mb4 COLLATE utf8mb4_unicode_ci default NULL,
  PRIMARY KEY (`image_id`),
  FULLTEXT imgdesc (`description`)
);

-- Some images have GPS data
CREATE TABLE `ark_location` (
  `image_id` int(11) NOT NULL default 0,
  -- catchall					type 0
  -- 40.748616 N,74.004289 W			type 1
  -- 40 deg 44' 55.02" N, 74 deg 0' 15.44" W	type 2
  `loc_type` TINYINT NOT NULL default 0,
  `location` varchar(63) character set utf8mb4 COLLATE utf8mb4_unicode_ci default NULL,
  -- image_id, loc_type must be a unique pair
  PRIMARY KEY (`image_id`,`loc_type`),
  INDEX (`location`)
);

-- camera, depth of field, capture mode, or other data to save
CREATE TABLE `ark_exif_other` (
  `image_id` int(11) NOT NULL default 0,
  `exif_name_id` int(11),
  `exif_value_id` int(11),
  INDEX (`image_id`),
  INDEX (`exif_name_id`),
  INDEX (`exif_value_id`)
);

CREATE TABLE `ark_exif_names` (
  `exif_name_id` int(11) NOT NULL auto_increment,
  `exif_name` varchar(63) character set utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL UNIQUE,
  PRIMARY KEY (`exif_name_id`),
  INDEX (`exif_name`)
);

CREATE TABLE `ark_exif_values` (
  `exif_value_id` int(11) NOT NULL auto_increment,
  `exif_value` varchar(63) character set utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`exif_value_id`),
  FULLTEXT exiftext (`exif_value`)
);

