Start of a netflow and snmp monitoring tool

Designed for use on a small/home network.  Testing against dd-wrt

Got a prototype mostly working (at least for collection).  Performance
could be better, and the code is fairly nasty in places (full of
experimentation).  That is the state of the master branch.  Collects,
and pushes into a database.

I'm currently working in the cleanup branch.  Making the database
access saner, cleaning up some nasty bits, etc.  So far

- Basic test module (t/selftest.pl)
- Cleaned up some of the DB code (still in progress)
  - Big thing was the insert loop.
- Some directory structure cleanup

I've been using flow-tools for testing.  Haven't figured out how to
send a sustained flows per second to do actual performance
measurement.  (short of looping small flow-gen batches)

---
Installation
------------
You'll need the following perl modules (cleanup branch 1.17.12):

- POE
- POE::Component::Server:HTTP (webserver currently commented out, but module is still used)
- POE::Wheel::Run
- Net::Flow
- Net::IP
- Log::Message::Simple
- HTTTP::Status (webserver currently commented out)
- DBD::SQLite
 
Running
-------
1. Download the zip.  
2. Run FlowTrack.pl  
3. Send flows to port 2055
4. Flows get written to FlowTrack.sqlite in the directory where you ran FlowTrack.pl



