var map;
var bounds;
var info;
var maxTrucks = 4;
var tMarker = [];
var tListener = [];
var truckNormalLayer = 10;
var truckZoomLayer = 20;
var loTemp = 16;
var hiTemp = 26;

var warehousePos;

var PanelIDs = [
	'FleetStatus',
	'Telemetrics0',
	'Telemetrics1',
	'Telemetrics2'
];

var Accident = ['STABLE', 'ROLLOVER'];
var Door = ['CLOSED', 'OPEN'];

// icons
var truckIcon = 'images/TruckGreen.png';
var alertIcon = 'images/TruckGreen_Alert.png';
var greyTruckIcon = 'images/TruckGrey.png';
var warehouseIcon = 'images/Warehouse.png';

// chart values
var ingarage;
var stalled;
var intransit;

var dStatus = []; // delivery status for each truck
var ONTIME = 0;
var LATE = -1;
var EARLY = 1;

/******************************************************************************
 map creation and update function
 ******************************************************************************/
function drawMap() {
 // warehouse info
 var warehouseAddr = '3350 Donald Lee Hollowell Pkwy NW Atlanta, GA 30331';
 var warehouseCoords = '33.7899380,-84.4993746';
 
 // tower
 var towerCoords = '33.78526463288818,-84.43051099777222';
 
 // waypoints/destinations
 var wpAddress = [
	'Philips Arena, Philips Dr NW, Atlanta, GA 30303-2723',
	'Georgia Dome, 1 Georgia Dome Dr NW, Atlanta, GA 30313-1504',
	'World of Coca-Cola, 121 Baker St NW, Atlanta, GA 30313-1807',
	'Turner Field, 755 Hank Aaron Dr SW, Atlanta, GA 30315-1120',
	'High Museum of Art, 1280 Peachtree St NE, Atlanta, GA 30309-3549',
  
	'Fulton County Airport-Brown Field, 3952 Aviation Cir NW, Atlanta, GA 30336',
  'Six Flags Over Georgia, 275 Riverside Parkway Southwest, Austell, GA 30168',
  'Atlanta Metropolitan State College, 1630 Metropolitan Pkwy SW, Atlanta, GA 30310',
  'Lakewood Stadium, Lakewood Ave SE, Atlanta, GA 30315',
  'United States Penitentiary Atlanta, 601 McDonough Blvd SE, Atlanta, GA 30315',
	
  'Georgia Institute of Technology, North Ave NW, Atlanta, GA 30332',
	'Jimmy Carter Presidential Library and Museum, 441 Freedom Pkwy NE, Atlanta, GA 30307',
	'Zoo Atlanta, 800 Cherokee Ave SE, Atlanta, GA 30315',
	'Clark Atlanta University, 223 James P Brawley Dr SW, Atlanta, GA 30314',
	'CSX-Tilford Yard, 1442 Marietta Rd NW, Atlanta, GA 30318'
 ];
 
 var wpCoords = [
	'33.7570100,-84.3973393', // Philips Arena
	'33.7563217,-84.4022164', // Georgia Dome
	'33.7627423,-84.3926638', // World of Coke
	'33.7365,-84.3898', // Turner Field
	'33.7892,-84.3849', // High Museum of Art
	
	'33.7771,-84.5217', // Fulton County Airport
  '33.7699,-84.5476', // Six Flags Over Georgia
  '33.7119,-84.4057', // Atlanta Metropolitan State College
  '33.7119,-84.3803', // Lakewood Stadium
  '33.7116,-84.3711', // United States Penitentiary Atlanta
	
	'33.7713,-84.3912', // Georgia Institute of Technology
  '33.7665,-84.3562', // Jimmy Carter Presidential Library and Museum
  '33.7341,-84.3723', // Zoo Atlanta
	'33.7540,-84.4120', // Clark Atlanta University
	'33.7888,-84.4363' // CSX-Tilford Yard
 ];
 
 var wpName = [];
 for(var i = 0; i < wpAddress.length; i++)  {
	 var name = wpAddress[i].split(",", 1);
	 wpName.push(name[0]);
	 // console.log(name[0]);
 }

 var Waypt = [];
 for(var i = 0; i < wpAddress.length; i++)  {
	 Waypt.push({ location: wpAddress[i] });
 }
 
 // define map
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
     google.maps.MapTypeId.TERRAIN],
 }; // end mapOptions
 
 // draw map
 map = new google.maps.Map(document.getElementById('map_div'), mapOptions);
 
 bounds = new google.maps.LatLngBounds;
 info = new google.maps.InfoWindow();

 /*
 var trafficLayer = new google.maps.TrafficLayer();
 trafficLayer.setMap(map);
 */
 
 // display warehouse icon
 latlng = warehouseCoords.split(",");
 warehousePos = new google.maps.LatLng(parseFloat(latlng[0]), parseFloat(latlng[1]));
 bounds.extend(warehousePos);

 var warehouseMarker = new google.maps.Marker({
	 position: warehousePos,
	 icon: warehouseIcon,
	 map: map,
	 title: 'Warehouse',
	 html: '<h4>Warehouse:</h4>' + warehouseAddr,
	 zIndex: 1
 });

 google.maps.event.addListener(warehouseMarker, 'click', function() { 
   info.setContent(this.html);
   info.open(map, this); 
   map.setCenter(this.getPosition()); // center on waypoint
   map.setZoom(15); // zoom to street level
 });
 google.maps.event.addListener(warehouseMarker, 'rightclick', function() { 
	 info.close(map, this); 
	 map.setCenter(bounds.getCenter()); // center map
	 map.fitBounds(bounds); // zoom to include everything
 }); // end addListener		       

 // display tower icon
 var latlng = towerCoords.split(",");
 var towerPos = new google.maps.LatLng(parseFloat(latlng[0]), parseFloat(latlng[1]));
 bounds.extend(towerPos);

 /*
 var towerMarker = new google.maps.Marker({
	 position: towerPos,
	 icon: towerIcon,
	 map: map,
	 title: 'Cell Tower',
	 html: 'Cell tower with CAT-M service',
	 zIndex: 1
 });

 towerMarker.addListener('click', function() { 
       info.setContent(this.html);
       info.open(map, this); 
 });
 */
 
 // display all waypoint location icons
 for(var i = 0; i < wpAddress.length; i++) {
	 latlng = wpCoords[i].split(",");
	 var pos = new google.maps.LatLng(parseFloat(latlng[0]), parseFloat(latlng[1]));
	 bounds.extend(pos);

	 // If waypoint/destination markers are not to be displayed, comment out from here
	 // to the end of the for-loop (i.e. just after addListener call).
	 /*
	 var marker = new google.maps.Marker({
		 position: pos,
		 icon: waypointIcon,
		 map: map,
		 title: wpName[i],
		 html: wpAddress[i],
		 zIndex: 1
	});
	
    google.maps.event.addListener(marker, 'click', function() { 
      info.setContent(this.html);
      info.open(map, this); 
      map.setCenter(this.getPosition()); // center on waypoint
      map.setZoom(15); // zoom to street level
    });
    google.maps.event.addListener(marker, 'rightclick', function() { 
      info.close(map, this); 
      map.setCenter(bounds.getCenter()); // center map
      map.fitBounds(bounds); // zoom to include everything
    }); // end addListener	
	*/	
 } // end for each Addresses
       
 map.fitBounds(bounds);
 map.setCenter(bounds.getCenter());

 // initialize truck markers
 for(var truck = 0; truck < maxTrucks; truck++) {
	 // console.log("Initializing truck " + truck);
	 var icon = truckIcon;
   var zlayer = truckZoomLayer;
   
	 if(truck > 0) {
     icon = greyTruckIcon;
	   zlayer = truckNormalLayer;
   }
		 
	 tMarker[truck]= new google.maps.Marker({
		 map: map,
		 position: warehousePos,
		 icon: icon,
		 title: 'Truck '+ truck + ': OK.',
		 html: '<h4>Truck '+truck+':</h4><b>Location:</b> ' + warehouseCoords,
   // visible: 1,
		 zIndex: zlayer
	 }); // end marker;
	 
	 tListener[truck] = tMarker[truck].addListener('click', function() { 
	       info.setContent(this.html);
	       info.open(map, this); 
	 });

   dStatus[truck] = ONTIME;   
 } // end for truck
 
 ingarage = maxTrucks;
 stalled = 0;
 intransit = 0;
 initFleetStatusChart(ingarage, stalled, intransit);

 early = 0;
 ontime = maxTrucks;
 late = 0;
 initDeliveryStatusChart(early, ontime, late);
 
 // Schedule the updateMap function to run every 5 seconds (5000ms)
 updateMap();
 var interval = self.setInterval(updateMap, 5000);
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
			 // console.log('Truck ' + data.truck);

			 var html = '<h4>Truck: ' + data.name + '</h4><table>';
			 var pos = new google.maps.LatLng(parseFloat(data.lat), parseFloat(data.lng));
			 var title;
			 var icon = truckIcon; 
       var zlayer = truckZoomLayer; 
       
       // only truck 0 is special
			 if(data.truck > 0) {
				 icon = greyTruckIcon;
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
       
       dStatus[data.truck] = data.status;
       
			 // update the truck's postion on the map
			 tMarker[data.truck].setPosition(pos);
			 tMarker[data.truck].setVisible(1);
			 
			 if(data.accident || data.door || data.temp < loTemp || data.temp > hiTemp) {
				 if(data.accident)
					 title += ' ' + Accident[data.accident];
				 if(data.door)
					 title += ' ' + Door[data.door];
				 if(data.temp < loTemp)
					 title += ' TOO COOL;';
				 if(data.temp > hiTemp)
					 title += ' TOO WARM';
				 
				 tMarker[data.truck].setAnimation(google.maps.Animation.BOUNCE);
				 tMarker[data.truck].setIcon(alertIcon);
				 tMarker[data.truck].setTitle(data.name + ':' + title);
				 
				 html += '<tr><td><b>Status:</b></td>' +
					'<td align=right><b class=red>PROBLEM!</b><td></tr>';
			 }
			 else {
				 tMarker[data.truck].setAnimation(null);
				 tMarker[data.truck].setIcon(icon);
				 tMarker[data.truck].setTitle(data.name + ': OK');
				 
				 html += '<tr><td><b>Status:</b></td>' +
					'<td align=right>OK</td></tr>';
			 }
			 
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
			html += '<tr><td><b>Temperature:</b></td>' + 
				'<td align=right>' + data.temp + '&deg;C';
			if(data.temp < loTemp)
				html += ' is <b class=blue>TOO COLD</b></td></tr>';
			else if(data.temp > hiTemp)
				html += ' is <b class=red>TOO HOT</b></td></tr>';
			 
			html += '</table>';

			// clear old listeners
			google.maps.event.clearInstanceListeners(tListener[data.truck]);     

 			// listeners for infowindow
			tListener[data.truck] = tMarker[data.truck].addListener('click', function() { 
			       this.setZIndex(truckZoomLayer);
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

			updateTelemetrics(data);
      updateFleetStatusChart(ingarage, stalled, intransit); // in amCharts.js
      updateDeliveryStatusChart(getEarly(), getOntime(), getLate()); // in amCharts2.js
		}); // end getJSON
	} // end for truck
  
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
    telemetrics += '<img src="images/Open.png" alt="open">';
  else
    telemetrics += '<img src="images/Locked.png" alt="closed">';
    
  telemetrics += '</p><p>' + Door[data.door] + '</p>' +
      '</td>' +
      
      '<td class="telemetrics">' +
      '<p>' +
      // '<i class="fa fa-ambulance" aria-hidden="true"></i> ' +
      'Accident alert' + 
      '</p><p>';
      
  if(data.accident)
    telemetrics += '<img src="images/Rollover.png" alt="rollover">';
  else
    telemetrics += '<img src="images/Stable.png" alt="stable">';
      
  telemetrics += '</p><p>' + Accident[data.accident] + '</p>' +
       '</td>' +
      
      '<td class="telemetrics">' +
      '<p>' +
      // '<i class="fa fa-sort-numeric-asc" aria-hidden="true"></i> ' +
      'Refrigation temperature' +
      '</p><p>';
      
  if(data.temp < loTemp)
    telemetrics += '<img src="images/Cold.png" alt="cold">';
  else if(data.temp > hiTemp)
    telemetrics += '<img src="images/Warm.png" alt="warm">';
  else
    telemetrics += '<img src="images/Temperature.png" alt="just_right">';
      
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
    // '<table class="table table-hover">' +
    '<table width="100%">' +
    '<tbody>' +
    '<tr>' +
    '<td rowspan=6 width=225px height=225px>';
    
  if(data.door)
    telemetrics += '<img src="images/OpenDoors.png" alt="Open Doors" width=225px height=225px>';
  else
    telemetrics += '<img src="images/MovingTruck.png" alt="Moving Truck" width=225px height=225px>';
  
  telemetrics += '</td>' + 
  
      '<td class="vlabel" >Vehicle number</td>' +
      '<td class="vdata" id="truck' + data.truck + '">' + data.truck + '</td>' +
    '</tr>' +
    '<tr>' +
      '<td class="vlabel" >Vehicle Name</td>' +
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
      '<td class="vdata" id="destination'+ data.truck + '">' + data.dest + '</td>' +
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
  
  // If the truck's telemetrics are active, have the map remain centered on the truck.
  id = 'Telemetrics' + data.truck;
  div = document.getElementById(id);
  // console.log("div.style.display = " + div.style.display);
  if(div.style.display == 'block') {
		 var pos = new google.maps.LatLng(parseFloat(data.lat), parseFloat(data.lng));
     map.setCenter(pos);
     // console.log("map following truck");
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
	 if(truckno >= 0 && truckno <= maxTrucks-1) {
		 tMarker[parseInt(truckno)].setZIndex(truckZoomLayer);
		 map.setCenter(tMarker[parseInt(truckno)].getPosition());
		 map.setZoom(15);
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
 inactivate all sidebar menu items.  That is, show all menu items as not being 
 the active menu item/panel.
 ******************************************************************************/
function inactivateMenuItems() {
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
	if(truckno >= 0 && truckno <= maxTrucks-1) {
		var id = 'Telemetrics' + truckno;
		var div = document.getElementById(id);
		
		hideAllInfoPanels();
		
		div.style.display = "block";

		inactivateMenuItems();
		
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
	var div = document.getElementById("FleetStatus");

	hideAllInfoPanels();
	
	if(div.style.display != "block")
		div.style.display = "block"; // show the div	
	
	inactivateMenuItems();

	div = document.getElementById("FleetStatusMenuItem");
	div.className = "active";
	
	// show full map
	map.fitBounds(bounds);
	map.setCenter(bounds.getCenter());
}

/******************************************************************************
 Return the number of ontime trucks.
 ******************************************************************************/
function getOntime() {
  var count = 0;
 	for(var truck = 0; truck < maxTrucks; truck++) {
    if(dStatus[truck] == ONTIME)
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
    if(dStatus[truck] == LATE)
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
    if(dStatus[truck] == EARLY)
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
