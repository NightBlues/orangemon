$(document).ready(function(){

  var plot = function(elt, lines, title, treshold) {
    return $.jqplot(elt, lines,{
        title: title,
        series:[{showMarker:false}],
        canvasOverlay: {
            show: true,
            objects: [
                {dashedHorizontalLine: {
                    name: 'Treshold',
                    y: treshold,
                    lineWidth: 2,
                    color: 'rgb(255, 55, 55)',
                    shadow: false
                }},
            ]
        },
        axes:{
             xaxis:{
                 renderer:$.jqplot.DateAxisRenderer,
                 // rendererOptions: { forceTickAt0: true, forceTickAt100: true },
                 // labelRenderer: $.jqplot.CanvasAxisLabelRenderer,
                rendererOptions:{
                    tickRenderer:$.jqplot.CanvasAxisTickRenderer
                },
                tickOptions:{ 
                    fontSize:'10pt', 
                    fontFamily:'Tahoma', 
                    angle:-40
                }
             },
             yaxis: {
                rendererOptions:{
                    tickRenderer:$.jqplot.CanvasAxisTickRenderer
                },
                tickOptions:{ 
                    fontSize:'10pt', 
                    fontFamily:'Tahoma', 
                    angle: 30
                }
                 //label: "latency",
                 //labelRenderer: $.jqplot.CanvasAxisLabelRenderer,
             }
        },
    });

  };

  var plot_auto = function(elt_id, title, treshold) {
      var _get_url = function() {
         return "/" + elt_id + ".json?n=" + $("#last_n").val() + "&_dc=" + (new Date()).getTime() / 1000;
      };
      var _handler = function(data) {
        var lines = _.map(data.result, function(line) {
            return _.map(line, function(i) { return [i[0] * 1000, i[1]];});
        });
        $("#" + elt_id).empty();
        var p = plot(elt_id, lines, title, treshold);
        setTimeout(function(){
            $.get(_get_url(),
            function(data) {
               p.destroy();
               _handler(data);
            });
        }, 3000);
      };
      $.get(_get_url(), _handler);
  };


  $.jqplot.config.enablePlugins = true;
  plot_auto("pings", "Internet latency", 8000);
  plot_auto("cputemp", "CPU Temprature", 50);
});
