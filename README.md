# files.kramerc.social

The Mastodon files bucket for [kramerc.social](https://kramerc.social), an Amazon S3 bucket and CloudFront distribution managed with Terraform.

## Set up

Attach the following IAM policies to your IAM user:
- AmazonDynamoDBFullAccess
- AmazonRoute53FullAccess
- AmazonS3FullAccess
- AWSCertificateManagerFullAccess
- CloudFrontFullAccess
- IAMFullAccess

[Custom policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_controlling.html) can be created to further lockdown the IAM user to the specific resources and actions used by this module. 

Obtain [access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) for your AWS IAM user.
```
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
```

Then init:
```shell
terraform init
```

Terraform is now ready.
