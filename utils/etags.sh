#!/bin/sh
find . -name "*.pl" -o -name "*.pm" -o -name "*.t" |xargs etags -a -l perl
