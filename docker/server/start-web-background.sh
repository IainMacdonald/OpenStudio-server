#!/usr/bin/env bash

echo "Waiting for Mongo to start"
/usr/local/bin/wait-for-it --strict -t 0 db:27017

echo "Waiting for Redis to start"
/usr/local/bin/wait-for-it --strict -t 0 queue:6379

#cd /opt/openstudio/server && bundle exec rake environment resque:work
echo "Startup two resque workers"
cd /opt/openstudio/server && COUNT=6 bundle exec rake environment resque:workers
