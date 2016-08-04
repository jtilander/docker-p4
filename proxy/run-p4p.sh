#!/bin/bash

echo "Running exec /usr/bin/p4p -r $P4CACHE -p $P4PORT -t $P4TARGET"
exec /usr/bin/p4p -r $P4CACHE -p $P4PORT -t $P4TARGET
