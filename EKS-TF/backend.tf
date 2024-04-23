terraform {
  backend "s3" {
    bucket = "sateesh1075" 
    key    = "EKS/terraform.tfstate"
    region = "ap-south-1"
  }
}
