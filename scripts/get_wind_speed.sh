#!/bin/bash

# This script gets the current wind speed for a given zip code.

# Usage: ./get_wind_speed.sh <zip_code> [-today]
# Example: ./get_wind_speed.sh 90210
# Example: ./get_wind_speed.sh 90210 -today

ZIP_CODE=""
TODAY_FLAG=false
THRESHOLD_SPEED=15
THRESHOLD_SET=false

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -today)
      TODAY_FLAG=true
      ;;
    -t)
      THRESHOLD_SPEED="$2"
      THRESHOLD_SET=true
      shift
      ;;
    *)
      ZIP_CODE="$1"
      ;;
  esac
  shift
done

if [ -z "$ZIP_CODE" ]; then
  echo "Usage: $0 <zip_code> [-today] [-t <threshold_speed>]"
  exit 1
fi

WEATHER_DATA=$(curl -s "https://wttr.in/$ZIP_CODE?format=j1")

if [ -z "$WEATHER_DATA" ]; then
  echo "Failed to get weather data. Please check your internet connection or the zip code."
  exit 1
fi

if $TODAY_FLAG; then
  echo "$WEATHER_DATA" | jq -r '.weather[0].hourly[] | "\(.time) \(.windspeedMiles)"' | while read -r time wind; do
    if ! $THRESHOLD_SET || (( $(echo "$wind > $THRESHOLD_SPEED" | bc -l) )); then
      hour=$((time / 100))
      if (( hour == 0 )); then
        formatted_time="12:00 AM"
      elif (( hour < 12 )); then
        formatted_time="$hour:00 AM"
      elif (( hour == 12 )); then
        formatted_time="12:00 PM"
      else
        formatted_time="$((hour - 12)):00 PM"
      fi
      echo "$formatted_time - $wind mph"
    fi
  done
else
  WIND_SPEED=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].windspeedMiles')

  if [ -z "$WIND_SPEED" ] || [ "$WIND_SPEED" == "null" ]; then
    echo "Could not find wind speed for the given zip code. Please check the zip code."
    exit 1
  fi

  echo "Current wind speed in $ZIP_CODE is $WIND_SPEED mph."
fi
