# certnow
Certbot 💜 AWS (Secrets Manager + Route 53)

This is a simple bash script which uses Certbot to generate a wildcard certificate for a domain and upload it to AWS Secrets Manager. It uses DNS validation via Route 53 for the domain.

By default, Let's Encrypt will be used. The certificate will be valid for 90 days if using Let's Encrypt.

We recommend running this script via Airflow, a cron job, or other serverless infrastructure options to keep your certificate up to date.

## Requirements
- [Certbot](https://certbot.eff.org/)
- [AWS CLI](https://aws.amazon.com/cli/)
- An AWS account with Route 53 and Secrets Manager access.
- The domain you wish to issue a certificate to must have an active (public) zone in Route 53.

## Usage

```bash
$ ./certnow.sh
Usage: certnow.sh <domain> <email> <aws_profile> <aws_region> <aws_secret_name> <extra_certbot_args>
```

## Example

```bash
$ ./certnow.sh example.com name@yourdomaingoeshere.com default us-east-1 example-com-cert

# To use RSA keys instead of ECDSA keys, use extra_certbot_args like so:
$ ./certnow.sh example.com name@yourdomaingoeshere.com default us-east-1 example-com-cert "--key-type rsa --rsa-key-size 4096"
```
