#!/bin/bash

MODEL_PATH="cust-001/fabric-cicd-semantic-model.SemanticModel"

echo '{ "displayName": "fabric-cicd-semantic-model", "type": "SemanticModel", "definition": { "parts": [' > model_payload.json

FIRST=true

for file in $(find $MODEL_PATH -type f); do
  CONTENT=$(base64 -w 0 "$file")
  REL_PATH=$(realpath --relative-to=$MODEL_PATH "$file")

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo ',' >> model_payload.json
  fi

  echo "{
    \"path\": \"$REL_PATH\",
    \"payload\": \"$CONTENT\",
    \"payloadType\": \"InlineBase64\"
  }" >> model_payload.json
done

echo '] } }' >> model_payload.json
