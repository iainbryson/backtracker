require 'Ox'
require 'plist'
#require 'nokogiri-plist'

plist = nil
plist_file = '/Users/iainbryson/Library/Application Support/MarsEdit/UploadedFiles/Info.plist'

#plist = Nokogiri::PList(open('/Users/iainbryson/Library/Application\ Support/MarsEdit/UploadedFiles/Info.plist'))

plist = Plist::parse_xml(plist_file)

filemap = {}

plist["Files"].each do |file|
    filemap[file["url"]] = file["originalFileName"]
end


# http://www.ohler.com/dev/ways_to_parse_xml/ways_to_parse_xml.html
def plist_to_obj_xml(xml)
  xml = xml.gsub(%{<plist version="1.0">
}, '')
  xml.gsub!(%{
</plist>}, '')
  { '<dict>' => '<h>',
    '</dict>' => '</h>',
    '<dict/>' => '<h/>',
    '<array>' => '<a>',
    '</array>' => '</a>',
    '<array/>' => '<a/>',
    '<string>' => '<s>',
    '</string>' => '</s>',
    '<string/>' => '<s/>',
    '<key>' => '<s>',
    '</key>' => '</s>',
    '<integer>' => '<i>',
    '</integer>' => '</i>',
    '<integer/>' => '<i/>',
    '<real>' => '<f>',
    '</real>' => '</f>',
    '<real/>' => '<f/>',
    '<true/>' => '<y/>',
    '<false/>' => '<n/>',
  }.each do |pat,rep|
    xml.gsub!(pat, rep)
  end
  xml
end

def convert_parse_obj(xml)
  xml = plist_to_obj_xml(xml)
  p xml
  ::Ox.load(xml, :mode => :object)
end

#convert_parse_obj(File.read(plist_file))

