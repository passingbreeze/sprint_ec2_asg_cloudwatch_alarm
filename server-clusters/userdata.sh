#!/bin/bash
echo "Hello, World" > index.html
sudo apt update --fix-missing
sudo apt install stress
nohup busybox httpd -f -p 80 &