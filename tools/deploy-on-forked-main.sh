#!/bin/sh

# output color (to read easily)
outputColor=32

network=forked-mainnet
owner=$(grep ADDRESS .env | cut -d '=' -f2)

printf "\e[$outputColor;1m"
printf "command: npx oz compile\n"
printf "\e[m"
npx oz compile

# printf "\e[$outputColor;1m"
# printf "\ncommand: npx oz session --network $network --from $owner --expires 3600 --timeout 750 --blockTimeout 50\n"
# printf "\e[m"
# npx oz session --network $network --from $owner --expires 3600 --timeout 750 --blockTimeout 50

# deploy TokenSwap
printf "\e[$outputColor;1m"
printf "\ncommand: npx oz deploy --kind \"regular\" TookenSwap \"$(grep LendingPoolAddressesProvider .env | cut -d '=' -f2)\"\n"
printf "\e[m"
npx oz deploy --network $network --from $owner --kind "regular" TokenSwap "$(grep LendingPoolAddressesProvider .env | cut -d '=' -f2)"
