require 'mini_exiftool'

photo_path = '/Users/iainbryson/Pictures/2014/2014-12-06/2014-12-06 17.01.32.jpg'

photo = MiniExiftool.new photo_path

puts photo.title

puts photo['Keywords']

#photo['Keywords'] << "Blog"

photo.keywords = photo.keywords + ["Blog"]

puts photo['Keywords']

puts photo.changed?


photo.save

puts photo.errors
