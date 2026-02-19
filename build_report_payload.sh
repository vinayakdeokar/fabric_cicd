#!/bin/bash

REPORT_PATH="cust-001/Sales_Report_vinayak_001.Report"

echo '{ "displayName": "Sales_Report_vinayak_001", "type": "Report", "definition": { "parts": [' > report_payload.json

FIRST=true

for file in $(find $REPORT_PATH -type f); do
  CONTENT=$(base64 -w 0 "$file")
  REL_PATH=$(realpath --relative-to=$REPORT_PATH "$file")

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo ',' >> report_payload.json
  fi

  echo "{
    \"path\": \"$REL_PATH\",
    \"payload\": \"$CONTENT\",
    \"payloadType\": \"InlineBase64\"
  }" >> report_payload.json
done

echo '] } }' >> report_payload.json
