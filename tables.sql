# created, database ark on begriffin.com

-- image basics: id, path, base name, date
CREATE TABLE `ark_images` (
  `image_id` int(11) NOT NULL auto_increment,
  `image_path` varchar(255) NOT NULL UNIQUE,	-- a path name with directories and suffix
  `image_name` varchar(47) NOT NULL,            -- just a base name like "flir_20220718T220825"
  `image_date` DATETIME,
  PRIMARY KEY (`image_id`),
  INDEX (`image_path`),
  INDEX (`image_name`),
  INDEX (`image_date`)
);

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
  `tag_id` int(11) NOT NULL auto_increment,
  `tag` varchar(127) character set utf8mb4 COLLATE utf8mb4_unicode_ci,
  `tag_clean` varchar(127) character set utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`tag_id`),
  INDEX (`tag_clean`)
);
ALTER TABLE `ark_tags` 
  ADD `uses` int(11) default 1 AFTER `tag_id`,
  ADD `last` DATETIME default NULL AFTER `uses`;

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
  `exif_name` varchar(63) character set utf8mb4 COLLATE utf8mb4_unicode_ci default NULL,
  `exif_value` varchar(63) character set utf8mb4 COLLATE utf8mb4_unicode_ci default NULL,
  INDEX (`image_id`),
  INDEX (`exif_name`),
  INDEX (`exif_value`)
);

