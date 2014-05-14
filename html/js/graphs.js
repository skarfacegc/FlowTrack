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

function getGraphData()
{
    $.ajax({
        url:"/json/LastHourTotals/1",
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
    var html_slug = "";
    $("#talker_grid").empty();

    $.each(talkers, function() {

        div_count++;

        if(div_count == 1)
        {
            html_slug = html_slug + "<div id='"+div_count+"' class='section group'>";
        }

        html_slug = html_slug + "<div class='content gridItem col span_1_of_3'>"+
        "<div class='internal_ip_name'>"+ this.internal_ip_name +" &nbsp;</div>" +
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
