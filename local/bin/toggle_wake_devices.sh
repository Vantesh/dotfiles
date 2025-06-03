#!/bin/bash

WAKE_DEVICES=("XHC" "RP01" "RP05" "RP09" "PEG0")

if [[ "$1" == "enable" ]]; then
    TARGET_STATE="*disabled"
    DESIRED_ACTION="enable"
elif [[ "$1" == "disable" ]]; then
    TARGET_STATE="*enabled"
    DESIRED_ACTION="disable"
else
    exit 1
fi

CURRENT_STATES=$(cat /proc/acpi/wakeup)

for dev in "${WAKE_DEVICES[@]}"; do
    CUR_STATE=$(echo "$CURRENT_STATES" | grep "^$dev" | awk '{print $3}')
    # Only toggle if current state is the opposite of desired
    if [[ "$CUR_STATE" == "$TARGET_STATE" ]]; then
        echo "$dev" > /proc/acpi/wakeup 2>/dev/null || true
        # Optional: log for debugging
        # echo "Toggled $dev to $DESIRED_ACTION"
    fi
done
