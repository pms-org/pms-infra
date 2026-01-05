#!/usr/bin/env bash

set -e

# Try to auto-detect AWS profile
PROFILE="${AWS_PROFILE:-default}"
REGION="$(aws configure get region --profile "$PROFILE")"

if [ -z "$REGION" ]; then
  REGION="us-east-1"
fi

export AWS_PROFILE="$PROFILE"
export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"

echo "Using AWS_PROFILE=$AWS_PROFILE"
echo "Using AWS_REGION=$AWS_REGION"

aws sts get-caller-identity >/dev/null || {
  echo "❌ AWS credentials not valid"
  exit 1
}

echo "✅ AWS environment ready"
