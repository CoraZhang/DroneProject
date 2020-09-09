var fsChart; // fleet status pie chart

/******************************************************************************
 Initialize the Fleet Status pie chart.
 ******************************************************************************/
function initFleetStatusChart(garage, stall, transit) {
  // console.log("FleetStatus: InGarage: " + garage + "; Stalled: " + stall + "; InTransit: " + transit);
  fsChart = AmCharts.makeChart( "chartdiv", {
    "type": "pie",
    "angle": 20.7,
    "balloonText": "[[title]]<br><span style='font-size:14px'><b>[[value]]</b> ([[percents]]%)</span>",
    "labelText": "[[percents]]%",
    "depth3D": 15,
    "titleField": "category",
    "valueField": "column-1",
    "theme": "light",
    "minRadius":80,
    "allLabels": [],
    "startDuration": 0, // no animation
    "balloon": {},
    "fontFamily": "Ericsson Capital TT",
    "fontSize": 12,
    "legend": {
      "enabled": true,
      "align": "center",
      "markerType": "circle"
    },
    "titles": [
      {
        "id": "Title-1",
        "text": "FLEET STATUS"
      }
    ],
    "dataProvider": [
      {
        "category": "At Warehouse",
        "column-1": garage
      },
      {
        "category": "Stalled",
        "column-1": stall
      },
      {
        "category": "In transit",
        "column-1": transit
      }
    ]
  } );

}

/******************************************************************************
 Update the Fleet Status pie chart.
 ******************************************************************************/
function updateFleetStatusChart(garage, stall, transit) {
  fsChart.clear();
  initFleetStatusChart(garage, stall, transit);
}
