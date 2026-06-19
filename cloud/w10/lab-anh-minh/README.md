# AWS Macie S3 Sensitive Data Detection Lab - Terraform

This Terraform configuration deploys the complete infrastructure for detecting sensitive data in Amazon S3 buckets using Amazon Macie with SNS notifications.

## Architecture Components

- **S3 Bucket**: Sample data storage with encryption and versioning
- **Amazon Macie**: Automated data discovery and protection service
- **SNS Topic**: Send alert notifications
- **EventBridge Rule**: Capture high/critical severity Macie findings
- **Email Alerts**: Receive findings via email

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured
- Valid email address for receiving alerts

## Usage

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Configure Variables
Edit `terraform.tfvars` and update:
```hcl
alert_email = "your-email@example.com"
aws_region  = "us-east-1"  # Change as needed
```

### 3. Plan Deployment
```bash
terraform plan
```

### 4. Apply Configuration
```bash
terraform apply
```

### 5. Confirm Email Subscription
After applying, check your email and confirm the SNS topic subscription.

## File Structure

- `main.tf` - Core resources (S3, Macie, SNS, EventBridge)
- `variables.tf` - Input variables definition
- `outputs.tf` - Output values
- `terraform.tfvars` - Variable values

## Testing the Setup

### 1. Create Sample Files with Sensitive Data
```bash
# Create a file with credit card number
echo "Credit Card: 4111-1111-1111-1111" > sensitive_data.txt

# Upload to S3
aws s3 cp sensitive_data.txt s3://$(terraform output -raw s3_bucket_name)/
```

### 2. Run Macie Classification Job
```bash
# Get Job ID
JOB_ID=$(terraform output -raw macie_job_id)

# Start the job
aws macie2 start-classification-job --job-id $JOB_ID
```

### 3. Monitor Findings
- Check AWS Macie console for findings
- Monitor SNS email notifications
- Review EventBridge rules execution in CloudWatch

## Outputs

After `terraform apply`, you'll get:
- `s3_bucket_name` - S3 bucket for sample files
- `macie_job_id` - Classification job ID
- `sns_topic_arn` - SNS topic for alerts
- `event_rule_name` - EventBridge rule name

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## Notes

- Macie charges apply based on data scanned (see [AWS pricing](https://aws.amazon.com/macie/pricing/))
- Email subscription requires manual confirmation
- Classification job can take time depending on data volume
- High and critical severity findings trigger EventBridge rules
