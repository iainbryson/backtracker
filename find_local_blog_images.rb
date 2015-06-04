require 'find'
require 'json'
require 'uri'
require 'sqlite3'
require 'exifr'

require 'phashion'

require 'optparse'
require 'yaml'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-tag', '--tagname NAME', 'Tag name') { |v| options[:tag_name] = v }
  opts.on('-root', '--root NAME', 'Root folder name') { |v| options[:root] = v }
end.parse!

#dest_options = YAML.load_file('destination_config.yaml')
#puts dest_options['dest_name']

total_size = 0

$img_map = {};
$tag_name = options[:tag_name]


def mapPath(root, db)
#    img_map = {}

    scaled_re = /.*[0-9]{2,4}x[0-9]{2,4}\.jpg/i

    print "Searching in #{root}...\n"

    Find.find(root) do |path|
      if FileTest.directory?(path)
        if File.basename(path)[0] == '.'
          Find.prune       # Don't look any further into this directory.
        else
          next
        end
      elsif File.extname(path) =~ /.*\.jpg/i then
      
        if $existing_paths.has_key?(path) then
            print "#{path} already in DB\n"
            next
        end
        
        img_base = File.basename(path)

        if img_base =~ scaled_re then
            print "#{path} is a thumbnail\n"
            img
        end

        size = FileTest.size(path)
        created_time = File.ctime(path)

    
        img_base = img_base.gsub(/^(wpid)?-/,"")
        
        img_base = img_base.sub( /(.*)\d\.jpg/, '\1.jpg' )
      
        fingerprint = Phashion::Image.new(path).fingerprint
      

        #img_map["#{base}#{size}"] = path
        $img_map["#{img_base}"] = path
        print("#{path} #{img_base}\n")
        
        gps = nil
            begin
            exif = EXIFR::JPEG.new(path)
            if exif && exif.exif? && exif.exif.gps then
            
                created_time = exif.exif.date_time_original || exif.exif.date_time || created_time;
                gps = {
                                :latitude        => exif.exif.gps.latitude,
                                :longitude       => exif.exif.gps.longitude,
                                :altitude        => exif.exif.gps.altitude,
                                :image_direction => exif.exif.gps.image_direction
                             }.to_json
            end
        rescue
        end

#WHERE NOT EXISTS (SELECT 1 FROM Images WHERE )        
        if db then db.execute("INSERT INTO Images VALUES(?, ?, ?, datetime(?, 'unixepoch'), ?, ?, ?) ", [path, img_base, size, 
#        created_time.strftime("%Y %m %d %H %M %S")
        created_time.to_time.to_i,
        gps,
        $tag_name,
        fingerprint
        ]) end
        
      end
    end
end

require 'sqlite3'

begin
    
    db = SQLite3::Database.open "test.db"
    db.execute "CREATE TABLE IF NOT EXISTS Images(
        Path  TEXT PRIMARY KEY,
        BaseName TEXT,
        Size INT,
        Created DATETIME,
        GpsJson TEXT,
        Tag TEXT,
        PerceptualHash BigInt
    )"

    rows = db.execute( "select Path from Images")
    
    $existing_paths = {}
    
    rows.each do |row|
        $existing_paths[row[0]] = true
    end

# ruby find_local_blog_images.rb -t local -r /Users/iainbryson/Pictures/iPhoto\ Library.migratedphotolibrary/Masters/
# ruby find_local_blog_images.rb -t local -r /Users/iainbryson/Pictures/2014
# ruby find_local_blog_images.rb -t local -r /Users/iainbryson/Pictures/2015
# ruby find_local_blog_images.rb -t local -r /Users/iainbryson/OneDrive
# ruby find_local_blog_images.rb -t blog -r /Users/iainbryson/Documents/bts/castawaylife_backup/
    mapPath(options[:root], db)

rescue SQLite3::Exception => e 
    
    puts "Exception occurred"
    puts e
    
ensure
    db.close if db
end


