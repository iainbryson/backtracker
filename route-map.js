

// pretty-print a date
function formatDate(date) {
    "use strict";
    
    /*var monthNames = [
        "January", "February", "March",
        "April", "May", "June", "July",
        "August", "September", "October",
        "November", "December"
    ];*/
    var monthNames = [
        "Jan", "Feb", "Mar",
        "Apr", "May", "Jun", "Jul",
        "Aug", "Sep", "Oct",
        "Nov", "Dec"
    ];

    var day = date.getDate();
    var monthIndex = date.getMonth();
    var year = date.getFullYear();

    return day + '-' + monthNames[monthIndex] + '-' + year;
}

// get the minimum bounds which contain a set of markers
function getMarkerBounds(markers) {
    var bounds = new google.maps.LatLngBounds(
        markers[0],
        markers[0]
    )
    
    for(var i = 1; i < markers.length; i++)
    {
        bounds.extend(markers[i]);
    }
    
    return bounds
}

// scroll the parent jquery DOM object so that its top is the item jquery dom object
function scrollingdiv(parent, item){
    parent.animate({scrollTop: item.position().top + parent.scrollTop()}, 800, 'swing');
}

// compute the geographical center of a series of points/
// (1) transform all points to (unit) XYZ coordinates
// (2) average them
// (3) compute the unit vector of the average
// (4) transform the unit vector back to latitude/longitude
function geographicalCenter(points) {
    "use strict";
    
    if (points.length == 1) return points[0];
    
    var threedpoints = points.map(function(latlong) {
        return [Math.cos(latlong[0] * Math.PI / 180) * Math.cos(latlong[1] * Math.PI / 180),
                Math.cos(latlong[0] * Math.PI / 180) * Math.sin(latlong[1] * Math.PI / 180),
                Math.sin(latlong[0] * Math.PI / 180) ]} )
 
    var sum = threedpoints.reduce(function(a, b) { return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]; })
    var avg = sum.map(function(a) { return a / threedpoints.length; })

    var vector_length = Math.sqrt(avg[0]*avg[0] + avg[1]*avg[1] + avg[2] * avg[2])

    if (vector_length < 1e-6) throw new InvalidOperation("vector length too small (are the points at opposite ends of the world?");

    var unit_vector = avg.map(function(a) { return a /vector_length; })

    var latitude =  Math.asin(unit_vector[2])
    var cos_lat = Math.cos(latitude);
    var longitude;
    if (Math.abs(cos_lat) > 0.01) {
        longitude = Math.acos(unit_vector[0] / cos_lat)
    } else {
        longitude = Math.asin(unit_vector[1] / Math.sin(latitude))
    }

    return [latitude * 180 / Math.PI, longitude * 180 / Math.PI]
}

// https://stackoverflow.com/questions/7095574/google-maps-api-3-custom-marker-color-for-default-dot-marker
/*function pinSymbol(color) {
    "use strict";

    return {
        path: 'M 0,0 C -2,-20 -10,-22 -10,-30 A 10,10 0 1,1 10,-30 C 10,-22 2,-20 0,0 z M -2,-30 a 2,2 0 1,1 4,0 2,2 0 1,1 -4,0',
        fillColor: color,
        fillOpacity: 1,
        strokeColor: '#000',
        strokeWeight: 2,
        scale: 1,
   };
}*/

// labeled pin
// http://biostall.com/adding-number-or-letters-to-google-maps-api-markers
function pinSymbol(color, label) {
    color = color.substr(1,color.length) // remove the leading '#'
    return 'http://chart.apis.google.com/chart?chst=d_map_pin_letter&chld='+label+'|' + color + '|eeeeee'
}

function initialize(marker_data) {
    "use strict";

    var root = marker_data

    var markers = root[0].markers.filter(function(d) { return d.gps; });

    var lat_extent  = d3.extent(markers, function(d) { return d.gps.latitude;  });
    var long_extent = d3.extent(markers, function(d) { return d.gps.longitude; });

    markers.forEach( function(d) { if (d.day) d.day = new Date(d.day); })
    var marker_dates = markers.map( function(d) { if (d.day) return d.day; })
    var date_extent = d3.extent(marker_dates)
    var time_range = d3.time.scale().domain(date_extent).range([0,1])

    markers = markers.sort(function(l, r) { return l.day - r.day; })

    // Bad idea: when the points cross the dateline, you'll be looking at the wrong side of the world
    //var extent_center = [(lat_extent[1] + lat_extent[0])/2, (long_extent[1] + long_extent[0])/2 ]
    //var center = new google.maps.LatLng((lat_extent[1] + lat_extent[0])/2, (long_extent[1] + long_extent[0])/2)

    var center = geographicalCenter(markers.map(function(d) { return [d.gps.latitude, d.gps.longitude] }))

console.log(center)
console.log(markers)

    var mapOptions = {
            zoom: 2,
            draggableCursor: 'default',
            center:  new google.maps.LatLng(center[0], center[1])
      }

    var map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions)

    // Define a symbol using a predefined path (an arrow)
    // supplied by the Google Maps JavaScript API.
    var lineSymbol = {
        path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
        scale: '3.0'
    };

    var travelArrows = []
    
    var marker_id = 0
    
    var setupMarkers = function() {
        var prevPoint;
        
        for (var res in root) {
            if (root.hasOwnProperty(res)) {
                var div = $('<div id="toczoom' + root[res]["zoom"][0] + '-' + root[res]["zoom"][1] + '"></div>')
                var ul = $('<ul></ul>')
                div.appendTo('#margin-content')
                ul.appendTo(div)
        
                var markers_at_zoom = []
                var lines_at_zoom = []
                var toc_at_zoom = []
                var prevPoint = null
                
                var map_markers = []
                var marker_info = root[res]["markers"]
                 marker_info.forEach(function(d) { d.position = new google.maps.LatLng(d.gps.latitude, d.gps.longitude); })

                var marker_label = 'A'
                
                for (var i = 0; i < marker_info.length; i++) {
                    var m = marker_info[i]
                    m.marker_id = marker_id++

                    var myLatLng = m.position

                    var pinColor = d3.interpolateRgb(d3.rgb(0x00,0x00,0x30), d3.rgb(0x20,0x20,0xff))(time_range(new Date(m.day)))

                    var pin = pinSymbol(pinColor, marker_label)

                    var content;
                    if (m.markers.length > 1) {
                        content = m.markers.length + " posts \u2022 " + formatDate(new Date(m.day)) + " \u2022 " + m.country + ", " + m.state
                    } else {
                        content = formatDate(new Date(m.day)) + " \u2022 " + m.markers[0].title
                    }

                    var marker = new google.maps.Marker({
                        marker_id: marker_id,
                        position: myLatLng,
                        icon:     pin,
                        link:     m.post,
                        title:    content
                    });

                    var sub_markers = m.markers.map(function(d) { return new google.maps.LatLng(d.gps.latitude, d.gps.longitude); })
                    
                    var bounds = getMarkerBounds(sub_markers)
                    
                    marker.bounds = bounds;
                    google.maps.event.addListener(marker, 'click', function() {
                        map.fitBounds(this.bounds)
                    });

                    markers_at_zoom.push(marker);

                    if (i > 0) {
                        var lineCoordinates = [
                            prevPoint,
                            myLatLng
                        ];

                        var line = new google.maps.Polyline({
                            path: lineCoordinates,
                            icons: [{
                              icon: lineSymbol,
                              offset: '100%',
                                }, {
                              icon: lineSymbol,
                              offset: '50%',
                                }],
                              geodesic: true,
                                strokeColor: pinColor,
                                strokeOpacity: 0.8,
                                strokeWeight: 2,
                                fillColor: '#000000',
                                fillOpacity: 0.35,
                                map: map
                        });
                        
                        lines_at_zoom.push(line)
                    }

                    if (m.country) {
                        var li = $('<li id="marker' + marker_id + '">' + marker_label + ': ' + formatDate(new Date(m.day)) + " &mdash;   " + m.country + ", " + m.state + ", " + m.sub_state+'</li>')
                        li.appendTo(ul)

                        var sublist = $('<ul></ul>')
                        sublist.appendTo(ul)

                        m.markers.forEach(function(d) { console.log("\t\t" + d.post);
                                var sub_entry = $('<li><a href="' + d.post +'">' + d.title + '</a></li>')
                                sub_entry.appendTo(sublist)
                            } )
                    } else {
                        var li = $('<li id="marker' + marker_id + '">' + formatDate(new Date(m.day)) + ' &mdash;    <a href="' + m.markers[0].post +'">' + m.markers[0].title + '</a></li>')
                        li.appendTo(ul)
                    }

                    prevPoint = myLatLng
                    marker_label = String.fromCharCode(marker_label.charCodeAt(0) + 1)
                }
                
                mgr.addMarkers(markers_at_zoom, root[res]["zoom"][0], root[res]["zoom"][1]);
                
                travelArrows.push({zoom: root[res]["zoom"], arrows: lines_at_zoom, markers : markers_at_zoom })
            }
        }
        
        mgr.refresh();
    }
    
    var updateMarkers = function(map) {
        var zoom = map.getZoom();
        
        for (var i = 0; i < travelArrows.length; i++) {
            var toc = $('#toczoom' + travelArrows[i].zoom[0] + '-' + travelArrows[i].zoom[1])
            if (zoom >= travelArrows[i].zoom[0] && zoom <= travelArrows[i].zoom[1]) {
                for (var j = 0; j < travelArrows[i].arrows.length; j++) {
                    travelArrows[i].arrows[j].setMap(map)
                }
                toc.show()
                for(var j = 0, bounds = map.getBounds(); j < travelArrows[i].markers.length; j++) {
                    if( bounds.contains(travelArrows[i].markers[j].getPosition()) ){
                        var item = $('#marker' + travelArrows[i].markers[j].marker_id)
                        scrollingdiv($('#margin'), item)
                        break;
                    }
                }
            } else {
                for (var j = 0; j < travelArrows[i].arrows.length; j++) {
                    travelArrows[i].arrows[j].setMap(null)
                }
                toc.hide()
            }
        }
        
    }


    var mgr = new MarkerManager(map);

    google.maps.event.addListener(mgr, 'loaded', function(){
        setupMarkers();
        updateMarkers(map);
        google.maps.event.addListener(map, 'zoom_changed', function() {
            updateMarkers(map);
        });
    });  
}

function onload() {

    var json_url = $("#json-data-url").text()
    
    console.log('json data url: ' + json_url)

    var marker_data = $.ajax({
        url: json_url,
        dataType: 'json'
    });

    $.when(marker_data).done(initialize)
                       .fail(function(xhr, status, errorThrown) {
                                            console.log("loading " + " failed\n"+errorThrown+'\n'+status+'\n'+xhr.statusText);
                                         });
}

$( document ).ready(onload);
