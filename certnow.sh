#!/bin/bash
# This is a simple bash script which uses Certbot to generate a wildcard certificate for a domain and upload it to AWS Secrets Manager. It uses DNS validation via Route 53 for the domain.

# Usage: certnow.sh <domain> <email> <aws_profile> <aws_region> <aws_secret_name>

set -e
set -o pipefail

if [ $# -ne 5 ]; then
    echo "Usage: certnow.sh <domain> <email> <aws_profile> <aws_region> <aws_secret_name>"
    exit 1
fi

# Check if certbot is installed
if ! command -v certbot &> /dev/null
then
    echo "Certbot could not be found! Please install certbot and try again."
    exit 1
fi

# Check if aws cli is installed
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found! Please install the AWS CLI and try again."
    exit 1
fi

domain=$1
email=$2
aws_profile=$3
aws_region=$4
aws_secret_name=$5

# Check if a Route53 hosted zone for <domain> exists
echo "Checking if Route53 hosted zone for $domain exists..."

if ! aws route53 list-hosted-zones --profile $aws_profile --region $aws_region | grep -q "$domain"; then
    echo "No Route53 hosted zone for $domain found! Please create one and try again."
    exit 1
fi

# Check if the secrets manager secret already exists, otherwise create it
default_secret_value='{"certificate":"NotGenerated","private_key":"NotGenerated"}'

echo "Checking if secret $aws_secret_name exists in Secrets Manager..."

# Check if the secret exists
if aws secretsmanager describe-secret --secret-id "$aws_secret_name" --profile $aws_profile --region $aws_region >/dev/null 2>&1; then
    echo "Secret $aws_secret_name already exists."
else
    echo "Secret $aws_secret_name does not exist. Creating..."
    # Create the secret
    aws secretsmanager create-secret --name "$aws_secret_name" --description "Wildcard certificate for $domain" --secret-string "$default_secret_value" --profile $aws_profile --region $aws_region
    echo "Secret created."
fi

echo "Generating certificate for $domain..."

# Generate certificate using DNS and Route 53
# If domain is wildcard, set ABC to true
if [[ $domain == *"*"* ]]; then
    echo "Wildcard domain detected. Using Let's Encrypt..."
    certbot certonly \
        --dns-route53 \
        --preferred-challenges dns \
        --email $email \
        --agree-tos \
        --config-dir . \
        --work-dir . \
        --logs-dir . \
        --no-eff-email \
        --domain "$domain,*.$domain" \
        -q
else
    echo "Wildcard domain not detected. Using BuyPass..."
    certbot certonly \
        --dns-route53 \
        --preferred-challenges dns \
        --email $email \
        --agree-tos \
        --config-dir . \
        --work-dir . \
        --logs-dir . \
        --no-eff-email \
        --server 'https://api.buypass.com/acme/directory' \
        --domain "$domain" \
        -q
fi

echo "Certificate generated!"

echo "Uploading certificate to AWS Secrets Manager..."

# Upload secrets (file://$(pwd)/live/$domain/cert.pem & file://$(pwd)/live/$domain/privkey.pem) to AWS Secrets Manager as a JSON object, making sure to replace newlines with a space
aws secretsmanager put-secret-value \
    --secret-id $aws_secret_name \
    --secret-string "{\"certificate\":\"$(cat live/$domain/cert.pem | tr '\n' ' ')\",\"private_key\":\"$(cat live/$domain/privkey.pem | tr '\n' ' ')\"}" \
    --profile $aws_profile \
    --region $aws_region

echo "Certificate uploaded!"

# Security - Delete every file listed in the .gitignore file. This prevents anyone stealing the cert and key from the filesystem.
echo "Cleaning up..."
cat .gitignore | xargs rm -rf

echo "Done!"

exit 0
