# Use an ARM64-compatible base image
FROM rust:latest as builder

# Install required dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-venv \
    python3-pip && \
    apt-get clean

# Create a virtual environment and install Slither
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir slither-analyzer

# Add the virtual environment to PATH
ENV PATH="/opt/venv/bin:$PATH"

# Install Foundry using Foundryup
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup

# Set up environment
ENV PATH="/root/.foundry/bin:$PATH"

# Set working directory to /app
WORKDIR /app

# Expose default command
CMD ["foundryup"]