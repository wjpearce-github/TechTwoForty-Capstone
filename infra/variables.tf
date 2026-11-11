variable "region" {
  type        = string
  description = "AWS Region for everything in the capstone"
  default     = "eu-west-2"
}

variable "github_subject" {
  type        = string
  description = "Your repo as GitHub names it in OIDC tokens, printed in Stage 2 phase 4, for example repo:yourname@12345678/devsecops-capstone@987654321"
}
