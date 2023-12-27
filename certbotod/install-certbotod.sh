#!/bin/bash

# Copy file
cp certbotod.sh /usr/local/bin/certbotod

# Download the file if latest in the server
wget -N https://raw.githubusercontent.com/wiexon/dfiles/main/certbotod/certbotod.sh -O /usr/local/bin/certbotod

# Make the file executable
chmod +x /usr/local/bin/certbotod

echo "File downloaded and installed successfully!"
