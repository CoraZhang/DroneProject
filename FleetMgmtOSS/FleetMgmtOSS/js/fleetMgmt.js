/******************************************************************************
 * fleetMgmt.js
 * By Chris Spencer, P.Eng (christopher.b.spencer@ericsson.com)
 * Ericsson Canada Inc, Ottawa, Ontario, CANADA
 * (c) 2106-2018
 ******************************************************************************/
var map;
var bounds;
var info;
var maxTrucks = 4;
var tMarker = [];
var tListener = [];
var truckNormalLayer = 10;
var truckZoomLayer = 20;
//var loTemp = 1;
//var hiTemp = 5;
var loTemp = 18;
var hiTemp = 26;

// warehouse info
var warehousePos;
var warehouseName = 'Parliament Hill';
var warehouseCoords = '45.42265,-75.69988';

var PanelIDs = [
	'FleetStatus',
	'Telemetrics0',
	'Telemetrics1',
	'Telemetrics2',
	'Telemetrics3'
];

var Accident = ['STABLE', 'ROLLOVER'];
var Door = ['CLOSED', 'OPEN'];

// image files
var truckImage = 'images/TruckGreen.png';
var alertImage = 'images/TruckGreen_Alert.png';
var greyTruckImage = 'images/TruckGrey.png';
var greyAlertImage = 'images/TruckGrey_Alert.png';
var warehouseImage = 'images/Warehouse.png';

// markers
var truckIcon = L.icon({iconUrl: truckImage, iconAnchor: [36, 36], popupAnchor: [0, -30]});
var alertIcon = L.icon({iconUrl: alertImage, iconAnchor: [36, 36], popupAnchor: [0, -30]});
var greyTruckIcon = L.icon({iconUrl: greyTruckImage, iconAnchor: [36, 36], popupAnchor: [0, -30]});
var greyAlertIcon = L.icon({iconUrl: greyAlertImage, iconAnchor: [36, 36], popupAnchor: [0, -30]});
var warehouseIcon = L.icon({iconUrl: warehouseImage, iconAnchor: [36, 72], popupAnchor: [0, -30]});

// chart values
var ingarage;
var stalled;
var intransit;

var deliveryStat = []; // delivery status for each truck
var ONTIME = 0;
var LATE = -1;
var EARLY = 1;
var NOTLEFT = 2;

/******************************************************************************
 map creation and update function
 ******************************************************************************/
function drawMap() {

 // define map
/*  var mapOptions = {
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
     google.maps.MapTypeId.TERRAIN],
 }; // end mapOptions
 */ 
 
 // draw map
 // map = new google.maps.Map(document.getElementById('map_div'), mapOptions);
 map = new L.map('map_div').setView([45.42265,-75.69988], truckNormalLayer);
 L.control.scale().addTo(map);

 gl = L.mapboxGL({
        attribution: '<a href="https://www.maptiler.com/license/maps/" target="_blank">© MapTiler</a> <a href="https://www.openstreetmap.org/copyright" target="_blank">© OpenStreetMap contributors</a>',
        accessToken: 'not-needed',
        style: 'https://maps.tilehosting.com/styles/bright/style.json?key=nYTEGMyrAlMnNjX6W0rn'
      }).addTo(map);

 L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token=nYTEGMyrAlMnNjX6W0rn', {
      attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery ɠ<a href="https://www.mapbox.com/">Mapbox</a>',
      maxZoom: 18,
      id: 'mapbox.streets',
      accessToken: 'nYTEGMyrAlMnNjX6W0rn'
    }).addTo(map);

 /*
 var trafficLayer = new google.maps.TrafficLayer();
 trafficLayer.setMap(map);
 */
 
 initializeMap();
 
 console.log("Initializing fleet status chart...");
 ingarage = maxTrucks;
 stalled = 0;
 intransit = 0;
 initFleetStatusChart(ingarage, stalled, intransit);

 console.log("Initializing delivery status chart...");
 early = 0;
 ontime = 0;
 late = 0;
 notleft = maxTrucks;
 initDeliveryStatusChart(early, ontime, late, notleft);
 
 // Schedule the updateMap function to run every 5 seconds (5000ms)
 console.log("Updating map...");
 updateMap();
 var interval = self.setInterval(updateMap, 5000);
}

/******************************************************************************
 Read the contents of the warehouse.json file.
 ******************************************************************************/
function initializeMap() {
  var jsonFile = 'json/warehouse.json';
  console.log("Initializing map...");

  $.getJSON(jsonFile, function (data) {
	console.log("Initializing warehouse...");
    setWarehouseCoords(data.lat, data.lng);
    setWarehouseName(data.name);
    warehousePos = L.latLng(data.lat.toFixed(5), data.lng.toFixed(5));

    console.log("Warehouse Name: " + warehouseName + "; Coords: " + warehouseCoords + " (Lat: " + data.lat + ", Lng: " + data.lng +")");
	
    var icon = warehouseIcon;
    var warehouseMarker = new L.marker(warehousePos, {icon: icon, title: warehouseName}).addTo(map);
	var html = '<h4>' + data.name + '</h4>';
	
	warehouseMarker.bindPopup(html);
	bounds = L.latLngBounds([[data.lat + 0.025, data.lng + 0.025], [data.lat - 0.025, data.lng - 0.025]]);
	
	// warehouse click action
    warehouseMarker.on('click', function() { 
      map.setView(warehousePos, truckZoomLayer); // center map and zoom in
    });
	
    // warehouse double-click action
    warehouseMarker.on('dblclick', function() { 
      map.fitBounds(bounds); // zoom out to include everything
	  showFleetStatus();
    });

    console.log("Warehouse initialized.");
	console.log("Initializing truck markers to near warehouse " + warehousePos.toString() + "...");
 
	for(var truck = 0; truck < maxTrucks; truck++) {
	   var icon = truckIcon;
	   var zlayer = truckZoomLayer;
	   var title = 'Truck ' + truck + ': OK.';
	   var pos = L.latLng((data.lat + (truck * 0.0005)).toFixed(5), (data.lng - (truck * 0.0005)).toFixed(5));
	   var html = '<h4>Truck '+truck+':</h4><b>Location:</b> ' + pos.toString();
	   
       console.log("Truck #" + truck + " pos = " + pos.toString());
	   bounds.extend(pos);
	   
	   if(truck > 0) {
		  icon = greyTruckIcon;
		  zlayer = truckNormalLayer;
		}
		
		tMarker[truck]= L.marker(pos, {
			icon: icon,
			title: title,
			zIndexOffset: zlayer
		   }).addTo(map); // end marker;
		tMarker[truck].bindPopup(html);
		
		// truck click action
		tMarker[truck].on('click', function() { 
			 map.setView(pos, truckZoomLayer); // center map and zoom in
			});
				
		// truck double-click action
		tMarker[truck].on('contextmenu', function() { 
		  map.fitBounds(bounds); // zoom out to include everything
		  showFleetStatus();
		});
				
		deliveryStat[truck] = ONTIME;   
		console.log("Truck #" + truck + " initialized.");
	} // end for truck

	map.fitBounds(bounds);
	map.setView(bounds.getCenter(), truckZoomLayer);
  }); // end getJSON
}

/******************************************************************************
 ******************************************************************************/
function setWarehouseCoords(lat, lng) {
  warehouseCoords = lat.toFixed(5) + ',' + lng.toFixed(5);
}

/******************************************************************************
 ******************************************************************************/
function setWarehouseName(name) {
 warehouseName = name;
}

/******************************************************************************
 Update the trucks' position on the map.  Call functions to update HTML displays.
 ******************************************************************************/
function updateMap() {  
  ingarage = 0;
  stalled = 0;
  intransit = 0;

	for(var truck = 0; truck < maxTrucks; truck++) {
       var jsonFile = 'json/truck' + truck + '.json';
       // console.log('json file ' + truck + ': ' + jsonFile);
       
       $.getJSON(jsonFile, function (data) {
         var html = '<h4>Truck: ' + data.name + '</h4><table>';
         var pos = L.latLng(parseFloat(data.lat), parseFloat(data.lng));
         var icon = truckIcon; 
         var alert = alertIcon;
         var zlayer = truckZoomLayer; 
         var title = '';
        
         bounds.extend(pos);
         
         // only truck 0 is special
         if(data.truck > 0) {
           icon = greyTruckIcon;
           alert = greyAlertIcon;
           zlayer = truckNormalLayer;
          }
         
         if(pos.equals(warehousePos))
           ingarage++;
         else {
           if(data.accident || data.door) 
              stalled++;
           else 
              intransit++;
         } 
            
         deliveryStat[data.truck] = data.status;
         
         // alert event
         if(data.accident || data.door || data.temp < loTemp || data.temp > hiTemp) {
           if(data.accident)
                title += Accident[data.accident] + '; ';
           if(data.door)
                title += 'DOOR ' + Door[data.door] + '; ';
           if(data.temp < loTemp)
                title += 'TOO COOL';
           if(data.temp > hiTemp)
                title += 'TOO WARM';
           
           // tMarker[data.truck].setAnimation(google.maps.Animation.BOUNCE);
           tMarker[data.truck].setIcon(alert);
           tMarker[data.truck]._icon.title = 'Truck ' + data.truck + ', ' + data.name + ': ' + title;
           
           html += '<tr><td><b>Status:</b></td>' +
           '<td align=right><b class=red>PROBLEM!</b><td></tr>';
         }
         // no alert; all good
         else {
           // tMarker[data.truck].setAnimation(null);
           tMarker[data.truck].setIcon(icon);
           tMarker[data.truck]._icon.title = 'Truck ' + data.truck + ', ' + data.name + ': OK';
           
           html += '<tr><td><b>Status:</b></td>' +
           '<td align=right>OK</td></tr>';
         }
         
         // update the truck's postion on the map
         tMarker[data.truck].setLatLng(pos);
         tMarker[data.truck].setZIndexOffset(zlayer);

         html += '<tr><td><b>Driver:</b></td><td align=right>' + data.driver + '</td></tr>';
         html += '<tr><td><b>Location:</b></td><td align=right>' + 
         data.lat.toFixed(5) + ', ' + data.lng.toFixed(5) + '</td></tr>';
         
         // accident
         html += '<tr><td><b>Accident:</b></td>';	
		 
         if(data.accident)
            html += '<td align=right><b class=red>' + Accident[data.accident] + '</b></td></tr>';
         else
            html += '<td align=right>' + Accident[data.accident] + '</td></tr>';
         
         // door 
         html += '<tr><td><b>Door:</b></td>';
		 
         if(data.door)
          html += '<td align=right><b class=red>' + Door[data.door] + '</b></td></tr>';
         else
          html += '<td align=right>' + Door[data.door] + '</td></tr>';
         
        // temperature
        html += '<tr><td><b>Temperature:</b></td>' + '<td align=right>' + data.temp + '&deg;C';
		
        if(data.temp < loTemp)
         html += ' is <b class=blue>TOO COLD</b></td></tr>';
        else if(data.temp > hiTemp)
         html += ' is <b class=red>TOO HOT</b></td></tr>';
         
        html += '</table>';

		tMarker[data.truck].bindPopup(html);

        // clear old listeners
		tMarker[data.truck].off();
		
         // listeners for infowindow
		 /*
        tListener[data.truck] = tMarker[data.truck].addListener('click', function() { 
               this.setZIndex(zlayer);
               info.setContent(html);
               info.open(map, this); 
               map.setCenter(this.getPosition()); // center on truck
               map.setZoom(15); // zoom to street level
        }); // end addListener	
           
        tListener[data.truck] = tMarker[data.truck].addListener('rightclick', function() { 
               this.setZIndex(zlayer);
               info.close(map, this); 
               map.setCenter(bounds.getCenter()); // center map
               map.fitBounds(bounds); // zoom to include everything
        }); // end addListener	
        */
		
		tMarker[data.truck].on('click', function() { 
 		  findTruck(data.truck);
  		  tMarker[data.truck].togglePopup();
		});
			
		// truck double-click action
		tMarker[data.truck].on('contextmenu', function() { 
		  map.fitBounds(bounds); // zoom out to include everything
		  tMarker[data.truck].closePopup();
		  showFleetStatus();
		});
		
        updateTelemetrics(data);
        updateFleetStatusChart(ingarage, stalled, intransit); // in fsCharts.js
        updateDeliveryStatusChart(getEarly(), getOntime(), getLate(), getNotLeft()); // in dsCharts.js
       }); // end getJSON
	} // end for truck
  
 // map.fitBounds(bounds);
 // console.log('updateMap: InGarage: ' + ingarage + "; Stalled: " + stalled + "; InTransit: " + intransit);
}

/******************************************************************************
 Update the trucks' telemetrics panel contents.
 ******************************************************************************/
function updateTelemetrics(data) {
  // update Telemetrics panel info
  var telemetrics = '<div class="table1Info">' +
    '<table class="teletab">' +
    '<tbody>' +
    '<tr>' +
      '<td class="telemetrics">' +
      '<p>' +
      // '<i class="fa fa-unlock" aria-hidden="true"></i> ' +
      'Container door' +
      '</p><p>';
      
  if(data.door)
    telemetrics += '<img src="images/Open.png" alt="open" title="Door Open">';
  else
    telemetrics += '<img src="images/Locked.png" alt="closed" title="Door Closed">';
    
  telemetrics += '</p><p>' + Door[data.door] + '</p>' +
      '</td>' +
      '<td class="telemetrics">' +
      '<p>' +
      'Accident alert' + 
      '</p><p>';
      
  if(data.accident)
    telemetrics += '<img src="images/Rollover.png" alt="rollover" title="Accident">';
  else
    telemetrics += '<img src="images/Stable.png" alt="stable" title="Stable">';
      
  telemetrics += '</p><p>' + Accident[data.accident] + '</p>' +
       '</td>' +
      
      '<td class="telemetrics">' +
      '<p>' +
      'Temperature' +
      '</p><p>';
      
  if(data.temp < loTemp)
    telemetrics += '<img src="images/Cold.png" alt="cold" title="Too Cold">';
  else if(data.temp > hiTemp)
    telemetrics += '<img src="images/Warm.png" alt="warm" title="Too Warm">';
  else
    telemetrics += '<img src="images/Temperature.png" alt="just_right" title="Goldilocks Zone">';
      
  telemetrics += '</p><p>' + data.temp.toFixed(1) + '&deg;C' + ' / ' + c2f(data.temp) + '&deg;F</p>' +
      '</td>' +
    '</tr>' +
    '</tbody>' +
    '</table>' +
    '</div>';
   
  // truck info
  telemetrics += '<hr>' + 
    '<p class="title">Vehicle Information</p>';
  telemetrics +=  '<div class="table2Info">' +
    '<table width="100%">' +
    '<tbody>' +
    '<tr>' +
    '<td rowspan=6 width=225px height=225px>';
  telemetrics += '<img src="' + data.photo + '" width=225px height=225px>';
  telemetrics += '</td>' + 
  
      '<td class="vlabel" >Vehicle&nbsp;number</td>' +
      '<td class="vdata" id="truck' + data.truck + '">' + data.truck + '</td>' +
    '</tr>' +
    '<tr>' +
      '<td class="vlabel" >Vehicle&nbsp;Name</td>' +
      '<td class="vdata" id="name'+ data.truck + '">' + data.name + '</td>' +
    '</tr>' +
    '<tr>' +
      '<td class="vlabel" >Driver</td>' +
      '<td class="vdata" id="driver'+ data.truck + '">' + data.driver + '</td>' +
    '</tr>' +				
    '<tr>' +
      '<td class="vlabel" >Route</td>' +
      '<td class="vdata" id="route'+ data.truck + '">' + data.route + '</td>' +
    '</tr>' +
    '<tr>' +
      '<td class="vlabel" >Destination</td>' +
      '<td class="vdata" id="destination'+ data.truck + '">' + data.destination + '</td>' +
    '</tr>' +

    '<tr>' +
      '<td class="vlabel" >Location</td>' +
      '<td class="vdata" id="location'+ data.truck + '">' + data.lat.toFixed(5) + ', ' + data.lng.toFixed(5) + '</td>' +
    '</tr>' +
    '</tbody>' +
    '</table>' +
    '</div>';

  // update the telemetrics block for the truck
  var id = "TelemetricsBody" + data.truck;
  var div = document.getElementById(id);
  div.innerHTML = telemetrics;	
  
  // update the menu image
  id = 'Telemetrics' + data.truck + 'MenuImage';
  var img = document.getElementById(id);
  
  if(data.door || data.accident || data.temp < loTemp || data.temp > hiTemp) {
    if(data.truck > 0)
       img.src = greyAlertImage;
    else // truck 0
       img.src = alertImage;
  }
  else  {
    if(data.truck > 0)
       img.src = greyTruckImage;
    else // truck 0
       img.src = truckImage;  
  }
   
  // If the truck's telemetrics are active, have the map remain centered on the truck.
  id = 'Telemetrics' + data.truck;
  div = document.getElementById(id);
  
  if(div.style.display == 'block') {
	var pos = new L.latLng(parseFloat(data.lat), parseFloat(data.lng));
    map.setView(pos, truckZoomLayer);
  }
}

/******************************************************************************
convert celsius to farenheit, as an integer
******************************************************************************/
function c2f(ctemp) {
  var ftemp = 32 + (1.8 * ctemp);
  return ftemp.toFixed(1);
}
/******************************************************************************
 center map on the truck indicated  by the truck number, and zoom in.
 ******************************************************************************/
function findTruck(truckno) {
	 console.log("Finding truck #" + truckno + "...");
	 
	 if(truckno >= 0 && truckno <= maxTrucks-1) {
		 tMarker[parseInt(truckno)].setZIndexOffset(truckZoomLayer);
		 map.setView(tMarker[parseInt(truckno)].getLatLng(), truckZoomLayer);
		 // map.setZoom(truckZoomLayer);
	 }
	 else
		alert("Truck number " + truckno + " doesn't exist.");
}

/******************************************************************************
 hide all info panels
 ******************************************************************************/
function hideAllInfoPanels() {
	for(var i = 0; i < PanelIDs.length; i++) {
		var div = document.getElementById(PanelIDs[i]);
		if(div.style.display != "none")
			div.style.display = "none"; // hide the div
	}
}

/******************************************************************************
 Deactivate all sidebar menu items.  That is, show all menu items as not being 
 the active menu item/panel.
 ******************************************************************************/
function deactivateMenuItems() {
	for(var i = 0; i < PanelIDs.length; i++) {
		var id = PanelIDs[i] + "MenuItem";
		var div = document.getElementById(id);
		div.className = null; // hide the div
	}
}

/******************************************************************************
 show the given truck's telemetrics
 ******************************************************************************/
function showTelemetrics(truckno) {	
    console.log("Showing telemetrics for truck #" + truckno + "...");
    
	if(truckno >= 0 && truckno <= maxTrucks-1) {
		var id = 'Telemetrics' + truckno;
		var div = document.getElementById(id);
		
		hideAllInfoPanels();
		div.style.display = "block";
        deactivateMenuItems();
		
		id += "MenuItem";
		div = document.getElementById(id);
		div.className = "active";
		
		// zoom in on selected truck
		findTruck(truckno);
	}
	else
		alert("Truck number " + truckno + " doesn't exist.");
}

/******************************************************************************
 show the fleet status panel
 ******************************************************************************/
function showFleetStatus() {
	console.log("Showing fleet status...");
	
	var div = document.getElementById("FleetStatus");

	hideAllInfoPanels();
	
	if(div.style.display != "block")
		div.style.display = "block"; // show the div	
	
	deactivateMenuItems();

	div = document.getElementById("FleetStatusMenuItem");
	div.className = "active";
	
	// show full map
	map.fitBounds(bounds);
	map.setView(bounds.getCenter());
}

/******************************************************************************
 Return the number of ontime trucks.
 ******************************************************************************/
function getOntime() {
  var count = 0;
 	for(var truck = 0; truck < maxTrucks; truck++) {
    if(deliveryStat[truck] == ONTIME)
      count++;
  }
  return count;
}

/******************************************************************************
 Return the number of late trucks.
 ******************************************************************************/
function getLate() {
  var count = 0;
 	for(var truck = 0; truck < maxTrucks; truck++) {
    if(deliveryStat[truck] == LATE)
      count++;
  }
  return count;
}

/******************************************************************************
 Return the number of early trucks.
 ******************************************************************************/
function getEarly() {
  var count = 0;
 	for(var truck = 0; truck < maxTrucks; truck++) {
    if(deliveryStat[truck] == EARLY)
      count++;
  }
  return count;
}

/******************************************************************************
 Return the number of early trucks.
 ******************************************************************************/
function getNotLeft() {
  var count = 0;
 	for(var truck = 0; truck < maxTrucks; truck++) {
    if(deliveryStat[truck] == NOTLEFT)
      count++;
  }
  return count;
}

/******************************************************************************
 Returns a random integer between min (included) and max (excluded)
 Using Math.round() will give you a non-uniform distribution!
 ******************************************************************************/ 
function getRandomInt(max) {
  var min = Math.ceil(0);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min)) + min;
}
