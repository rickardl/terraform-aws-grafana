curl -fSL https://github.com/wata727/tflint/releases/download/v0.7.0/tflint_linux_amd64.zip -o tflint.zip
unzip tflint.zip -d /opt/tflint
ln -s /opt/tflint/tflint /usr/bin/tflint
rm -f tflint.zip

before_install:
- curl -fSL "https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip" -o terraform.zip
- unzip terraform.zip -d /opt/terraform
- ln -s /opt/terraform/terraform /usr/bin/terraform
- rm -f terraform.zip