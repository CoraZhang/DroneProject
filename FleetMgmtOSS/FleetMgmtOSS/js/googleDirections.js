// var html = "<h3>Route Coordinates:</h3>\n<textarea cols=100 rows=25>";
var map;
var directionsService = new google.maps.DirectionsService();
var directionsDisplay = new google.maps.DirectionsRenderer();
var bounds = new google.maps.LatLngBounds;
var Points = [];

/******************************************************************************************************/
function initMap() {
 
 var mapOptions = {
   mapType: 'normal',
   fullscreenControl: true,
   showTooltip: true,
   showInfoWindow: true,
   mapTypeControl: true,
   scaleControl: true,
   scrollWheel: true,
   streetViewControl: true,
   zoomControl: true,
   
   // User will only be able to view/select custom styled maps.
   mapTypeIds: [google.maps.MapTypeId.ROADMAP, google.maps.MapTypeId.SATELLITE, google.maps.MapTypeId.HYBRID, 
     google.maps.MapTypeId.TERRAIN]
 }; // end mapOptions
 
 map = new google.maps.Map(document.getElementById('map_div'), mapOptions);
 
 directionsDisplay.setMap(map);
} // end initMap;

/******************************************************************************************************/
function calcRoute() {
   var start = document.getElementById('start').value;
   var end = document.getElementById('end').value;
   var coordsdiv = document.getElementById('coords');
   coordsdiv.innerHTML = "";
   
   var request = {
        origin: start,
        destination: end,
        travelMode: google.maps.TravelMode.DRIVING
     };
            
   directionsService.route(request, function (response, status) {
      if (status == google.maps.DirectionsStatus.OK) {
         
         var html = "Dest: " + response.routes[0].legs[0].end_address + "\n";
         
         map.fitBounds(response.routes[0].bounds);
         directionsDisplay.setDirections(response);
         
         for (var i = 0; i < response.routes[0].overview_path.length; ++i) {
           var point = new google.maps.LatLng(response.routes[0].overview_path[i].lat(), response.routes[0].overview_path[i].lng());
           bounds.extend(point);
           Points.push(point);
           console.log(response.routes[0].overview_path[i].lat() + ', ' + response.routes[0].overview_path[i].lng());
           html += response.routes[0].overview_path[i].lat().toFixed(5) + "," + response.routes[0].overview_path[i].lng().toFixed(5) + "\n";
         } // end for i
        
        var coordsdiv = document.getElementById('coords');
        coordsdiv.innerHTML += html;
      } // end if status
   });

  map.fitBounds(bounds);
  map.setCenter(bounds.getCenter());
}

