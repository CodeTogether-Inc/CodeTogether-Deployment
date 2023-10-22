#!/bin/sh

echo "Triggering launch of Cassandra..."
/usr/local/bin/docker-entrypoint.sh &

echo "Waiting for Cassandra to be ready (may take a minute)..."
until $(nodetool status 2>&1 | grep "UN" > /dev/null); do 
  sleep 5; 
done
sleep 30;

echo "Cassandra is running."
set +x

echo "Creating schema in Cassandra (if needed)..."
/opt/cassandra/bin/cqlsh -u cassandra -p cassandra -f /scripts/init.sql

echo "Confirming schema exists..."
DBCREATED=`/opt/cassandra/bin/cqlsh -u cassandra -p cassandra -f /scripts/init.sql 2>&1 | grep "already exists" | wc -l`
if [ $DBCREATED -eq 0 ]; then
  echo "Error: schema creation failed"
  exit 1
fi

echo "Cassandra is ready."
touch /tmp/cassandra-ready

while true; do sleep 1000; done
