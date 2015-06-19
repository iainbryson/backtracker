# backtracker
Examine all posts from a WordPress blog for geographical data and generate some interesting visualizations of the journey.

## Scripts

'backtracker.rb' loads all the posts from the WordPress site and extracts the EXIF data, most importantly the GPS data, for each image in each post.  It produces a JSON file containing the mapping between post and location along with the list of image urls.

'find_local_blog_images.rb' recurses through a (local) directory tree looking at each JPEG.  For each image, it extracts the base name, EXIF data (GPS and create date) and perceptual hash using [phash][phash].  It puts all this information into a local sqlite database.

'find_missing_gps_info.rb' loads the markers.js JSON file produced by 'backtracker.rb' and joins it with the information in the database provided by 'find_local_blog_images.rb'.  It works to find local versions of the remote blog images based on name, creation date and perceptural hash.  It matches as many as possible and puts out a new json file with the improved GPS information.

'render-posts.html' loads in the JSON markers data and creates markers on a google map.

### Order

'''
ruby backtracker.rb --endpost 76| tee out


ruby backtracker.rb | tee out
ruby -r pry find_missing_gps_info.rb | tee out3
bundler exec ruby -v generate-hierarchical-markers.rb | tee out4
'''

[phash]:


### NOTES


#### Manually generate gps info for static markers file 

'''ruby
require 'json'
require 'exifr'

def pbcopy(input)
 str = input.to_s
 IO.popen('pbcopy', 'w') { |f| f << str }
 str
end

file = '/Users/iainbryson/Pictures/2014/2014-12-06/IMG_1785.JPG'
exif = EXIFR::JPEG.new(file)
j = {  :gps => {
    :latitude        => exif.exif.gps.latitude,
    :longitude       => exif.exif.gps.longitude,
    :altitude        => exif.exif.gps.altitude,
    :image_direction => exif.exif.gps.image_direction
 } }
pbcopy JSON.pretty_generate(j)
j.to_json
#https://stackoverflow.com/questions/4229571/how-do-you-save-irb-inputs-to-a-rb-file
File.open("irb.log", "w") do |f|
    f << Readline::HISTORY.to_a.join("\n")
end
'''
