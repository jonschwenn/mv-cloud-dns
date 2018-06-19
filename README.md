# DNS Zone Migrator

This tool migrate your DNS zones from Vultr to DigitalOcean. The record settings will be copied over during the migration.

#### Supported Records:
* A
* AAAA
* CNAME
* MX
* TXT

#### Unsupported Records:
* NS Records: Automatically created on migration to point to the DigitalOcean name servers
* SRV Records: Not supported due to added complexity with Vultr's implementation
* CAA Records: Not supported due to added complexity with Vultr's implementation
* SSHFP Records: Not supported on DigitalOcean

### Prerequisites
---
1. A modern Linux OS
2. git (if you intend on cloning this repository)
3. jq (can be installed with a simple `ap-get install jq` or `yum install jq`)
4. API tokens for your Vultr and DigitalOcean accounts

### Setup
---
- Clone the repository
```
$ git clone https://github.com/jonschwenn/mv-cloud-dns.git
```
- Run the script and paste the API tokens when prompted
```
$ ./mv-cloud-dns/mv-cloud-dns.sh
```
- Follow the recommendations of the script and point your domains to DigitalOcean's name servers once completed:
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com

### Future Development
--
I have intentions of adding more cloud provider options.

### License, Warranty, and Contributing
---
This tool is made available under the [Apache 2.0](LICENSE) License.
There is no warranty provided and use of this software at your own risk.
Have an idea for this script or found a bug? Check out the [contributing guidelines](CONTRIBUTING.md)
