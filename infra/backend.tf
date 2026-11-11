terraform {
  backend "s3" {
    bucket       = "your-unique-tfstate-bucket"
    key          = "network/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}
