// talkerData will hold data about the talker grid
talkerData = new Object();
talkerData.lastUpdate = new Object();
talkerData.ipPairs = new Object();

var minutes_back = 360;
var bucket_size = 2;


function onGraphDataReceived(series) {
    // This is the flot charts options struct
    var options = {
        lines: {
            show: true
        },
        series: {
            lines: {
                lineWidth: 3
            },
        },
        xaxes: [{
            mode: "time",
        }, ],
        yaxes: [{
            tickFormatter: function(val, axis) {
                if (val > 1000000)
                    return (val / 1000000).toFixed(axis.tickDecimals) + " MB";
                else if (val > 1000)
                    return (val / 1000).toFixed(axis.tickDecimals) + " kB";
                else
                    return val.toFixed(axis.tickDecimals) + " B";
            }
        }, ],
        grid: {
            borderColor: "#E6E6E6",
        }
    };


    $.plot($("#topGraph"), [series.ingress_bytes, series.egress_bytes], options);
}

function getMainGraphData() {
    $.ajax({
        url: "/json/GraphTotalsForLast/" + minutes_back + "/" + bucket_size,
        method: 'GET',
        dataType: 'json',
        success: onGraphDataReceived
    });

}

function getTalkerData() {
    $.ajax({
        url: '/json/topTalkers/21',
        type: 'GET',
        dataType: 'json',
        success: onTalkerDataReceived
    });

}

function isDemoMode()
{
    return window.location.href.match(/[\?&amp;]demo=1/);
}

function drawTalkerGraphs() {

    for (var pair_id in talkerData.ipPairs)
    {

    // This bit of nastiness is to create a closure to pass the pair_id into the 
    // pair graph rendering routine
    (function(pair_id){
        $.ajax({
            url: '/json/TalkerGraphTotalsForLast/' + 
            talkerData.ipPairs[pair_id][0] + "/" + talkerData.ipPairs[pair_id][1] +
            "/" + minutes_back + "/" +bucket_size,
            type: 'GET',
            dataType: 'json',
            success: function(json) {
                onTalkerGraphDataReceived(json, pair_id);
            }
        });
    })(pair_id);
}
}


function onTalkerGraphDataReceived(graph_data, pair_id) {

    // Figure out the max value for graphs
    var max_egress = Math.max.apply(null, graph_data["egress_bytes"]);
    var max_ingress = Math.max.apply(null, graph_data["ingress_bytes"]);
    var maxValue = 0;
    if( max_egress > max_ingress)
    {
        maxValue = max_egress;
    }
    else
    {
        maxValue = max_ingress;
    }

    $('#'+pair_id).sparkline(graph_data["egress_bytes"], {height: "50px", width: "90%", 
        lineColor: "#BAD8F8", fillColor: false, chartRangeMax: maxValue, spotColor: false, 
        minSpotColor: false, maxSpotColor: false, lineWidth: 2});

    $('#'+pair_id).sparkline(graph_data["ingress_bytes"], {height: "50px", width: "90%", 
        lineColor: "#E2BF43", fillColor: false, composite: true, chartRangeMax: maxValue,
        spotColor: false, minSpotColor: false, maxSpotColor: false, lineWidth: 2});;


}

function onTalkerDataReceived(talkers) {
    var div_count = 0;
    var grid_count = 0;
    var html_slug = "";
    var grid_change = "";
    $("#talker_grid").empty();

    $.each(talkers, function() {

        div_count++;
        grid_count++;

        // Check to see if this pair is in the current list.
        // also check to see if position has changed.
        grid_change = "";
        if (this.id in talkerData.lastUpdate) {
            if (grid_count < talkerData.lastUpdate[this.id]) {
                grid_change = "fa-arrow-circle-down";
            } else if (grid_count == talkerData.lastUpdate[this.id]) {
                grid_change = "";
            } else {
                grid_change = "fa-arrow-circle-up";
            }
        } else {
            grid_change = "fa-plus-circle";
        }

        // record the existance and position of this talker pair
        // used to highlight new talkers and to show talker movement
        talkerData.lastUpdate[this.id] = grid_count;
        talkerData.ipPairs[this.id] = [this.internal_ip, this.external_ip];

        if (div_count == 1) {
            html_slug = html_slug + "<div id='" + div_count + "' class='section group'>";
        }

        var internal_name = !isDemoMode() ? this.internal_ip_name : "your.network.com";
        var internal_ip = !isDemoMode() ? this.internal_ip : "192.16.1.254";
        var external_name = !isDemoMode() ? this.external_ip_name : "google.com";
        var external_ip = !isDemoMode() ? this.external_ip : "74.125.228.104";


        html_slug = html_slug + "<div class='content gridItem col span_1_of_3'>" +
        "<div class='internal_ip_name'>" + internal_name + " &nbsp;</div>" +
        "<div class='external_ip_name'>&nbsp;" + external_name + "</div>" +
        "<span class='change_indicator fa " + grid_change + " fa-fw'></span>" +
        "<span class='internal_ip'>" + internal_ip + "</span>" +
        "<span class='external_ip'>" + external_ip + "</span>" +
        "<div id='" + this.id + "' class='talker_graph'>Loading ...</div>" +
        "</div>";

        if (div_count == 3) {
            div_count = 0;
            html_slug = html_slug + "</div>";
        }

        

    });


drawTalkerGraphs();
$("#talker_grid").append(html_slug);
}