![Picture](http://flowtrack.info/images/screenshot.png)

[![Build Status](https://travis-ci.org/skarfacegc/FlowTrack.svg?branch=feature%2FgridGraph)](https://travis-ci.org/skarfacegc/FlowTrack)

About
-----
FlowTrack is designed to listen for and log netflow (v5) traffic.  My goal with it is to make installation as easy as
possible.  There's no need to configure an external webserver or database.  When you run FlowTracker a small 
webserver is started, and a netflow collector is started.

Initially I'm focusing on feature set and simplicity of installation.  Scalability is a secondary concern right now.
I'm testing with very light traffic.  In otherwords, this will likely melt under high load.  If you do try running this
under high load, let me know how it goes. 

I'd love to know if you're using it. Questions?  Bugs? Feature Requests?  Open them as issues on [GitHub](https://github.com/skarfacegc/FlowTrack/)

Take a look at the roadmap (below) for a rough idea of status.

Installation & Use
------------------

### Requirements
(I will likely add new stuff to this list, such as rrdtool):
- Working SQLite Install
- Some source of flow data (rflowd from dd-wrt works great)
    - May or may not work with ipfix
- Perl 5.10+  (tested on 5.16.1)
    - Mojolicious
    - Net::Server
    - Log::Log4perl
    - YAML
    - DBI
    - DBD::SQLite
    - Net::Flow
    - Net::IP
    - DateTime
    - Net::DNS
    - List::Util
    - Devel::Cover (for UT coverage)
    - Test::Pretty (nicer output for prove)
    
- Something to send you v5 netflow data (rflowd on dd-wrt works great!)
- a working SQLite installation

### Installing
I recommend cloning the repository to make getting updates etc. easier.

    git clone git://github.com/skarfacegc/FlowTrack.git

### Configuration
**flowTrack.conf**

    # Port to read for netflow
    netflow_port: 2055

    # Name of the database
    database_name: FlowTrack.sqlite

    # What do you consider your internal network
    # Not used in version 0.01  Will be used to determine ingress/egress
    internal_network: 192.168.1.0/24

    # Where to write data (database/logs/etc)
    data_dir: ./Data

    # How many seconds to keep raw flows around
    # Defaults to a half day
    purge_interval: 43200

    # Port for the webserver
    web_port: 5656

    # Log4Perl Configuration file
    logging_conf: flowTrackLog.conf

    # Location of pid files
    pid_files: ./log

Run FlowTrack.pl

    ./FlowTrack.pl [--config=/location/of/config/file.conf]

Logging is configured in flowTrackLog.conf Defaults to logging in ./log


### URLs
Point your browser at [http://localhost:5656/](http://localhost:5656/)
The following URLs do things:

- [http://localhost:5656/](http://locallhost:5656/) <br>
   This is the main page  (currently points to /FlowsForLast/1)
- [http://localhost:5656/FlowsForLast/1](http://localhost:5656/FlowsForLast/1) <br>
   Shows flows for the last 1 minute.  Change the 1 to another number to expand your time range.
- [http://localhost:5656/json/FlowsForLast/1](http://localhost:5656/json/FlowsForLast/1)<br>
   Raw data for the above

### Tuning
You can tune the collector pool by twiddling these values in **FT/FlowCollector.pm**
```perl
    min_spare_servers => 3,
    max_spare_server  => 5,
    max_servers       => 5,
    max_requests      => 5,
```
Release Notes
--------------
0.0.1
- Initial release.
- Major components work

  - Collector
  - Webserver

- Single table view of recent flows (no graphs etc)


Libraries Used
-------------------------

- [Net::Server](http://search.cpan.org/~rhandom/Net-Server-2.006/lib/Net/Server.pod) - handles the collection loop
- [log4perl](http://mschilli.github.com/log4perl/) - An excellent log4j style system for perl
- [Mojolicious](http://mojolicio.us/) - webserver and web framework
- [JQuery](http://jquery.com/) - JS Framework
- [DataTables](http://datatables.net/) - Table Viewer
- [SQLite](http://www.sqlite.org/) - SQLite for the database
- [FlotCharts](http://www.flotcharts.org/) - jQuery graphing package
- [ResponsiveGrid](http://www.responsivegridsystem.com/) - Responsive Grid

Planned Roadmap
----------------

- **Release 0.0.1 09|09|2012**
    - ~~Data collection~~
    - ~~Webserver~~
    - ~~Basic list view~~
    - ~~Sane logging~~
    - ~~Daemonize~~
    - ~~Kill Children on signal~~
    - ~~Fix the no-data request in Main.pm  (browser shouldn't hang on no data)~~
    - ~~Check for dead procs~~
    - ~~Docs~~
    - ~~Cleanup dead files~~
- **Release 0.0.2**
    - ~~Active Talker Grid~~
    - ~~DNS Resolution~~
    - ~~grid change indicators~~
    - ~~Main Ingress/Egress Graph~~
    - Active Talker Graphs
    - Link Pair grid items to table view
- **Future**
    - Per host detail page
    - UI Driven time range selection
    - IPFIX support  (Net::Flow supports it, I just don't have an easy IPFIX 
      source.  Gonna look at Yaf at some pt)
    - HTTP Auth
    - Refactor config loading (not happy with the current solution)




License
-------
     Copyright (c) 2012, andrew@manor.org
     All rights reserved.
     
     Redistribution and use in source and binary forms, with or without
     modification, are permitted provided that the following conditions are met: 
     
     1. Redistributions of source code must retain the above copyright notice, this
        list of conditions and the following disclaimer. 
     2. Redistributions in binary form must reproduce the above copyright notice,
        this list of conditions and the following disclaimer in the documentation
        and/or other materials provided with the distribution. 
     
     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
     ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
     WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
     DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
     ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
     (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
     ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
     (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
     SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
     
     The views and conclusions contained in the software and documentation are those
     of the authors and should not be interpreted as representing official policies, 
     either expressed or implied, of the FreeBSD Project.



