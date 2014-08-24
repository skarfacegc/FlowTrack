Notes while I'm coding
-----------------------


Main graph call stack:
- getGraphData()  graphs.js   Sets load timer
    - /json/LastHourTotals/<arg> -> FT::FlowTrackWeb::Main::aggergateBucketJSON(arg)
        - FT::FlowTrack::getSumBucketsForLast( 120, 180 )  ~~** This needs to take variable args **~~ DONE


- Add ip pairs to getSumBucketsForTimeRange
- Add ip pairs to the getInternal/Ingress/Egress calls
- Possible re-factor to hash arguments?


~~need to refactor the 3 foreach loops in getSumBuckets~~ DONE  Different approach than above, but the goal was met.  :)

~~Simplify flow storage by siwtching to ArrayTupleFetch
http://atrueswordsman.wordpress.com/2009/07/10/perl-dbi-batch-uploadinsert-row-wise-vs-column-wise-binding/~~ DONE