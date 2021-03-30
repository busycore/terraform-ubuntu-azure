terraform {
  required_version = ">=0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.26"
    }
  }
}


//The provider for azure cloud
//skip registration once we are already logged in our session
provider "azurerm" {
  skip_provider_registration = true
  features {}
}
