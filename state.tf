terraform {
  backend "s3" {
    bucket = "terraform-pd"
    key    = "roboshop/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
