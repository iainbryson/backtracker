require 'find'
require 'json'
require 'uri'
require 'time'
require 'pp'
require 'geocoder'
require 'dbscan'
require 'pry'
require 'pry-rescue'
require 'active_support'

Geocoder.configure(:units => :km)

$distanceMultiplier = 1.0


class ActiveSupport::TimeWithZone
  def as_json(options = {})
    strftime('%Y/%m/%d %H:%M:%S %z')
  end
end

class Array
    def haversine_distance2(n)
        Geocoder::Calculations::distance_between( self, n )
    end
    def spacio_temporal_distance(n)
        $distanceMultiplier * Geocoder::Calculations::distance_between( self[0..1], n[0..1] ) + 10.0 * (self[2] - n[2] ).abs / (60*60*24)
    end
end

def mean(array)
    array.inject(0) { |sum, x| sum += x } / array.size.to_f
end

def median(array, already_sorted=false)
    return nil if array.empty?
    array = array.sort unless already_sorted
    m_pos = array.size / 2
    return array.size % 2 == 1 ? array[m_pos] : mean(array[m_pos-1..m_pos])
end

# bundler exec ruby generate-hierarchical-markers.rb

file = File.read('markers2.js')
file_json = file[(file.index('[')-1)..(file.rindex(']'))].strip
markers = JSON.parse(file_json)

file = File.read('markers_static.js')
file_json = file[(file.index('[')-1)..(file.rindex(']'))].strip
markers = markers + JSON.parse(file_json)


markers_with_gps = markers.select{ |m| m.has_key?('gps') && m['gps']  && m['date_time']}

markers_with_gps.each do |m|
    m['date_time'] = Time.parse(m['date_time'])
end

min_date = markers_with_gps.map{|m| m['date_time']}.min

pp min_date
#g = Geocoder.search(markers[0]['gps']['latitude'].to_s + ', ' + markers[0]['gps']['longitude'].to_s)

def reverseGeocode(markers_with_gps)
    markers_with_gps[1..5].each do |m|
        gps = m['gps']
        g = Geocoder.search(gps['latitude'].to_s + ', ' + gps['longitude'].to_s)
    
        m['country'] = g[0].country
        m['state'] = g[0].state
        m['sub_state'] = g[0].sub_state
        m['city'] = g[0].city
    end
end

    
def generateClusters( eps, markers_with_gps, min_date )

    input = markers_with_gps.map{|m| [m['gps']['latitude'], m['gps']['longitude'], m['date_time'] - min_date, m]}
    
    dbscan = DBSCAN( input, :epsilon => eps, :min_points => 1, :distance => :spacio_temporal_distance )

#    binding.pry
    
    new_markers = 
    dbscan.clusters.select{|x| x != -1}.map do |index, c|
        puts "cluster #{index}:\n"
        
        pp c
        
        center = Geocoder::Calculations.geographic_center(c.map{|p| p.items[0..1]})
        center_day = min_date + median(c.map{|p| p.items[2]})

        g = []
        while g.length == 0 do
            g = Geocoder.search(center)
            sleep 20 if (g.length == 0)
        end
    
        {
            cluster_no: index,
            day: center_day,
            gps: {longitude: center[1], latitude: center[0]},
            markers: c.map{|p| p.items[3]},
            country: g[0].country,
            state: g[0].state,
            sub_state: g[0].sub_state,
            city: g[0].city
        }
    end.select{|x| x != nil}

    new_markers = new_markers + dbscan.clusters.select{|x| x == -1}[-1].map do |i|
        m = i.items[3]
        gps = m['gps']

        g = []
        while g.length == 0 do
            g = Geocoder.search(gps['latitude'].to_s + ', ' + gps['longitude'].to_s)
            sleep 20 if (g.length == 0)
        end
    
        {
            cluster_no: -1,
            day: m['date_time'],
            gps: gps,
            markers: [m],
            country: g[0].country,
            state: g[0].state,
            sub_state: g[0].sub_state,
            city: g[0].city
        }
    end.select{|x| x != nil}

    new_markers.sort!{|l,r| l[:day].to_i <=> r[:day].to_i}
    
    pp "sorted dates\n"
    pp new_markers.map{|x| x[:day]}
    
    new_markers
end

new_markers = []

Pry.rescue do
    new_markers << {zoom: [0, 4], markers: generateClusters(  600, markers_with_gps, min_date) }
    $distanceMultiplier = 10.0
    new_markers << {zoom: [5, 8], markers: generateClusters(  600, markers_with_gps, min_date) }

    new_markers << {zoom: [9,16], markers: markers_with_gps.map{|m|
            {
            cluster_no: -1,
            day:       m['date_time'],
            gps:       m['gps'],
            markers:   [m],
            country:   nil,
            state:     nil,
            sub_state: nil,
            city:      nil
        }
    }.sort!{|l,r| l[:day].to_i <=> r[:day].to_i} }
end

File.open('hierarchical_markers.js', 'w') { |file| file.write("var marker_data = "+JSON.pretty_generate(new_markers) + ";\n") }

File.open('hierarchical-markers.json', 'w') { |file| file.write( new_markers.to_json ) }
