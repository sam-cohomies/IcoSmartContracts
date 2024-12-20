# Use an ARM64-compatible base image
FROM rust:latest as builder

# Install required dependencies
RUN apt-get update && apt-get install -y curl git

# Install Foundry using Foundryup
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup

# Set up environment
ENV PATH="/root/.foundry/bin:$PATH"

# Set working directory to /app
WORKDIR /app

# Expose default command
CMD ["foundryup"]