# DNS Zone Migrator

This tool migrates your DNS zones from Vultr to DigitalOcean. The record settings will be copied over during the migration.

![mv-cloud-dns demo](https://github.com/jonschwenn/mv-cloud-dns/raw/master/demo.gif)

#### Supported Records:
* A
* AAAA
* CNAME
* MX
* TXT

#### Unsupported Records:
* *NS Records:* Automatically created on migration to point to the DigitalOcean name servers
* *SRV Records:* Not supported due to added complexity with Vultr's implementation
* *CAA Records:* Not supported due to added complexity with Vultr's implementation
* *SSHFP Records:* Not supported on DigitalOcean
* *DNSSEC:* Not supported on DigitalOcean 
_The tool will display a reminder to disable DNSSEC at your registrar if enabled on the Vultr DNS zone_

### Prerequisites
---
1. A modern Linux OS
2. git (can be installed with a simple `ap-get install git` or `yum install git`)
3. jq (can be installed with a simple `ap-get install jq` or `yum install jq`)
4. API tokens for your Vultr and DigitalOcean accounts
5. Make sure you've added the IP address of the system running the script to your Vultr API access controls

### Setup and Run
---
- Clone the repository
```sh
git clone https://github.com/jonschwenn/mv-cloud-dns.git
```
- Run the script and paste the API tokens when prompted
```sh
./mv-cloud-dns/mv-cloud-dns.sh
```
- Follow the recommendations of the script and point your domains to DigitalOcean's name servers once completed:
```
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com
```

### Future Development
---
I have intentions of adding more cloud provider options.

### License, Warranty, and Contributing
---
This tool is made available under the [Apache 2.0](LICENSE) License.
There is no warranty provided and use of this software at your own risk.
Have an idea for this script or found a bug? Check out the [contributing guidelines](CONTRIBUTING.md)
