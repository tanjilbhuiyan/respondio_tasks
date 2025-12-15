## Cost Analysis (Task 4)

### Scenario Requirements

- **Files per hour**: 1,000,000 files
- **Average file size**: 10 MB
- **Compression ratio**: ~20% (10 MB → ~8 MB)
- **Monthly volume**: 720 million files (720M)
- **Monthly data**: 7.2 PB input, ~5.76 PB output

### Detailed Cost Breakdown

#### 1. AWS Lambda Costs

**Request Charges:**
- Monthly requests: 720,000,000
- Cost per 1M requests: $0.20
- **Request cost**: (720M / 1M) × $0.20 = **$144.00/month**

**Compute Charges:**
- Memory allocation: 512 MB (0.5 GB)
- Estimated execution time per file: 3 seconds
  - Download 10 MB from S3: ~0.5s
  - Compress: ~1.5s
  - Upload 8 MB to S3: ~0.5s
  - Delete original: ~0.5s
- Total GB-seconds: 720M × 3s × 0.5 GB = 1,080,000,000 GB-seconds
- Cost per GB-second (x86_64): $0.0000166667
- **Compute cost**: 1,080,000,000 × $0.0000166667 = **$18,000.00/month**

**Lambda Total**: $18,144.00/month

---

#### 2. Amazon S3 Costs

**Storage Costs:**
- Assuming files are processed and deleted within 1 day
- Average storage: (7.2 PB / 30 days) = 240 TB = 240,000 GB average daily storage
- S3 Standard tiered pricing:
  - First 50 TB (51,200 GB): $0.023/GB = $1,177.60
  - Next 450 TB (188,800 GB): $0.022/GB = $4,153.60
- **Storage cost**: $1,177.60 + $4,153.60 = **$5,331.20/month**

**PUT Request Costs (uploading compressed files):**
- PUT requests: 720,000,000
- Cost per 1,000 PUTs: $0.005
- **PUT cost**: (720M / 1,000) × $0.005 = **$3,600.00/month**

**GET Request Costs (downloading for compression):**
- GET requests: 720,000,000
- Cost per 1,000 GETs: $0.0004
- **GET cost**: (720M / 1,000) × $0.0004 = **$288.00/month**

**DELETE Request Costs:**
- DELETE requests: 720,000,000
- **DELETE cost**: **$0.00** (free)

**S3 Total**: $9,219.20/month

---

#### 3. Data Transfer Costs

**Lambda ↔ S3 Transfer:**
- Using S3 Gateway VPC Endpoint: **$0.00** (free)
- Data transferred: ~14.4 PB/month (7.2 PB in + 5.76 PB out + 1.44 PB deletes)
- **Savings vs NAT Gateway**: ~$648,000/month (see comparison below)

**VPC Costs:**
- VPC: Free
- Private subnets: Free
- Route tables: Free
- S3 Gateway VPC Endpoint: **$0.00** (free)

**VPC Total**: $0.00/month

---

#### 4. Amazon ECR (Docker Image Storage)

**Image Storage:**
- Average image size: ~200 MB
- Images stored (with lifecycle policy): 10 versions
- Total storage: 2 GB
- Cost: $0.10 per GB/month
- **ECR cost**: 2 × $0.10 = **$0.20/month** (negligible)

---

### 💰 Total Monthly Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| AWS Lambda (requests) | $144.00 |
| AWS Lambda (compute) | $18,000.00 |
| Amazon S3 (storage) | $5,331.20 |
| Amazon S3 (PUT requests) | $3,600.00 |
| Amazon S3 (GET requests) | $288.00 |
| Data Transfer (VPC Gateway) | $0.00 |
| Amazon ECR | $0.20 |
| **TOTAL** | **$27,363.40** |

---

### 📊 Cost Comparison: With vs Without S3 Gateway VPC Endpoint

#### Traditional Approach (NAT Gateway)

| Service | Monthly Cost |
|---------|--------------|
| NAT Gateway (2 AZs) | $64.80 |
| NAT Gateway data processing (14.4 PB × $0.045/GB) | $648,000.00 |
| **Traditional Total** | **$675,136.85** |

#### Our Approach (S3 Gateway VPC Endpoint)

| Service | Monthly Cost |
|---------|--------------|
| S3 Gateway VPC Endpoint | $0.00 |
| Data transfer | $0.00 |
| **Our Total** | **$27,363.40** |

**💡 Monthly Savings: $647,773.45 (96% cost reduction on infrastructure)**

---

### 🎯 Cost Optimization Recommendations

#### 1. **Use S3 Intelligent-Tiering** (Potential savings: ~$2,000/month)
- Automatically moves data to cheaper storage tiers
- If compressed files are accessed infrequently, they'll move to cheaper tiers
- No retrieval fees for Frequent/Infrequent Access tiers
- **Estimated savings**: 40% of storage cost = $2,132/month

#### 2. **Implement S3 Lifecycle Policies** (Potential savings: ~$4,371/month)
- Move processed files to Glacier Instant Retrieval after 7 days if they don't need immediate access
- Delete files after retention period (e.g., 90 days)
- S3 Glacier Instant Retrieval storage: $0.004/GB vs S3 Standard tiered pricing (avg ~$0.022/GB)
- Storage with Glacier: 240,000 GB × $0.004 = $960/month
- **Estimated savings**: $5,331 - $960 = **$4,371/month** on storage costs

#### 3. **Optimize Lambda Memory Configuration** (Potential savings: ~$5,000/month)
- Current: 512 MB
- Test with 256 MB or 384 MB
- Lower memory = lower cost, but may increase execution time
- **Benchmark**: Run tests to find optimal memory/speed balance
- **Estimated savings**: 20-30% of compute cost = $3,600-5,400/month

#### 4. **Use Lambda Reserved Concurrency** (Potential savings: ~$2,000/month)
- For predictable workloads (1M files/hour = 833 executions/second)
- Reserved Concurrency pricing can be cheaper for steady-state workloads
- **Estimated savings**: 10-15% of Lambda cost = $1,814-2,722/month

#### 5. **Compress More Efficiently** (Potential savings: ~$500/month)
- Current: ZIP compression (~20% reduction)
- Consider: GZIP, BZIP2, or LZMA for better compression ratios (40-60%)
- **Trade-off**: Longer compression time vs smaller storage/transfer
- **Estimated savings**: $500-1,000/month on storage and transfer

#### 6. **Batch Processing** (Potential savings: ~$1,000/month)
- Instead of 1 Lambda per file, batch 10-100 files per invocation
- Reduces request charges significantly
- Current: 720M requests × $0.20/M = $144
- Batched (100 files): 7.2M requests × $0.20/M = $1.44
- **Estimated savings**: $142.56/month on requests + reduced overhead

#### 7. **CloudWatch Logs Optimization** (Potential savings: ~$500/month)
- Lambda generates logs for all 720M invocations
- Estimated log size: 1 KB per invocation = 720 GB/month
- CloudWatch Logs: $0.50/GB = $360/month
- **Recommendation**: Set log retention to 7 days, export to S3 for long-term storage
- **Estimated savings**: $200-300/month

---

### 💡 Optimized Monthly Cost Projection

| Optimization | Monthly Savings |
|--------------|-----------------|
| Base Cost | $27,363.40 |
| S3 Intelligent-Tiering | -$2,132.00 |
| S3 Lifecycle to Glacier Instant Retrieval | -$4,371.00 |
| Lambda memory optimization (384 MB) | -$4,500.00 |
| Lambda Reserved Concurrency | -$2,000.00 |
| Batch processing (50 files/invocation) | -$140.00 |
| CloudWatch log optimization | -$250.00 |
| **Optimized Total** | **$13,970.40** |

**Total Potential Savings: $13,393.00/month (49% reduction)**

---

### 📈 Cost Scaling Analysis

| Files/Hour | Monthly Files | Lambda Cost | S3 Cost | Total Cost | Cost per File |
|------------|---------------|-------------|---------|------------|---------------|
| 100,000 | 72M | $1,814 | $922 | $2,736 | $0.0000380 |
| 500,000 | 360M | $9,072 | $4,610 | $13,682 | $0.0000380 |
| 1,000,000 | 720M | $18,144 | $9,219 | $27,363 | $0.0000380 |
| 2,000,000 | 1,440M | $36,288 | $18,438 | $54,726 | $0.0000380 |
| 5,000,000 | 3,600M | $90,720 | $46,095 | $136,815 | $0.0000380 |

**Key Insight**: Cost scales linearly at **$0.0000380 per file** (3.80 cents per 1,000 files).

---

### 🎓 Cost Analysis Summary

1. **Current monthly cost**: $27,363.40
2. **Optimized monthly cost**: $13,970.40 (with recommended optimizations)
3. **Cost per file**: $0.0000380 (base) → $0.0000194 (optimized)
4. **Biggest cost driver**: Lambda compute time (66% of total cost)
5. **Biggest saving**: S3 Gateway VPC Endpoint vs NAT Gateway ($647.7K/month saved)

**Recommendation**: Implement optimizations #1, #2, #3, and #6 for immediate 49% cost reduction with minimal architectural changes.

---

## Getting Started

### Prerequisites

- AWS CLI installed and configured
- Docker installed and running
- Python 3.9+ (for Task 1)
- Bash shell

### Quick Deploy

#### Task 1 (SAM - Simple Solution)
```bash
cd "Task 1"
sam deploy --guided
```

#### Task 2 (CloudFormation - Production Solution)
```bash
cd "Task 2"
./deploy.sh
```

### Testing

```bash
# Get bucket name
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name file-compression-infra \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text)

# Upload test file
echo '{"test": "data"}' > sample.json
aws s3 cp sample.json s3://$BUCKET_NAME/incoming/

# Check processed files
aws s3 ls s3://$BUCKET_NAME/processed/

# View logs
aws logs tail /aws/lambda/file-compression-lambda-file-compression --follow
```

### Cleanup

```bash
cd "Task 2"
./cleanup.sh
```

---

## Repository Structure

```
respondio/
├── README.md                    # This file (overview + cost analysis)
├── Tasks.md                     # Original task requirements
│
├── Task 1/                      # Simple SAM-based solution
│   ├── README.md                # Task 1 documentation
│   ├── template.yaml            # SAM template
│   ├── lambda_function.py       # Python Lambda code
│   └── .gitignore
│
└── Task 2/                      # Production CloudFormation solution
    ├── README.md                # Task 2 documentation
    ├── infra-template.yaml      # Infrastructure stack (VPC, S3, etc.)
    ├── lambda-template.yaml     # Lambda stack
    ├── lambda_function.py       # Python Lambda code
    ├── Dockerfile               # Lambda container image
    ├── deploy.sh                # Automated deployment script
    ├── cleanup.sh               # Cleanup script
    └── template.yaml            # Single-stack template (backup)
```

---

## Key Technologies

- **AWS Lambda**: Serverless compute
- **Amazon S3**: Object storage with event notifications
- **AWS CloudFormation**: Infrastructure as Code
- **AWS SAM**: Serverless Application Model
- **Docker**: Container-based Lambda deployment
- **Amazon VPC**: Network isolation
- **S3 Gateway VPC Endpoint**: Private S3 access
- **Amazon ECR**: Container registry
- **Python 3.12**: Lambda runtime
- **IAM**: Security and permissions
