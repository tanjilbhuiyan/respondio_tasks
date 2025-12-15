#!/bin/bash

set -e

# Disable AWS CLI pager
export AWS_PAGER=""

INFRA_STACK_NAME="file-compression-infra"
LAMBDA_STACK_NAME="file-compression-lambda"
REGION="us-east-1"
ECR_REPO_NAME="file-compression-lambda-repo"

echo "=========================================="
echo "CloudFormation Deployment Script"
echo "=========================================="

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# ECR Repository URI
ECR_REPO_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}"
echo "ECR Repository: $ECR_REPO_URI"

# Step 1: Deploy Infrastructure Stack
echo ""
echo "=========================================="
echo "Step 1: Deploying Infrastructure Stack"
echo "=========================================="
aws cloudformation deploy \
    --template-file infra-template.yaml \
    --stack-name $INFRA_STACK_NAME \
    --parameter-overrides \
        VpcCIDR=10.0.0.0/16 \
        PrivateSubnet1CIDR=10.0.1.0/24 \
        PrivateSubnet2CIDR=10.0.2.0/24 \
    --region $REGION

echo "Infrastructure stack deployed successfully!"

# Step 2: Create ECR Repository if it doesn't exist
echo ""
echo "=========================================="
echo "Step 2: Creating ECR Repository"
echo "=========================================="
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION 2>/dev/null || \
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --image-scanning-configuration scanOnPush=true

echo "ECR repository ready"

# Step 3: Build Docker Image
echo ""
echo "=========================================="
echo "Step 3: Building Docker Image (amd64 only)"
echo "=========================================="
IMAGE_TAG="latest"

# Delete existing image with latest tag to ensure clean state
echo "Removing existing 'latest' image from ECR (if exists)..."
aws ecr batch-delete-image \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --image-ids imageTag=$IMAGE_TAG 2>/dev/null || echo "No existing 'latest' image to delete"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO_URI

# Build image for linux/amd64 ONLY (no buildx, no multi-arch)
echo "Building Docker image for linux/amd64 (single architecture)..."
# Use plain docker build to avoid buildx multi-arch issues
DOCKER_BUILDKIT=0 docker build --platform linux/amd64 -t $ECR_REPO_NAME:$IMAGE_TAG .

# Tag and push
echo "Tagging image..."
docker tag $ECR_REPO_NAME:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG

echo "Pushing image to ECR..."
docker push $ECR_REPO_URI:$IMAGE_TAG

# Verify the manifest type
echo ""
echo "Verifying image manifest type..."
MANIFEST_TYPE=$(aws ecr describe-images \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --image-ids imageTag=$IMAGE_TAG \
    --query 'imageDetails[0].imageManifestMediaType' \
    --output text)

echo "Image manifest type: $MANIFEST_TYPE"

if [[ "$MANIFEST_TYPE" == "application/vnd.oci.image.index.v1+json" ]]; then
    echo ""
    echo "❌ ERROR: Multi-arch manifest detected! Lambda will reject this."
    echo "   The image was built with buildx or has multiple architectures."
    echo "   Please ensure you're using plain 'docker build' without buildx."
    exit 1
elif [[ "$MANIFEST_TYPE" == "application/vnd.oci.image.manifest.v1+json" ]] || \
     [[ "$MANIFEST_TYPE" == "application/vnd.docker.distribution.manifest.v2+json" ]]; then
    echo "✅ Single-arch manifest confirmed. Lambda will accept this image."
else
    echo "⚠️  Unexpected manifest type: $MANIFEST_TYPE"
fi

echo "Docker image pushed successfully!"

# Step 4: Deploy Lambda Stack
echo ""
echo "=========================================="
echo "Step 4: Deploying Lambda Stack"
echo "=========================================="
aws cloudformation deploy \
    --template-file lambda-template.yaml \
    --stack-name $LAMBDA_STACK_NAME \
    --parameter-overrides \
        InfraStackName=$INFRA_STACK_NAME \
        LambdaImageUri=$ECR_REPO_URI:$IMAGE_TAG \
        SourcePrefix=incoming/ \
        ProcessedPrefix=processed/ \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

echo "Lambda stack deployed successfully!"

# Step 5: Configure S3 Event Notification
echo ""
echo "=========================================="
echo "Step 5: Configuring S3 Event Notification"
echo "=========================================="

# Get bucket and Lambda ARN
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $INFRA_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text)

LAMBDA_ARN=$(aws cloudformation describe-stacks \
    --stack-name $LAMBDA_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`FunctionArn`].OutputValue' \
    --output text)

echo "Bucket: $BUCKET_NAME"
echo "Lambda: $LAMBDA_ARN"

# Create notification configuration
cat > /tmp/notification.json <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "incoming/"
            }
          ]
        }
      }
    }
  ]
}
EOF

# Apply notification configuration
aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration file:///tmp/notification.json

rm /tmp/notification.json

echo "S3 event notification configured successfully!"

# Step 6: Display Outputs
echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Infrastructure Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name $INFRA_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo "Lambda Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name $LAMBDA_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo "To test, upload a file:"
echo "aws s3 cp test-file.json s3://$BUCKET_NAME/incoming/"
echo ""
echo "Check processed files:"
echo "aws s3 ls s3://$BUCKET_NAME/processed/"
echo ""
echo "View logs:"
echo "aws logs tail /aws/lambda/$LAMBDA_STACK_NAME-file-compression --follow"
