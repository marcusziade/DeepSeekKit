# Use the official Swift image
FROM swift:5.9-jammy

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Package files first for better caching
COPY Package.swift Package.resolved* ./

# Copy source files
COPY Sources ./Sources
COPY Tests ./Tests

# Build the project
RUN swift build -c release

# Create a minimal runtime image
FROM swift:5.9-jammy-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

# Copy built binaries from builder
COPY --from=0 /app/.build/release/deepseek-cli /usr/local/bin/

# Set up non-root user
RUN useradd -m -s /bin/bash deepseek
USER deepseek
WORKDIR /home/deepseek

# Set default command
CMD ["deepseek-cli", "--help"]