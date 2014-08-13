// talkerData will hold data about the talker grid
talkerData = new Object();
talkerData.lastUpdate = new Object();




function onGraphDataReceived(series)
{
    // This is the flot charts options struct
    var options = {
                    lines: { show: true },
                    xaxes: 
                    [
                        {
                            mode: "time",
                        },
                    ],
                    yaxes: 
                    [
                        {
                            tickFormatter: function (val,axis)
                            {
                                if (val > 1000000)
                                  return (val / 1000000).toFixed(axis.tickDecimals) + " MB";
                                else if (val > 1000)
                                  return (val / 1000).toFixed(axis.tickDecimals) + " kB";
                                else
                                  return val.toFixed(axis.tickDecimals) + " B"; 
                            }
                        },
                    ],
                    grid: {
                        borderColor: "#E6E6E6",
                    }
                };

    $.plot($("#topGraph"), [series.ingress_bytes, series.egress_bytes], options);
}

function getMainGraphData()
{
    $.ajax({
        url:"/json/GraphTotalsForLast/360/2",
        method: 'GET',
        dataType: 'json',
        success: onGraphDataReceived
    });

}


function getTalkerData()
{
    $.ajax({
      url: '/json/topTalkers/21',
      type: 'GET',
      dataType: 'json',
      success: onTalkerDataReceived
    });

}

function onTalkerDataReceived(talkers)
{
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
        if(this.id in talkerData.lastUpdate)
        {
            if(grid_count < talkerData.lastUpdate[this.id])
            {   
                grid_change = "fa-arrow-circle-down";
            }
            else if(grid_count == talkerData.lastUpdate[this.id])
            {
                grid_change = "";
            }
            else
            {
                grid_change = "fa-arrow-circle-up";
            }
        }
        else
        {
            grid_change = "fa-plus-circle";
        }

        // record the existance and position of this talker pair
        // used to highlight new talkers and to show talker movement
        talkerData.lastUpdate[this.id] = grid_count;

        console.log("GC: "+ grid_change);


        if(div_count == 1)
        {
            html_slug = html_slug + "<div id='"+div_count+"' class='section group'>";
        }

        html_slug = html_slug + "<div class='content gridItem col span_1_of_3'>"+
        "<div class='internal_ip_name'>"+ this.internal_ip_name +" &nbsp;</div>" +
        "<span class='change_indicator fa "+ grid_change + " fa-fw'></span>"+
        "<span class='internal_ip'>" + this.internal_ip + "</span>" + 
        "<span class='external_ip'>" + this.external_ip + "</span>" +
        "<div class='external_ip_name'>&nbsp;"+ this.external_ip_name +"</div>" +
        "<div id='" + this.id +"' class='talkerGraph'></div>" +
        "</div>";

        if(div_count == 3)
        {
            div_count = 0;
            html_slug = html_slug + "</div>";
        }
    });

    $("#talker_grid").append(html_slug);
}
