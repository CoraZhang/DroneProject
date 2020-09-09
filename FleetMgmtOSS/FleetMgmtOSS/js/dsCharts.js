var dsChart; // delivery status pie chart

/******************************************************************************
 Initialize the Delivery Status pie chart.
 ******************************************************************************/
function initDeliveryStatusChart(early, ontime, late, notleft) {
  // console.log("DeliveryStatus: Early: " + early + "; OnTime: " + ontime + "; Late: " + late);
  dsChart = AmCharts.makeChart( "chartdiv1", {
    "type": "pie",
    "angle": 20.7,
    "balloonText": "[[title]]<br><span style='font-size:14px'><b>[[value]]</b> ([[percents]]%)</span>",
    "labelText": "[[percents]]%",
    "depth3D": 15,
    "titleField": "category",
    "valueField": "column-1",
    "theme": "light",
    "minRadius":70,
    "allLabels": [],
    "startDuration": 0,
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
        "text": "DELIVERY STATUS"
      }
    ],
    "dataProvider": [
      {
        "category": "Running Late",
        "column-1": late
      },
      {
        "category": "Running Early",
        "column-1": early
      },
      {
        "category": "On Time",
        "column-1": ontime
      },
      {
        "category": "At Warehouse",
        "column-1": notleft
      },

    ]
  } );
}

/******************************************************************************
 Update the Delivery Status pie chart.
 ******************************************************************************/
function updateDeliveryStatusChart(early, ontime, late, notleft) {
  dsChart.clear();
  initDeliveryStatusChart(early, ontime, late, notleft);
}
