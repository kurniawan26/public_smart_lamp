#!/bin/sh
set -eu

echo "[starter] Running database migrations and optional demo initialization..."
bin/smart_city_lamp eval 'SmartCityLamp.Release.setup()'

echo "[starter] Starting Smart City Lamp on port ${PORT:-4000}..."
exec bin/smart_city_lamp start
