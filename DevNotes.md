Notes while I'm coding
-----------------------


Main graph call stack:
- getGraphData()  graphs.js   Sets load timer
    - /json/LastHourTotals/<arg> -> FT::FlowTrackWeb::Main::aggergateBucketJSON(arg)
        - FT::FlowTrack::getSumBucketsForLast( 120, 180 )  ~~** This needs to take variable args **~~ DONE


- Add ip pairs to getSumBucketsForTimeRange
- Add ip pairs to the getInternal/Ingress/Egress calls
- Possible re-factor to hash arguments?

- need to refactor the 3 foreach loops in getSumBuckets
    - extract logic into single method
    - should allow the same hash to be passed repeatedly (allows for updating totals)
    - DS will need to look roughly like
    
```
        totals
            [  Array of flows/bytes/packets ]
        ingress   
            [  Array of flows/bytes/packets ]
        egress
            [  Array of flows/bytes/packets ]
        internal
            [  Array of flows/bytes/packets ]
            
```


~~Simplify flow storage by siwtching to ArrayTupleFetch
http://atrueswordsman.wordpress.com/2009/07/10/perl-dbi-batch-uploadinsert-row-wise-vs-column-wise-binding/~~ DONE