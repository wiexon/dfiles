#!/bin/bash

# Download the file
wget -O /usr/local/bin/certbotod https://raw.githubusercontent.com/wiexon/dfiles/main/certbotod/certbotod.sh

# Make the file executable
chmod +x /usr/local/bin/certbotod

sudo ln -s /usr/local/bin/certbotod /usr/bin/certbotod

echo "Installation complete"