# Nestr Key Agent

Nestr Key Agent is a secure and efficient solution for storing and retrieving cryptographic keys, designed specifically for nostr applications. It provides a background service that securely manages keys, accessible via gRPC, ensuring that your sensitive key material is handled with the utmost care and security.

## Features

- **Secure Key Storage**: Keys are encrypted using AES-256 in GCM mode, with key derivation using scrypt.
- **Cross-Platform Support**: Runs as a background service on Windows, macOS, and Linux.
- **gRPC Interface**: Provides a modern, efficient gRPC API for key management operations.
- **Caching Mechanism**: Implements a secure, time-limited caching system to balance security and performance.
- **Language Support**: 
  - Go implementation available out-of-the-box.
  - TypeScript implementation coming soon (will be linked here when available).

## Security

- Keys are encrypted using AES-256 in Galois/Counter Mode (GCM).
- Key derivation is performed using scrypt with the following parameters:
  - N = 32768
  - r = 8
  - p = 1
- Each key is stored with a unique salt.
- In-memory caching is time-limited to reduce exposure.

## Installation
*The following is just an outline and is not currently accurate, will be updated before release*

### Windows

1. Build the project:
go build
2. Install as a service:
nestr-key-agent.exe install

### macOS

1. Build the project:
go build
2. Run the installation script:
./install_mac.sh

### Linux

1. Build the project:
go build
2. Run the installation script:
./install.sh

## Usage

The Nestr Key Agent runs as a background service and exposes a gRPC interface for key management operations. Client code for interacting with the service can be found in the `/lib/agent` folder.

### Go Client Example

```go
import "github.com/HORNET-Storage/nestr-key-agent/lib/agent"

client, err := agent.NewKeyAgentClient()
if err != nil {
 log.Fatalf("Failed to create client: %v", err)
}
defer client.Close()

// Store a key
err = client.StoreKey("my-key", "private-key-data", "secure-passphrase")
if err != nil {
 log.Fatalf("Failed to store key: %v", err)
}

// Retrieve a key
key, err := client.RetrieveKey("my-key", "secure-passphrase")
if err != nil {
 log.Fatalf("Failed to retrieve key: %v", err)
}
```

Note: This software is provided "as is", without warranty of any kind. Use at your own risk.