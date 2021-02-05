#!/bin/sh

# output color (to read easily)
outputColor=32

# remove network files
printf "\e[$outputColor;1m"
printf "\ncommand: rm -f .openzeppelin/dev-5353.json\n"
printf "\e[m"
rm -f .openzeppelin/dev-5353.json

# fork-main
ganache-cli -f $(grep INFURA_MAIN_URL .env | cut -d '=' -f2) -i 5353 -p 7545