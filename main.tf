terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.62"
    }
  }

  backend "s3" {
    region         = "us-east-1"
    bucket         = "files-kramerc-social-terraform"
    key            = "terraform.tfstate"
    dynamodb_table = "files-kramerc-social-terraform"
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  s3_origin_id = "S3-files-kramerc-social"
}

resource "aws_route53_zone" "files-kramerc-social" {
  name = "files.kramerc.social"
}

resource "aws_s3_bucket" "files-kramerc-social" {
  bucket = "files-kramerc-social"
}

resource "aws_s3_bucket_acl" "files-kramerc-social" {
  bucket = aws_s3_bucket.files-kramerc-social.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "files-kramerc-social" {
  bucket = aws_s3_bucket.files-kramerc-social.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "files-kramerc-social" {
  bucket = aws_s3_bucket.files-kramerc-social.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
          "Sid": "PublicReadGetObject",
          "Effect": "Allow",
          "Principal": "*",
          "Action": [
             "s3:GetObject"
          ],
          "Resource": [
             "arn:aws:s3:::${aws_s3_bucket.files-kramerc-social.id}/*"
          ]
      }
    ]
}
POLICY
}

resource "aws_s3_bucket" "files-kramerc-social-logs" {
  bucket = "files-kramerc-social-logs"
}

resource "aws_s3_bucket_acl" "files-kramerc-social-logs" {
  bucket = aws_s3_bucket.files-kramerc-social-logs.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "files-kramerc-social-logs" {
  bucket = aws_s3_bucket.files-kramerc-social-logs.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "files-kramerc-social" {
  bucket = aws_s3_bucket.files-kramerc-social.id

  target_bucket = aws_s3_bucket.files-kramerc-social-logs.id
  target_prefix = "log/"
}

resource "aws_iam_user" "mastodon" {
  name = "mastodon"
}

resource "aws_iam_access_key" "mastodon" {
  user = aws_iam_user.mastodon.name
}

resource "aws_iam_user_policy" "mastodon" {
  user   = aws_iam_user.mastodon.name
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Bucket",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.files-kramerc-social.id}"
      ]
    },
    {
      "Sid": "AllowS3Access",
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetObject",        
        "s3:GetObjectAcl",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.files-kramerc-social.id}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_cloudfront_distribution" "files-kramerc-social" {
  origin {
    domain_name = aws_s3_bucket.files-kramerc-social.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "files.kramerc.social"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.files-kramerc-social-logs.bucket_domain_name
  }

  aliases = ["files.kramerc.social"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.files-kramerc-social-cert.arn
    ssl_support_method  = "sni-only"
  }
}

resource "aws_route53_record" "files-kramerc-social" {
  zone_id = aws_route53_zone.files-kramerc-social.zone_id
  name    = "files.kramerc.social"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_cloudfront_distribution.files-kramerc-social.domain_name]
}

resource "aws_acm_certificate" "files-kramerc-social-cert" {
  domain_name       = "files.kramerc.social"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "files-kramerc-social-cert" {
  for_each = {
    for dvo in aws_acm_certificate.files-kramerc-social-cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.files-kramerc-social.zone_id
}

resource "aws_acm_certificate_validation" "files-kramerc-social-cert" {
  certificate_arn         = aws_acm_certificate.files-kramerc-social-cert.arn
  validation_record_fqdns = [for record in aws_route53_record.files-kramerc-social-cert : record.fqdn]
}
