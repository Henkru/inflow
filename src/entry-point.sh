#!/bin/sh

[ -z "$INFLUX_HOST" ]  && echo "INFLUX_HOST is not specified" && exit 1
[ -z "$INFLUX_TOKEN" ]  && echo "INFLUX_TOKEN is not specified" && exit 1

TIMEOUT=${TIMEOUT:-60}
CONFIG_PATH=${CONFIG_PATH:-"/conf.d"}

echo "Waiting InfluxDB to be available..."
for CNT in $(seq $TIMEOUT); do
    wget $INFLUX_HOST -q -O - > /dev/null && break
    sleep 2
done

[ $CNT -ge $TIMEOUT ] && echo "Timeout reached" && exit 1

for f in $CONFIG_PATH/*.yml; do
    ./inflow.sh $f
done
