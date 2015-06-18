require 'find'
require 'json'
require 'uri'
require 'sqlite3'
require 'exifr'
require 'time'
require 'plist'
require 'pp'
require 'phashion'
require 'pry-rescue'
require 'geocoder'

plist_file = '/Users/iainbryson/Library/Application Support/MarsEdit/UploadedFiles/Info.plist'

file = File.read('markers.js')
file_json = file[(file.index('['))..(file.rindex(']'))].strip
markers = JSON.parse(file_json)

plist = Plist::parse_xml(plist_file)

$filemap = {}

plist["Files"].each do |file|
    $filemap[URI(file["url"]).path] = file["originalFilepath"]
end

print("examininging #{markers.length} markers...\n")

found_by_name_and_size = 0
not_found = 0
found_by_create_date = 0
found_by_marsedit_map = 0
found_by_perceptual_hash = 0
already_had_gps = 0
found_gps = 0
total = 0
found_created = 0


markers.each do |marker|
    marker["images"].each do |image|
        if image["gps"] then
            marker["gps"] = image["gps"]
            break
        end
    end
end

posts_with_gps_count = {before: markers.select{|x| x['gps']}.length, after: 0}
#Pry.rescue do

begin

    db = SQLite3::Database.open "test.db"

    rows = db.execute( "select Path, PerceptualHash, GpsJson, Created from Images WHERE Tag = 'local' COLLATE NOCASE")
    phashes = rows.map {|row| { path: row[0], phash: row[1], gps: row[2], created: row[3] } }

    markers.each do |marker|

        marker["images"].each do |image|

            found = 0
            total = total + 1
        
            found_locals = []

            uri = URI(image["image"])

            size = image["image_size"]

            created = image["date_time"] ? Time.parse(image["date_time"]) : nil

            img_base = File.basename(uri.path)

            img_base_stripped = File.basename(img_base).gsub(/^(wpid)?-/,"")
    
            img_base_stripped = img_base_stripped.sub( /(.*)\d\.jpg/, '\1.jpg' )
    
            if image["gps"] then
                already_had_gps = already_had_gps + 1
                found = found + 1
            end
        
            rows = db.execute( "select * from Images where (Path LIKE :basename OR BaseName = :stripped_basename) AND Tag = 'blog' COLLATE NOCASE",
              "basename" => "%"+img_base,
              "stripped_basename" => img_base_stripped
              #, "size" => size
              )

            if rows.length == 0 then
                print ("#{img_base} #{created}: not found in DB!\n")
            else
                phash = Integer(rows[0][6])
            
                phash_matches = phashes.select{ |p| Phashion.hamming_distance(phash, p[:phash]) < 8 }
            
                if phash_matches.length == 0 then
                    print ("#{img_base} #{created}: no perceptual hash matches!\n")
                else
                    found_by_perceptual_hash = found_by_perceptual_hash + 1
                    phash_matches.each do |row| found_locals << { path:  row[:path], gps:  row[:gps], date_time: Time.parse(row[:created]), found_by:  "hash" } end
                end
            end

            rows = db.execute( "select * from Images where (Path LIKE :basename) AND Tag = 'local' COLLATE NOCASE",
              "basename" => "%"+img_base
              #, "size" => size
              )
      
            if rows.length > 0 then
                print ("#{img_base_stripped}: found by name and size #{uri} at #{rows[0]}\n")
                found_by_name_and_size = found_by_name_and_size + 1
                rows.each do |row| found_locals << { path:  row[0], gps: row[4], date_time: Time.parse(row[3]), found_by:  "name" } end
            end
        
            if  created then
                rows = db.execute( "select * from Images where  Created =  datetime(:created, 'unixepoch')  AND Tag = 'local' COLLATE NOCASE",
                  "created" => created.to_time.to_i
                  #, "size" => size
                  )
            end
            if rows.length > 0 then
                print ("#{img_base_stripped}: found by create date #{uri} at #{rows[0]}\n")
                found_by_create_date = found_by_create_date + 1
                rows.each do |row| found_locals << { path:  row[0], gps: row[4], date_time: created, found_by:  "date" } end
            end

    
            if $filemap.has_key?(uri.to_s) then
                local_path = $filemap[uri.to_s]
                print ("#{img_base_stripped}: found by marsedit map data #{uri} at #{local_path}\n")
                found_by_marsedit_map = found_by_marsedit_map + 1
            
                rows = db.execute( "select * from Images where (Path LIKE :basename OR BaseName = :stripped_basename) AND Tag = 'blog' COLLATE NOCASE",
                  "basename" => "%"+File.basename(local_path),
                  "stripped_basename" => File.basename(local_path)
                  #, "size" => size
                  )
                gps = NIL
                gps = rows[0][4] if rows.length > 0
                created = rows[0][3] if rows.length > 0
                found_locals << { path:  local_path, gps:  gps, date_time: created, found_by:  "marsedit_map" }
            end
        
            found_locals.each do |l|
                print("\t#{l}\n")
            end
        
            gps = found_locals.select{ |l| l[:gps].to_s.strip.length != 0 && l[:date_time] }
            if gps.length > 0  then
                found_gps = found_gps + 1
                coords = gps.map{|p| g = JSON.parse(p[:gps]); [g['latitude'], g['longitude']] }
                pp coords
                center = Geocoder::Calculations.geographic_center(coords)
                #center = gps[0][:gps]
                if !marker["gps"] then
                    marker["gps"] = {latitude: center[0], longitude: center[1]}
                end
                print("FOUND GPS!\n")
            
                created_sorted = gps.sort{|l,r| l[:date_time] <=> r[:date_time] }
                pp created_sorted.map{ |l| l[:date_time] }
                found_created = found_created + 1
                if !marker["date_time"] then
                    marker["date_time"] = (created_sorted[0][:date_time])
                end
                print("FOUND CREATE TIME\n")
            end

            next if found_locals.length > 0

            print ("#{img_base_stripped} #{created}: not found\n")
            not_found = not_found + 1

        end

    end

rescue SQLite3::Exception => e 
    
    puts "Exception occurred"
    puts e
    
ensure
    db.close if db
end

#end # rescue

posts_with_gps_count[:after] = markers.select{|x| x['gps']}.length
markers_no_gps = (markers.select{|d| !d["gps"]})


puts "Images already having GPS #{already_had_gps}\n"
puts "Images found by create date: #{found_by_create_date}\n"
puts "Images found by MarsEdit map: #{found_by_marsedit_map}\n"
puts "Images found by name and size: #{found_by_name_and_size}\n"
puts "Images found by perceptual hash #{found_by_perceptual_hash}\n"
puts "Images having GPS totals:\n"
puts "\talready had it: #{already_had_gps}\n"
puts "\tfound it locally: #{found_gps}\n"
puts "\tdidn't find it: #{total - found_gps - already_had_gps}"
puts "Posts having GPS totals:\n"
puts "\talready had it: #{posts_with_gps_count[:before]}\n"
puts "\tfound it locally: #{posts_with_gps_count[:after]}\n"
puts "\tfinal count without: #{markers_no_gps.length}\n"

puts "\nList of posts without GPS info:"
markers_no_gps.each do |m|
    print "\t#{m['post']}\n"
end

File.open('markers2.js', 'w') { |file| file.write("var markers = "+JSON.pretty_generate(markers) + ";\n") }

