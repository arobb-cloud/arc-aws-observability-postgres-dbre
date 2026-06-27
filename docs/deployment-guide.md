# Deployment Guide

## Prerequisites

- AWS Account
- Terraform
- AWS CLI
- Docker Desktop
- Git
- GitHub Account

## Create directory structure

## Clone Repository

		$ cd c:/<path_root_dir>
		$ git clone https://github.com/arobb-cloud/arc-aws-observability-postgres-dbre.git
		$ cd arc-aws-observability-postgres-dbre

## Verify .gitignore

## Create Terraform scripts

	$ cd <root_dir>/
	$ New-Item terraform\main.tf
	$ New-Item terraform\variables.tf
	$ New-Item terraform\outputs.tf
	$ New-Item terraform\versions.tf
	$ New-Item terraform\providers.tf
	$ New-Item terraform\terraform.tfvars.example

## Terraform Deployment

terraform init
terraform validate
terraform plan

## Docker Deployment

docker compose up -d

## Verify PostgreSQL

docker ps

## Access pgAdmin

http://localhost:8080

## Validate GitHub Actions

Repository → Actions