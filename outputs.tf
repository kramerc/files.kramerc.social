output "mastodon_key_id" {
  value = aws_iam_access_key.mastodon.id
}

output "mastodon_encrypted_secret" {
  value = aws_iam_access_key.mastodon.encrypted_secret
}
