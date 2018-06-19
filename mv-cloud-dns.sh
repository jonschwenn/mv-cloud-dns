#!/usr/bin/env bash
# Script to export DNS zones from Vultr and import into DigitalOcean
# Read the README.md to ensure proper configuration
# https://github.com/jonschwenn/mv-cloud-dns

set -eo pipefail

blue="\e[34m"
green="\e[92m"
red="\e[31m"
und="\e[4m"
bold="\e[1m"
fin="\e[0m"

check_jq (){
  if [[ -z $(which jq)  ]]; then
    echo -e "${red}\nThis script requires jq. Please install jq and re-run this script.\n${fin}"
    echo -e "${bold}Example:${fin} yum install jq -or- apt-get install jq \n"
    echo -e "This script was not written to run on MacOS"
    exit 1
  fi
}

do_token (){
  until [[ $(curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" "https://api.digitalocean.com/v2/account" | jq -r '.id') != "unauthorized" ]]; do
    read -p $'\e[34mPlease enter in your DigitalOcean API token\e[0m\n> ' do_token;
  done
}

vultr_token (){
  until [[ $(curl -s -X GET -H "Content-Type: application/json" -H "API-key: ${vultr_token}" "https://api.vultr.com/v1/account/info" | grep -v "API key") ]]; do
    read -p $'\e[34mPlease enter in your Vultr API token\e[0m\n> ' vultr_token;
  done
}

migrate_zones (){
  # List Domain Zones at Vultr
  DOMAIN_LIST=($(curl -s -X GET -H "Content-Type: application/json" -H "API-key: ${vultr_token}" "https://api.vultr.com/v1/dns/list" | jq -r '.[] | .domain'))
  echo -e "\n\nList of Domains at Vultr:"
  printf '%s\n' "${DOMAIN_LIST[@]}"

  # Check to see if domains are already on the DigitalOcean account
  # Remove domains already on DigitalOcean from migration list
  DOMAIN_COUNT=${#DOMAIN_LIST[@]}
  for (( i=0; i<${DOMAIN_COUNT}; i++ )); do
    if [[ $(curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" "https://api.digitalocean.com/v2/domains/${DOMAIN_LIST[$i]}" | jq -r '.id') != "not_found" ]]; then
      echo -e "${red}Domain ${DOMAIN_LIST[$i]} found on DigitalOcean: Removing from migration${fin}"
      unset DOMAIN_LIST[$i]
    fi
  done

  # Create domain on DigitalOcean
  echo -e "\n\nMigrating Domain Zones to DigitalOcean..."
  for i in "${DOMAIN_LIST[@]}"; do
    if [[ $(curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" -d '{"name":"'$i'","ip_address":"1.2.3.4"}' "https://api.digitalocean.com/v2/domains/" | jq -r '.id') != "(unprocessable_entity|bad_request)" ]]; then
      echo -e "Domain created on DigitalOcean: $i"
    else
      echo -e "${red}Domain creation failed: $i ${fin}"
    fi
  done

  # Remove default A Record
  # This functionality is being switched to optional soon and this block can be removed once the zones can be created without an A record
  for i in "${DOMAIN_LIST[@]}"; do
    DEFAULT_RECORD=$(curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" "https://api.digitalocean.com/v2/domains/$i/records" | jq -r '.domain_records[3].id')
    curl -sS -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" "https://api.digitalocean.com/v2/domains/$i/records/$DEFAULT_RECORD"
  done

  # Migrate Records for each domain
  for i in "${DOMAIN_LIST[@]}"; do
    echo -e "\n\nMigrating Records for $i:"
    RECORD_COUNT=$(curl -s -X GET -H "Content-Type: application/json" -H "API-key: ${vultr_token}" "https://api.vultr.com/v1/dns/records?domain=$i" |  jq -r length)
    for (( x=0; x<${RECORD_COUNT}; x++ )); do
      RECORD=($(curl -s -X GET -H "Content-Type: application/json" -H "API-key: ${vultr_token}" "https://api.vultr.com/v1/dns/records?domain=$i" |  jq -r  ".[$x] | .type, if .name == \"\" then \"@\" else .name end, .ttl, .priority, .data"))
      # A Record and AAAA Record import
      if [[ "${RECORD[0]}" =~ ^(A|AAAA)$ ]]; then
        if [[ $(curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" -d '{"type":"'${RECORD[0]}'","name":"'${RECORD[1]}'","data":"'${RECORD[4]}'","priority":null,"port":null,"ttl":"'${RECORD[2]}'","weight":null,"flags":null,"tag":null}' "https://api.digitalocean.com/v2/domains/$i/records" | jq -r '.id') != "(unprocessable_entity|bad_request)" ]]; then
          echo -e "TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: ${RECORD[4]}  TTL: ${RECORD[2]}"
        else
          echo -e "${red}Record failed:  TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: ${RECORD[4]}  TTL: ${RECORD[2]} ${fin}"
        fi
      # Special case for MX (need to add Priority feild and to add trailing dot for DigitalOcean)
      elif [[ "${RECORD[0]}" =~ ^(MX)$ ]]; then
        if [[ $(curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" -d '{"type":"'${RECORD[0]}'","name":"'${RECORD[1]}'","data":"'${RECORD[4]}'.","priority":"'${RECORD[3]}'","port":null,"ttl":"'${RECORD[2]}'","weight":null,"flags":null,"tag":null}' "https://api.digitalocean.com/v2/domains/$i/records" | jq -r '.id') != "(unprocessable_entity|bad_request)" ]]; then
          echo -e "TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: ${RECORD[4]}  TTL: ${RECORD[2]}  PRIORITY: ${RECORD[3]}"
        else
          echo -e "${red}Record failed:  TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: ${RECORD[4]}  TTL: ${RECORD[2]}   PRIORITY: ${RECORD[3]}${fin}"
        fi
      # Special case for CNAME (need to add trailing dot for DigitalOcean)
      elif [[ "${RECORD[0]}" =~ ^(CNAME)$ ]]; then
        if [[ $(curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" -d '{"type":"'${RECORD[0]}'","name":"'${RECORD[1]}'","data":"'${RECORD[4]}'.","priority":null,"port":null,"ttl":"'${RECORD[2]}'","weight":null,"flags":null,"tag":null}' "https://api.digitalocean.com/v2/domains/$i/records" | jq -r '.id') != "(unprocessable_entity|bad_request)" ]]; then
          echo -e "TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: ${RECORD[4]}  TTL: ${RECORD[2]}"
        else
          echo -e "${red}Record failed:  TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: ${RECORD[4]}  TTL: ${RECORD[2]} ${fin}"
        fi
      # Special case for TXT Record, obtain a complete data field
      # Parsing the data field in jq is not predictable so we're running a dig directly against vultr's name server
      # This is where I questioned my choice to go "simple" with bash and jq
      elif [[ "${RECORD[0]}" =~ ^(TXT)$ ]]; then
        if [[ "${RECORD[1]}" == "@" ]]; then
          TXT_DATA=$(dig +short -t TXT @ns1.vultr.com $i)
        else
          TXT_DATA=$(dig +short -t TXT @ns1.vultr.com "${RECORD[1]}".$i)
        fi
        if [[ $(curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${do_token}" -d '{"type":"'${RECORD[0]}'","name":"'${RECORD[1]}'","data":'"$TXT_DATA"',"priority":null,"port":null,"ttl":"'${RECORD[2]}'","weight":null,"flags":null,"tag":null}' "https://api.digitalocean.com/v2/domains/$i/records" | jq -r '.id') != "(unprocessable_entity|bad_request)" ]]; then
          echo -e "TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: $TXT_DATA  TTL: ${RECORD[2]}"
        else
          echo -e "${red}Record failed:  TYPE: ${RECORD[0]}  NAME: ${RECORD[1]}  DATA: $TXT_DATA  TTL: ${RECORD[2]} ${fin}"
        fi
      fi
    done
  done

  # Alert for DNSSEC
  for i in "${DOMAIN_LIST[@]}"; do
    if [[ $(curl -s -X GET -H "Content-Type: application/json" -H "API-key: ${vultr_token}" "https://api.vultr.com/v1/dns/dnssec_info?domain=$i" ) !=  DNSSEC* ]]; then
      echo -e "\n\n${red}WARNING: Domain $i has DNSSEC enabled on Vultr. Please ensure this setting is disabled at your domain registrar.${fin}"
    fi
  done
}

finished (){
  echo -e "\n\nYour domain zones are now migrated to DigitalOcean!"
  echo -e "\nUse these name servers in your domain registrar's settings:"
  echo -e "${blue}ns1.digitalocean.com${fin}"
  echo -e "${blue}ns2.digitalocean.com${fin}"
  echo -e "${blue}ns3.digitalocean.com${fin}"
}

check_jq
do_token
vultr_token
migrate_zones
finished
