ark-gallery
-----------

The purpose of this is to create a search oriented, rather
than display oriented gallery tool. I'm making it after
trying nine tools and perusing feature lists on several others.

"Ark" as in "archive", not "ark" as in Noah.

## Other projects

Tested briefly:

1. Next Cloud
   - no good tag or search support
   - no exif integration
2. Piwigo
   - does not import exif tags, does not search tags; display of them only
3. Lychee
   - Imports tag data
   - Only does free form search
   - Photo importing via web is prone to breakage, API is terrible
4. Damselfly
   - Would not function on a VM
5. HomeGallery
   - Only does free form search
   - Adding tags didn't work
   - Signs it might not scale well
6. Photoview:
   - It didn't import tags
   - Seems to have no text search at all
7. Photonix:
   - Was unable to actually import photos on VM
8. Photoprism:
   - Clear documenation of VM expectations, and knobs for adjusting CPU
     and RAM impact
   - Imports my tags as "Subject"
   - Even with AI turned off adds some extra tags as "Keywords"
   - All tags and keywords are searchable, but only does free form search
   - Does not have a date search, just grouped by month
9. Chevereto
   - Exif support turns out to mean exif-stripping for privacy
   - Limited search


Ruled out by feature list description

1. Librephoto
   - No tag support
2. Pixelfed
   - Apparently no tag support, aims to be Instagram clone
3. Media Goblin
   - No active development, seems to be more video oriented
4. PiGallery2
   - Upfront lists tags as weakness
5. PhotoStructure
   - No tag support

## Goals for this project

Intended feature list:

* Web and command line components

* Very small user list, eg under 10 totat (one or two concurrent)
  - user management out of scope for now, use basic auth + https

* Scale to hundreds of thousands of pictures

* Operate comfortably on 1 CPU / 1 GB RAM cloud machine
  - prioritize search over import

* Exact and substring tag matching

* Proper set intersection searches
  - example:
    * with tag "art" and tag "chicago" and not tag "street art"
    to get stuff in museuems in Chicago, but not the Bean

* Narrow date search (specific days / times)

* Uses existing image file system layout; expected to have
  thumbnails and medium size previews locally, originals in
  S3 or S3 compatible (with similar layout)

* Import tags, GPS, camera details, and other interesting data
  from EXIF (currently my photos have tags embedded in EXIF in
  XMP Subject field). Other interesting data probably includes:
  - lens
  - depth of field
  - capture mode
  - flash
  - orientation

* Store other metadata like my old Flickr titles, descriptions,
  set information
  - free form search of that

* Look-up GPS to place name
  - search place names
  - show photos on map to find nearby picures (map view probably not
   in first version).

* Show photos on timeline to find photos with different tags, but
  very similar capture time (timeline view probably not in first
  version)

* Search photos by camera or lens used

* Tool for finding similar photos, to help find things that have
  been resized / renamed (probably not in first version)

