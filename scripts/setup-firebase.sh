#!/bin/bash

# Firebase Configuration Setup Script for Parable Bloom
# This script uses Bitwarden CLI to securely retrieve Firebase secrets
# and generate platform-specific configuration files for local development.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Bitwarden CLI is installed and logged in
check_bw_cli() {
    if ! command -v bw &> /dev/null; then
        print_error "Bitwarden CLI (bw) is not installed."
        print_error "Install it from: https://bitwarden.com/help/cli/"
        exit 1
    fi

    if ! bw login --check &> /dev/null; then
        print_error "You are not logged in to Bitwarden CLI."
        print_error "Run: bw login"
        exit 1
    fi

    print_success "Bitwarden CLI is installed and logged in"
}

# Check if Bitwarden Secrets CLI is installed
check_bws_cli() {
    if ! command -v bws &> /dev/null; then
        print_error "Bitwarden Secrets CLI (bws) is not installed."
        print_error "Install it from: https://bitwarden.com/help/secrets-manager-cli/"
        exit 1
    fi

    print_success "Bitwarden Secrets CLI is installed"
}

# Unlock Bitwarden vault if needed
unlock_vault() {
    if ! bw unlock --check &> /dev/null; then
        print_warning "Bitwarden vault is locked. Please unlock it:"
        bw unlock
    fi
}

# Retrieve secrets from Bitwarden Secrets Manager
get_secrets() {
    print_status "Retrieving Firebase secrets from Bitwarden..."

    # Get secrets from parable-bloom project
    local secrets_output
    secrets_output=$(bws secret list 7864e88f-517c-4da9-a114-b3bc0032bca0 2>/dev/null || {
        print_error "Failed to retrieve secrets from Bitwarden."
        print_error "Make sure you have access to the 'parable-bloom' project."
        print_error "Project ID: 7864e88f-517c-4da9-a114-b3bc0032bca0"
        exit 1
    })

    # Extract API key and project ID
    FIREBASE_WEB_API_KEY=$(echo "$secrets_output" | jq -r '.[] | select(.key == "FIREBASE_WEB_API_KEY") | .value')
    FIREBASE_PROJECT_ID=$(echo "$secrets_output" | jq -r '.[] | select(.key == "FIREBASE_PROJECT_ID") | .value')

    if [ -z "$FIREBASE_WEB_API_KEY" ] || [ -z "$FIREBASE_PROJECT_ID" ]; then
        print_error "Failed to retrieve required secrets."
        print_error "Make sure FIREBASE_WEB_API_KEY and FIREBASE_PROJECT_ID exist in the project."
        exit 1
    fi

    print_success "Retrieved Firebase secrets"
}

# Generate Android google-services.json
generate_android_config() {
    print_status "Generating Android configuration..."

    mkdir -p android/app

    cat > android/app/google-services.json << EOF
{
  "project_info": {
    "project_number": "1005379493386",
    "project_id": "${FIREBASE_PROJECT_ID}",
    "storage_bucket": "${FIREBASE_PROJECT_ID}.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:1005379493386:android:cb48ba8767aa471f1789f3",
        "android_client_info": {
          "package_name": "com.garciaericn.parable_bloom"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "${FIREBASE_WEB_API_KEY}"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
EOF

    print_success "Generated android/app/google-services.json"
}

# Generate iOS GoogleService-Info.plist
generate_ios_config() {
    print_status "Generating iOS configuration..."

    mkdir -p ios/Runner

    cat > ios/Runner/GoogleService-Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${FIREBASE_WEB_API_KEY}</string>
	<key>GCM_SENDER_ID</key>
	<string>1005379493386</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>com.garciaericn.parablebloom</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_PROJECT_ID}.firebasestorage.app</string>
	<key>IS_ADS_ENABLED</key>
	<false></false>
	<key>IS_ANALYTICS_ENABLED</key>
	<false></false>
	<key>IS_APPINVITE_ENABLED</key>
	<true></true>
	<key>IS_GCM_ENABLED</key>
	<true></true>
	<key>IS_SIGNIN_ENABLED</key>
	<true></true>
	<key>GOOGLE_APP_ID</key>
	<string>1:1005379493386:ios:74f559f1cf97c8ef1789f3</string>
</dict>
</plist>
EOF

    print_success "Generated ios/Runner/GoogleService-Info.plist"
}

# Generate web firebase-config.js
generate_web_config() {
    print_status "Generating web configuration..."

    cat > web/firebase-config.js << EOF
// Firebase Configuration for Parable Bloom Web App
// Generated automatically from Bitwarden secrets for local development
window.firebaseConfig = {
  apiKey: "${FIREBASE_WEB_API_KEY}",
  authDomain: "${FIREBASE_PROJECT_ID}.firebaseapp.com",
  projectId: "${FIREBASE_PROJECT_ID}",
  storageBucket: "${FIREBASE_PROJECT_ID}.firebasestorage.app",
  messagingSenderId: "1005379493386",
  appId: "1:1005379493386:web:8477bb3a66efd9f81789f3",
  measurementId: "G-9YV8X65ZNY"
};
EOF

    print_success "Generated web/firebase-config.js"
}

# Main execution
main() {
    echo "🔥 Firebase Configuration Setup for Parable Bloom"
    echo "=================================================="

    check_bw_cli
    check_bws_cli
    unlock_vault
    get_secrets
    generate_android_config
    generate_ios_config
    generate_web_config

    echo ""
    print_success "Firebase configuration setup complete!"
    print_status "You can now run Flutter builds locally with Firebase integration."
    print_warning "Remember: These config files are excluded from version control."
    print_warning "They contain API keys - keep them secure and never commit them."
}

# Run main function
main "$@"
