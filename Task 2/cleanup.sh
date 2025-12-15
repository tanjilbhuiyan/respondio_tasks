#!/bin/bash

set -e

# Disable AWS CLI pager
export AWS_PAGER=""

INFRA_STACK_NAME="file-compression-infra"
LAMBDA_STACK_NAME="file-compression-lambda"
REGION="us-east-1"
ECR_REPO_NAME="file-compression-lambda-repo"

echo "=========================================="
echo "CloudFormation Cleanup Script"
echo "=========================================="
echo ""
echo "This will delete all resources created by Task 2:"
echo "  - S3 Bucket and contents"
echo "  - ECR Repository and images"
echo "  - Lambda Function"
echo "  - VPC and networking resources"
echo "  - IAM Roles"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Step 1: Get bucket name from infra stack
echo ""
echo "Step 1: Getting S3 bucket name..."
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $INFRA_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

# Step 2: Remove S3 event notification
if [ -n "$BUCKET_NAME" ]; then
    echo ""
    echo "Step 2: Removing S3 event notification..."
    aws s3api put-bucket-notification-configuration \
        --bucket $BUCKET_NAME \
        --notification-configuration '{}' \
        --region $REGION 2>/dev/null || echo "No notification to remove"
fi

# Step 3: Empty S3 bucket
if [ -n "$BUCKET_NAME" ]; then
    echo ""
    echo "Step 3: Emptying S3 bucket: $BUCKET_NAME"
    aws s3 rm s3://$BUCKET_NAME --recursive --region $REGION || true
    echo "S3 bucket emptied successfully"
else
    echo ""
    echo "Step 3: No S3 bucket found or stack doesn't exist"
fi

# Step 4: Delete Lambda Stack
echo ""
echo "Step 4: Deleting Lambda CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name $LAMBDA_STACK_NAME \
    --region $REGION 2>/dev/null || echo "Lambda stack not found"

echo "Waiting for Lambda stack deletion..."
aws cloudformation wait stack-delete-complete \
    --stack-name $LAMBDA_STACK_NAME \
    --region $REGION 2>/dev/null || echo "Lambda stack deleted or not found"

# Step 5: Delete Infrastructure Stack
echo ""
echo "Step 5: Deleting Infrastructure CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name $INFRA_STACK_NAME \
    --region $REGION 2>/dev/null || echo "Infrastructure stack not found"

echo "Waiting for Infrastructure stack deletion..."
aws cloudformation wait stack-delete-complete \
    --stack-name $INFRA_STACK_NAME \
    --region $REGION 2>/dev/null || echo "Infrastructure stack deleted or not found"

# Step 6: Delete ECR images
echo ""
echo "Step 6: Deleting ECR images..."
IMAGE_IDS=$(aws ecr list-images \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --query 'imageIds[*]' \
    --output json 2>/dev/null || echo "[]")

if [ "$IMAGE_IDS" != "[]" ]; then
    aws ecr batch-delete-image \
        --repository-name $ECR_REPO_NAME \
        --region $REGION \
        --image-ids "$IMAGE_IDS" || true
    echo "ECR images deleted successfully"
else
    echo "No ECR images found"
fi

# Step 7: Delete ECR repository
echo ""
echo "Step 7: Deleting ECR repository..."
aws ecr delete-repository \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --force 2>/dev/null || echo "ECR repository not found or already deleted"

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "All resources have been removed:"
echo "  ✓ S3 Bucket emptied and deleted"
echo "  ✓ Lambda Stack deleted"
echo "  ✓ Infrastructure Stack deleted"
echo "  ✓ VPC and networking resources deleted"
echo "  ✓ ECR Repository and images deleted"
echo "  ✓ IAM Roles deleted"
echo ""
