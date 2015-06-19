require 'find'
require 'json'
require 'uri'
require 'time'
require 'pp'
require 'geocoder'
require 'pry'
require 'pry-rescue'


file = File.read('markers2.js')
file_json = file[(file.index('[')-1)..(file.rindex(']'))].strip
markers = JSON.parse(file_json)

markers_without_gps = markers.select{ |m| (!m.has_key?('gps') && !m['gps']) || !m['date_time']}

File.open('markers_unknown.js', 'w') { |file| file.write("var markers = "+JSON.pretty_generate(markers_without_gps) + ";\n") }

