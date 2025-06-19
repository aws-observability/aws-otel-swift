# Demo Applications

This directory contains the set of demo app submodules for AWS OpenTelemetry Swift.

## Requirements

- AWS CDK v2 installed
- An AWS account with appropriate permissions to deploy CDK (CloudFormation) stacks
- Docker and Docker Compose (for local otel-collector setup)
- Xcode (latest version recommended)

## Running the demo app with Xcode

Note: If you would like to use the OpenTelemetry Collector for local development and testing, refer to next section to get your environment setup.
1. Open Xcode
2. Go to File > Open...
3. Navigate to demo app directory
4. Select the `.xcodeproj` file and click "Open"
5. Refer to the `README` file for the demo app to complete setup
6. Click the play button at the top left to build and run the app in the simulator 

## Local Development with OpenTelemetry Collector

1. Modify the OpenTelemetry configuration to point to your local collector endpoints instead of AWS services.
    ```
    let config = AwsOpenTelemetryConfig(
        rum: RumConfig(
            ...
            overrideEndpoint: EndpointOverrides(
                logs: "http://localhost:4318/v1/logs",
                traces: "http://localhost:4318/v1/traces"
            ),
            ...
        ),
        ...
    )
    ```
2. Make sure you have Docker and Docker Compose installed on your system.

3. Create an output directory for the collector logs and traces:
    ```bash
    mkdir -p out
    ```
   
4. Start the OpenTelemetry Collector using Docker Compose:
    ```bash
    docker-compose up
    # or with newer Docker versions:
    docker compose up
    ```

5. The collector will be available at:
   - OTLP gRPC: `localhost:4317`
   - OTLP HTTP: `localhost:4318`

6. Telemetry data will be written to the following files:
   - Traces: `./out/traces.txt`
   - Logs: `./out/logs.txt`
   
7. To view the telemetry data in real-time:
    ```bash
    # For traces
    tail -f out/traces.txt
   
    # For logs
    tail -f out/logs.txt
    ```

8. To stop the collector:
    ```bash
    docker-compose down
    # or with newer Docker versions:
    docker compose down
    ```

### Troubleshooting common issues

- **No data is being printed in the Xcode logs even if `debug` is `true`**
    - This indicates an issue with the SDK initialization. Review the SDK logs in the Xcode debug console to identify the error. 

- **No data collected by the OpenTelemetry Collector**
    - Verify that the endpoints have been overriden in your SDK configurations.
    - Verify there are no internet connection issues.
    
- **No data written to text files**
    - Run `ls -l file.sh` to verify the system has access to write to the text files. If the value in the first column for the text files contains `w`, this indicates that the system has at least write permissions. If there is no `w`, run `chmod +w filename` to add write permissions. 
