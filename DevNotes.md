Notes while I'm coding
-----------------------


Main graph call stack:
- getGraphData()  graphs.js   Sets load timer
    - /json/LastHourTotals/<arg> -> FT::FlowTrackWeb::Main::aggergateBucketJSON(arg)
        - FT::FlowTrack::getSumBucketsForLast( 120, 180 )  ** This needs to take variable args **