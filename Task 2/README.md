# Task 2: S3 File Compression with VPC and Docker

AWS Lambda function that automatically compresses files uploaded to S3, deployed with CloudFormation using Docker containers in a custom VPC.

## Architecture

The infrastructure is split into **2 CloudFormation stacks**:

1. **Infrastructure Stack** (`infra-template.yaml`):
   - Custom VPC (10.0.0.0/16)
   - 2 Private Subnets in different AZs
   - **S3 Gateway VPC Endpoint** (enables private S3 access without NAT Gateway or internet)
   - S3 Bucket with versioning
   - Security Group

2. **Lambda Stack** (`lambda-template.yaml`):
   - ECR Repository for Docker images
   - Lambda Function (Python 3.12, x86_64)
   - IAM Role with S3 and VPC permissions
   - Lambda Version & Alias (for rollback)
   - S3 Event Notification

### Why S3 Gateway VPC Endpoint Instead of NAT Gateway?

**Traditional Approach** (with NAT Gateway):
- Lambda in private subnet → NAT Gateway → Internet Gateway → S3 (over internet)
- Costs: monthly cost for NAT Gateway + data transfer charges
- Security: Traffic goes over internet (even if encrypted)

**Our Approach** (with S3 Gateway VPC Endpoint):
- Lambda in private subnet → S3 Gateway VPC Endpoint → S3 (private AWS network)
- Costs: **$0** (Gateway VPC Endpoints are free)
- Security: Traffic never leaves AWS network
- Performance: Lower latency (no internet hop)

The S3 Gateway VPC Endpoint is attached to the private subnet route table, allowing Lambda to access S3 directly through AWS's internal network without requiring any internet access.

## Prerequisites

- AWS CLI installed and configured
- Docker installed and running
- Bash shell

## Quick Start

### Deploy Everything

```bash
cd "Task 2"
./deploy.sh
```

The script automatically:
1. ✅ Deploys infrastructure stack (VPC, subnets, S3 bucket)
2. ✅ Creates ECR repository
3. ✅ Builds Docker image (single-arch x86_64)
4. ✅ Pushes image to ECR
5. ✅ Deploys Lambda stack
6. ✅ Configures S3 event notification

### Test the Pipeline

Upload a test file:

```bash
# Get bucket name
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name file-compression-infra \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text)

# Upload a test file (create any file you want to compress)
echo '{"test": "data"}' > sample.json
aws s3 cp sample.json s3://$BUCKET_NAME/incoming/

# Check processed files (compressed ZIP)
aws s3 ls s3://$BUCKET_NAME/processed/

# Download and verify
aws s3 cp s3://$BUCKET_NAME/processed/sample.zip ./
unzip -l sample.zip
```

### View Lambda Logs

```bash
aws logs tail /aws/lambda/file-compression-lambda-file-compression --follow
```

### Cleanup

```bash
./cleanup.sh
```

This removes both stacks, empties S3 bucket, and deletes ECR images.

---

## Manual Deployment (Step-by-Step)

If you prefer manual control:

### Step 1: Deploy Infrastructure Stack

```bash
aws cloudformation deploy \
    --template-file infra-template.yaml \
    --stack-name file-compression-infra \
    --parameter-overrides \
        VpcCIDR=10.0.0.0/16 \
        PrivateSubnet1CIDR=10.0.1.0/24 \
        PrivateSubnet2CIDR=10.0.2.0/24 \
    --region us-east-1
```

### Step 2: Create ECR and Build Docker Image

```bash
# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_REPO_NAME="file-compression-lambda-repo"
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}"

# Create ECR repository
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $REGION

# Login to ECR
aws ecr get-login-password --region $REGION | \
    docker login --username AWS --password-stdin $ECR_URI

# Build Docker image (x86_64 only)
docker build --platform linux/amd64 -t $ECR_REPO_NAME:latest .

# Tag and push
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest
```

### Step 3: Deploy Lambda Stack

```bash
aws cloudformation deploy \
    --template-file lambda-template.yaml \
    --stack-name file-compression-lambda \
    --parameter-overrides \
        InfraStackName=file-compression-infra \
        LambdaImageUri=$ECR_URI:latest \
        SourcePrefix=incoming/ \
        ProcessedPrefix=processed/ \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1
```

### Step 4: Configure S3 Event Notification

```bash
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name file-compression-infra \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text)

LAMBDA_ARN=$(aws cloudformation describe-stacks \
    --stack-name file-compression-lambda \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`FunctionArn`].OutputValue' \
    --output text)

# Create notification config
cat > /tmp/notification.json <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "prefix", "Value": "incoming/"}
          ]
        }
      }
    }
  ]
}
EOF

# Apply notification
aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration file:///tmp/notification.json

rm /tmp/notification.json
```

---

## How It Works

1. **File Upload**: Upload any file to `s3://bucket-name/incoming/`
2. **Lambda Trigger**: S3 event triggers Lambda function
3. **Compression**: Lambda compresses file to ZIP format
4. **Storage**: ZIP saved to `s3://bucket-name/processed/`
5. **Cleanup**: Original file deleted from `incoming/`

### Network Architecture

- Lambda runs in **private subnets** (no direct internet access)
- S3 access via **S3 Gateway VPC Endpoint** attached to the route table
- **No NAT Gateway required** - saves cost and improves security
- All traffic between Lambda and S3 stays within AWS network

---

## Stack Outputs

### Infrastructure Stack Outputs

```bash
aws cloudformation describe-stacks \
    --stack-name file-compression-infra \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table
```

- `VpcId`: VPC ID
- `S3BucketName`: Bucket name
- `S3BucketARN`: Bucket ARN
- `PrivateSubnet1ID`, `PrivateSubnet2ID`: Subnet IDs
- `SecurityGroupID`: Security group for Lambda

### Lambda Stack Outputs

```bash
aws cloudformation describe-stacks \
    --stack-name file-compression-lambda \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table
```

- `FunctionArn`: Lambda function ARN
- `FunctionName`: Lambda function name
- `LambdaAliasArn`: Alias ARN (for rollback)

---

## Update Deployment

To update Lambda code:

1. Modify `lambda_function.py`
2. Run `./deploy.sh` again

The script rebuilds the Docker image and updates the Lambda function.

---

## Lambda Versioning & Rollback

Each deployment creates a new Lambda version with the `live` alias.

### List versions

```bash
aws lambda list-versions-by-function \
    --function-name file-compression-lambda-file-compression
```

### Rollback to previous version

```bash
aws lambda update-alias \
    --function-name file-compression-lambda-file-compression \
    --name live \
    --function-version <VERSION_NUMBER>
```

---

## Troubleshooting

### ❌ Error: "The image manifest, config or layer media type is not supported"

**Cause**: ECR contains a multi-arch image manifest (OCI index). Lambda requires single-arch images.

**Fix**:

```bash
# 1. Delete the bad image
aws ecr batch-delete-image \
    --repository-name file-compression-lambda-repo \
    --region us-east-1 \
    --image-ids imageTag=latest

# 2. Rebuild with single arch
docker build --platform linux/amd64 -t myrepo:latest .

# 3. Push again
docker push <ecr-uri>:latest

# 4. Verify manifest type
aws ecr describe-images \
    --repository-name file-compression-lambda-repo \
    --region us-east-1 \
    --query 'imageDetails[0].imageManifestMediaType'
```

✅ Expected: `application/vnd.oci.image.manifest.v1+json` (single-arch)  
❌ Wrong: `application/vnd.oci.image.index.v1+json` (multi-arch)

**The `deploy.sh` script does this automatically.**

### ❌ Lambda not triggering

- Check S3 event notification is configured (run `deploy.sh` to auto-configure)
- Verify file is uploaded to `incoming/` prefix
- Check CloudWatch logs for errors

### ❌ ECR push permission denied

Re-login to ECR:

```bash
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

---

## Files

- `infra-template.yaml`: Infrastructure CloudFormation template (VPC, S3, etc.)
- `lambda-template.yaml`: Lambda CloudFormation template
- `lambda_function.py`: Lambda code (file compression logic)
- `Dockerfile`: Lambda container image definition
- `deploy.sh`: Automated deployment script
- `cleanup.sh`: Cleanup script (deletes all resources)

---

## Resources Created

| Resource | Description |
|----------|-------------|
| VPC | 10.0.0.0/16 with DNS enabled |
| Private Subnets | 2 subnets in different AZs (10.0.1.0/24, 10.0.2.0/24) |
| Route Table | Private route table for subnet routing |
| S3 Gateway VPC Endpoint | **Free** private S3 access (no NAT Gateway needed) |
| Security Group | Lambda security group (allows outbound to S3 endpoint) |
| S3 Bucket | With versioning enabled |
| ECR Repository | For Docker images (lifecycle: keep last 10) |
| Lambda Function | Python 3.12, x86_64, 512MB RAM, 300s timeout |
| IAM Role | Lambda execution role with S3 + VPC + CloudWatch permissions |
| Lambda Version | Auto-versioned on each deploy |
| Lambda Alias | `live` alias for rollback capability |

---

## Security

- Lambda runs in **private subnets** with no direct internet access
- S3 access via **S3 Gateway VPC Endpoint** - traffic never leaves AWS network
- **No NAT Gateway** - reduces attack surface and eliminates internet egress
- IAM role follows **least privilege** (only S3 and CloudWatch permissions)
- ECR images scanned on push

---

## Cost Optimization

- **No NAT Gateway** - saves ~$32/month per AZ (S3 Gateway VPC Endpoint is free)
- No data transfer charges for S3 access (Gateway Endpoint is free)
- Lambda runs only when files are uploaded (pay-per-use)
- ECR lifecycle policy keeps only last 10 images (reduces storage costs)

---

## Additional Resources

- [AWS Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [AWS Lambda Base Images](https://gallery.ecr.aws/lambda/python)
- [S3 Gateway VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)