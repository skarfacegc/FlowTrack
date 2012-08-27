#!/usr/bin/env perl
#
# Copyright 2012 Andrew Williams <andrew@manor.org>
#
# Start services
#   Main Collection Routines start in FT/FlowCollector.pm
#
# For Documentation & License see the README
#
use strict;
use warnings;

use FT::FlowCollector;

FT::FlowCollector::CollectorStart();
