#!/bin/bash

# Script to synthesize, deploy, or destroy AWS CDK stacks with stack dependencies
# Usage: ./demo-cdk.sh <action>
# Example for deploy: ./demo-cdk.sh deploy
# Example for destroy: ./demo-cdk.sh destroy
# Example to only synth: ./demo-cdk.sh synth
# Example to clean: ./demo-cdk.sh clean

ACTION=$1

# Check for action parameter
if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <action>"
  echo "action can be 'synth', 'deploy', or 'destroy'"
  exit 1
fi

# Clean function to remove generated files
clean_resources() {
  echo "Cleaning up resources..."
  rm -rf cdk.out
  rm -rf node_modules
  rm -rf .cdk.staging
  rm -rf cdk.context.json
  echo "Cleanup complete."
}

# Clean command
if [[ "$ACTION" == "clean" ]]; then
  clean_resources
  exit 0
fi

# Run CDK synth once for all stacks
if [[ "$ACTION" == "synth" || "$ACTION" == "deploy" ]]; then
  # Clean resources before starting
  clean_resources
  
  npm install
  echo "Running CDK bootstrap"
  cdk bootstrap

  echo "Running CDK synth for all stacks..."
  if cdk synth; then
    echo "CDK synth successful!"
    if [[ "$ACTION" == "synth" ]]; then
      exit 0
    fi
  else
    echo "CDK synth failed. Exiting."
    exit 1
  fi
fi

# Deploy or destroy all stacks in the app
if [[ "$ACTION" == "deploy" ]]; then
  echo "Starting CDK deployment for all stacks in the app"
  if cdk deploy --all --require-approval never; then
    echo "Deployment successful for all stacks in the app"
  else
    echo "Deployment failed. Attempting to clean up resources by destroying all stacks..."
    cdk destroy --all --force --verbose
    exit 1
  fi
elif [[ "$ACTION" == "destroy" ]]; then
  echo "Starting CDK destroy for all stacks in the app"
  cdk destroy --all --force --verbose
  echo "Destroy complete for all stacks in the app"
else
  echo "Invalid action: $ACTION. Please use 'synth', 'deploy', 'destroy', or 'clean'."
  exit 1
fi
