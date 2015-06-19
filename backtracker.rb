require 'rubypress'
require 'nokogiri'
require 'uri'
require 'net/http'
require 'tempfile'
require 'exifr'
require 'json'
require 'pp'
require './wordpress_creds.rb'
require 'optparse'
require 'yaml'

options = { start_post:0, end_post:-1 }
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on('-start', '--startpost NUMBER', 'Starting post number') { |v| options[:start_post] = v.to_i }
  opts.on('-end', '--endpost NUMBER', 'Ending post number') { |v| options[:end_post] = v.to_i }
end.parse!

wp = Rubypress::Client.new(WPCreds::wordpress_creds)

start = options[:start_post]
step = 10

markers = []

exif = nil

while options[:end_post] < 0 || start <= options[:end_post] do

    step = (start + step > options[:end_post] ? options[:end_post]-start : step) if options[:end_post] > 0;

    print "start #{start} step #{step} end #{options[:end_post]}]\n"

    posts = wp.getPosts( {
              :filter => {
                  :post_type => 'post',
                  :post_status => 'publish',
                  :orderby => 'post_date',
                  :order => 'asc',
                  :offset => start,
                  :number => step
            } } )

    start = start + step

    break if posts.length == 0;

    posts.each do |post|

        pp post
        print "Title: #{post['post_title']}\n"
        print "Link:  #{post['link']}\n"
        print "id:    #{post['post_id']}\n"
        # https://stackoverflow.com/questions/5813446/extract-img-tags-in-ruby
        content = Nokogiri::HTML(post["post_content"])

        post_date = Time.new(post['post_date'].year, post['post_date'].month, post['post_date'].day, post['post_date'].hour, post['post_date'].min)

        marker = { :post => post['link'],
                   :title => post['post_title'],
                   :post_date => post_date,
                   :date_time => nil,
                   :gps => nil
                 }
                   
        images = []

        img_srcs = content.css('img').map{ |i| i['src'] }

        img_srcs.each do |img_src|

            ext = File::extname(img_src)
    
            next if ext.upcase != '.JPG'

            # Lengthy regex here is because of URI's with spaces: https://stackoverflow.com/questions/1805761/check-if-url-is-valid-ruby
            next if !(img_src =~ URI::DEFAULT_PARSER.regexp[:ABS_URI]);

            # https://stackoverflow.com/questions/587559/how-to-make-an-http-get-with-modified-headers
    
            size = 1024*128 # 128 kb should be enough for the header
            uri = URI(img_src)
            http = Net::HTTP.new(uri.host, uri.port)
            headers = {
                'Range' => "bytes=0-#{size}"
            }
            path = uri.path.empty? ? "/" : uri.path

            # test to ensure that the request will be valid - first get the head
            head = http.head(path, headers)

            code = head.code.to_i
            if (code >= 200 && code < 300) then

                image_size = head["content-length"]
                content_range = head["content-range"]
                if content_range then
                    image_size = head["content-range"].gsub(/(.*\/)/,"").to_i
                end

                print "Getting #{img_src}\n"
                file = Tempfile.new(['exif', File::extname(path)])
                begin
                    #the data is available...
                    total_size = 0;
                    http.get(uri.path, headers) do |chunk|
                        total_size = total_size + chunk.length
                        file.write(chunk)
                        #print "Got #{chunk.length} total #{total_size}\n"
                        #provided the data is good, print it...
                        #print chunk unless chunk =~ />416.+Range/
                    end
                    print "Got total #{total_size} #{image_size}\n"
                
                    image = { :image => path, :image_size => image_size }
                    file.rewind()
                    exif = EXIFR::JPEG.new(file)
                    if exif.exif then
                        print "Got exif\n"
                        pp exif.exif
                        
                        image_date_time = exif.exif.date_time_original || exif.exif.date_time
                        image.merge!({  :date_time => image_date_time
                                     }  )
                        if image_date_time then marker['date_time'] = image_date_time; end
                        if exif.exif.gps then
                        
                            image.merge!({  :gps => {
                                            :latitude        => exif.exif.gps.latitude,
                                            :longitude       => exif.exif.gps.longitude,
                                            :altitude        => exif.exif.gps.altitude,
                                            :image_direction => exif.exif.gps.image_direction
                                         } } )
                            marker['gps'] = image['gps']
                        end
                    end
                    
                    images << image
                    
                    if (image.has_key?("gps")) then break; end
                ensure
                   file.close
                   file.unlink   # deletes the temp file
                end
            end
            
        end
        marker['images'] = images
        markers << marker
    end
end

File.open('markers.js', 'w') { |file| file.write("var markers = "+JSON.pretty_generate(markers) + ";\n") }

