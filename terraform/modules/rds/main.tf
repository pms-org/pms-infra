resource "aws_s3_bucket" "tf_state" {
  bucket = "pms-terraform-state-209332675115"
  force_destroy = false
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "pms-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
