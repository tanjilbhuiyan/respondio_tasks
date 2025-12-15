# S3 File Compression Lambda

## Prerequisites

- AWS CLI installed and configured
- AWS SAM CLI installed
- AWS account with appropriate permissions

## Deployment Steps

### 1. Create S3 Bucket Manually

Create an S3 bucket with two folders:

```bash
aws s3 mb s3://my-file-compression-bucket-12345
```

The Lambda will use:
- `incoming/` - for source files
- `processed/` - for compressed ZIP files

### 2. Deploy Lambda with SAM

```bash
sam build
sam deploy --guided
```

Follow the prompts:
- Stack Name: `s3-file-compression-stack`
- AWS Region: `us-east-1`
- Parameter BucketName: `my-file-compression-bucket-12345`
- Parameter SourcePrefix: `incoming/`
- Parameter ProcessedPrefix: `processed/`
- Allow SAM CLI IAM role creation: Y
- Save arguments to configuration file: Y

### 3. Configure S3 Event Trigger Manually

After deployment, configure the S3 trigger:

1. Go to AWS Console → S3 → `my-file-compression-bucket-12345`
2. Navigate to **Properties** → **Event notifications**
3. Click **Create event notification**
   - Event name: `lambda-trigger`
   - Event types: Select **All object create events**
   - Prefix: `incoming/`
   - Destination: **Lambda function**
   - Lambda function: `s3-file-compression`
4. Save changes

## Testing

Upload a test file:

```bash
aws s3 cp test-file.json s3://my-file-compression-bucket-12345/incoming/
```

Check processed files:

```bash
aws s3 ls s3://my-file-compression-bucket-12345/processed/
```

View Lambda logs:

```bash
sam logs -n s3-file-compression --tail
```

## Cleanup

```bash
aws s3 rm s3://my-file-compression-bucket-12345 --recursive
sam delete --stack-name s3-file-compression-stack
aws s3 rb s3://my-file-compression-bucket-12345
```
