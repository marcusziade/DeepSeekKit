# Build stage
FROM swift:5.9-jammy as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files
COPY Package.swift Package.resolved ./

# Copy source code
COPY Sources ./Sources
COPY Tests ./Tests

# Build the project
RUN swift build -c release --disable-sandbox

# Runtime stage
FROM swift:5.9-jammy-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libcurl4 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary
COPY --from=builder /app/.build/release/deepseek-cli /usr/local/bin/

# Create non-root user
RUN useradd -m -s /bin/bash deepseek
USER deepseek
WORKDIR /home/deepseek

# Default command
ENTRYPOINT ["deepseek-cli"]
CMD ["--help"]