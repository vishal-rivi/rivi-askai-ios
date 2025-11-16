# Binary Repository Setup Guide

## Overview

This guide helps you create the binary distribution repository for RiviAskAI.

## Repository Structure

You'll need 3 repositories:

```
1. RiviAskAI (Private)           - Source code (this repo)
2. RiviAskAI-Binary (Private)    - Binary distribution
3. RiviAskAI-Examples (Optional) - Example projects
```

---

## Step 1: Create RiviAskAI-Binary Repository

### 1.1 Create New GitLab Repository

```bash
# On GitLab:
# - Create new repository: RiviAskAI-Binary
# - Set visibility: Private
# - Don't initialize with README
```

### 1.2 Clone and Setup

```bash
# Clone the new repository
git clone git@gitlab.com:your-org/RiviAskAI-Binary.git
cd RiviAskAI-Binary

# Create Package.swift
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RiviAskAI",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "RiviAskAI",
            targets: ["RiviAskAI"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "RiviAskAI",
            url: "https://your-server.com/frameworks/RiviAskAI-1.0.0.xcframework.zip",
            checksum: "REPLACE_WITH_ACTUAL_CHECKSUM"
        )
    ]
)
EOF

# Create README
cat > README.md << 'EOF'
# RiviAskAI

AI-powered search and filtering for iOS applications.

## Installation

### Swift Package Manager

Add to your project:

1. File → Add Package Dependencies
2. Enter URL: `https://gitlab.com/your-org/RiviAskAI-Binary.git`
3. Select version: `1.0.0` or later

Or add to `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://gitlab.com/your-org/RiviAskAI-Binary.git",
        from: "1.0.0"
    )
]
```

## Quick Start

```swift
import RiviAskAI

let response = try await RiviAskAI.performAskAIRequest(
    query: "4 star hotels near airport",
    searchId: "your-search-id",
    queryType: .hotel,
    currency: "USD",
    destination: "Dubai",
    origin: "New York",
    authToken: "your-token"
)

print(response.chips)
```

## Documentation

See [complete documentation](https://docs.yourcompany.com) for detailed usage.

## Support

- Email: support@yourcompany.com
- Issues: https://gitlab.com/your-org/RiviAskAI-Binary/issues

## License

Proprietary - Copyright © 2024 Your Company
EOF

# Commit and push
git add .
git commit -m "Initial binary package setup"
git push origin main
```

---

## Step 2: Create RiviAskAI-Examples Repository

### 2.1 Create New GitLab Repository

```bash
# On GitLab:
# - Create new repository: RiviAskAI-Examples
# - Set visibility: Private (or Public if you want)
# - Don't initialize with README
```

### 2.2 Move Example Project

```bash
# From your RiviAskAI source repo
cd /path/to/RiviAskAI

# Clone examples repo
git clone git@gitlab.com:your-org/RiviAskAI-Examples.git ../RiviAskAI-Examples

# Copy example project
cp -r RiviAskAIExample ../RiviAskAI-Examples/

# Copy documentation
cp README.md ../RiviAskAI-Examples/
cp COMPONENT_GUIDE.md ../RiviAskAI-Examples/

# Go to examples repo
cd ../RiviAskAI-Examples

# Update Package.swift in example to use binary
# (See Step 2.3 below)
```

### 2.3 Update Example to Use Binary Package

Edit `RiviAskAIExample/RiviAskAIExample.xcodeproj/project.pbxproj` or use Xcode:

1. Open `RiviAskAIExample.xcodeproj` in Xcode
2. Remove local package reference
3. Add binary package:
   - File → Add Package Dependencies
   - Enter: `https://gitlab.com/your-org/RiviAskAI-Binary.git`
   - Select version

### 2.4 Create Examples README

```bash
cat > README.md << 'EOF'
# RiviAskAI Examples

Example projects demonstrating RiviAskAI integration.

## Examples Included

### 1. RiviAskAIExample
Complete example showing:
- Package UI components
- Custom UI implementation
- SSE streaming
- Query type switching
- Language selection

## Setup

1. Clone this repository
2. Open `RiviAskAIExample/RiviAskAIExample.xcodeproj`
3. Update credentials in `ContentView.swift`:
   ```swift
   private let searchId = "your-search-id"
   private let authToken = "your-auth-token"
   ```
4. Build and run

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.9+

## Documentation

See [main documentation](../README.md) for complete API reference.
EOF

# Commit and push
git add .
git commit -m "Add RiviAskAI example project"
git push origin main
```

---

## Step 3: Setup File Hosting

You need to host the XCFramework zip files. Options:

### Option A: GitLab Releases (Recommended)

```bash
# After building XCFramework:
# 1. Go to GitLab → RiviAskAI-Binary → Releases
# 2. Create new release
# 3. Upload RiviAskAI-1.0.0.xcframework.zip
# 4. Get download URL
# 5. Update Package.swift with URL
```

### Option B: Your Own Server

```bash
# Upload to your server
scp build/RiviAskAI-1.0.0.xcframework.zip user@server.com:/var/www/frameworks/

# URL will be:
# https://your-domain.com/frameworks/RiviAskAI-1.0.0.xcframework.zip
```

### Option C: AWS S3

```bash
# Upload to S3
aws s3 cp build/RiviAskAI-1.0.0.xcframework.zip s3://your-bucket/frameworks/

# Make it accessible (with authentication if needed)
# URL: https://your-bucket.s3.amazonaws.com/frameworks/RiviAskAI-1.0.0.xcframework.zip
```

---

## Step 4: Update Package.swift with Real Values

After uploading XCFramework:

```swift
// RiviAskAI-Binary/Package.swift
.binaryTarget(
    name: "RiviAskAI",
    url: "https://your-actual-url.com/RiviAskAI-1.0.0.xcframework.zip",
    checksum: "actual-checksum-from-build-script"
)
```

---

## Step 5: Tag and Release

```bash
cd RiviAskAI-Binary
git add Package.swift
git commit -m "Release version 1.0.0"
git tag 1.0.0
git push origin main --tags
```

---

## Final Repository Structure

```
RiviAskAI/                          # Private - Source code
├── Sources/
├── Package.swift
├── build-xcframework.sh
└── release.sh

RiviAskAI-Binary/                   # Private - Binary distribution
├── Package.swift                   # Points to XCFramework
└── README.md

RiviAskAI-Examples/                 # Private/Public - Examples
├── RiviAskAIExample/
├── README.md
└── COMPONENT_GUIDE.md
```

---

## Client Access

### For Clients:

**Give access to:**
1. ✅ RiviAskAI-Binary (binary package)
2. ✅ RiviAskAI-Examples (example projects)

**Keep private:**
1. 🔒 RiviAskAI (source code)

### Client Setup:

```swift
// Client's Package.swift
dependencies: [
    .package(
        url: "https://oauth2:CLIENT_TOKEN@gitlab.com/your-org/RiviAskAI-Binary.git",
        from: "1.0.0"
    )
]
```

---

## Updating for New Versions

```bash
# 1. Make changes in RiviAskAI source repo
# 2. Build new version
./release.sh 1.1.0

# 3. Upload new XCFramework
# 4. Update RiviAskAI-Binary Package.swift
# 5. Tag and push
cd ../RiviAskAI-Binary
git add Package.swift
git commit -m "Release version 1.1.0"
git tag 1.1.0
git push origin main --tags
```

---

## Troubleshooting

### Build Fails

```bash
# Make sure you have a scheme
xcodebuild -list

# If no scheme, create one in Xcode:
# Product → Scheme → Manage Schemes → Check "Shared"
```

### Checksum Mismatch

```bash
# Recompute checksum
swift package compute-checksum build/RiviAskAI-1.0.0.xcframework.zip

# Update Package.swift with new checksum
```

### Client Can't Download

- Check URL is accessible
- Verify authentication token has access
- Ensure file is uploaded correctly

---

## Complete Checklist

- [ ] Create RiviAskAI-Binary repository
- [ ] Create RiviAskAI-Examples repository
- [ ] Build XCFramework
- [ ] Upload XCFramework to hosting
- [ ] Update Package.swift with URL and checksum
- [ ] Tag and push binary repo
- [ ] Move example project to examples repo
- [ ] Update example to use binary package
- [ ] Test client integration
- [ ] Create deploy tokens for clients
- [ ] Share access with clients
EOF
