# AWS S3 File Compression Pipeline

Automated serverless solution for compressing files uploaded to S3 using AWS Lambda, CloudFormation, and Docker.

---

## 📋 Overview

This repository demonstrates a production-ready AWS Lambda-based pipeline that automatically compresses files uploaded to S3. The solution showcases infrastructure as code, serverless architecture, cost optimization, and scalability analysis.

### Key Features

- ✅ Serverless, event-driven architecture
- ✅ Automatic file compression (ZIP format)
- ✅ Infrastructure as Code (CloudFormation/SAM)
- ✅ Docker-based Lambda deployment
- ✅ VPC isolation with private subnets
- ✅ **Cost-optimized:** S3 Gateway VPC Endpoint (saves $647K/month vs NAT Gateway)
- ✅ Lambda versioning and rollback support
- ✅ Comprehensive cost and scalability analysis

---

## 📁 Repository Structure

```
respondio/
│
├── 📄 README.md                    # This file (project overview)
├── 📄 TASKS.md                     # Original task requirements
│
├── 📁 Task 1/                      # Simple SAM-based solution
│   ├── README.md                   # Task 1 documentation
│   ├── template.yaml               # SAM template
│   └── lambda_function.py          # Python Lambda code
│
├── 📁 Task 2/                      # Production CloudFormation solution
│   ├── README.md                   # Task 2 documentation
│   ├── infra-template.yaml         # Infrastructure stack (VPC, S3, etc.)
│   ├── lambda-template.yaml        # Lambda stack
│   ├── lambda_function.py          # Python Lambda code
│   ├── Dockerfile                  # Lambda container image
│   ├── deploy.sh                   # Automated deployment script
│   ├── cleanup.sh                  # Cleanup script
│   └── template.yaml               # Single-stack template (backup)
│
├── 📁 Task 4/                      # Cost analysis
│   └── README.md                   # Detailed cost breakdown & optimization
│
└── 📁 Task 5/                      # Scalability & bottleneck analysis
    └── README.md                   # Scalability assessment & recommendations
```

---

## 🚀 Quick Links

### Task Documentation

| Task | Description | Documentation |
|------|-------------|---------------|
| **[Task 1](Task%201/)** | Basic S3-triggered Lambda using AWS SAM | [📖 Read Documentation](Task%201/README.md) |
| **[Task 2](Task%202/)** | Production VPC solution with Docker Lambda | [📖 Read Documentation](Task%202/README.md) |
| **Task 3** | Version control & documentation | ✅ Completed (this repo) |
| **[Task 4](Task%204/)** | Cost analysis for 1M files/hour | [📖 Read Documentation](Task%204/README.md) |
| **[Task 5](Task%205/)** | Scalability & bottleneck analysis | [📖 Read Documentation](Task%205/README.md) |

---

## 🏗️ Architecture

### Task 2 Architecture (Production Solution)

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Custom VPC (10.0.0.0/16)              │    │
│  │                                                     │    │
│  │  ┌─────────────────┐      ┌─────────────────┐    │    │
│  │  │ Private Subnet  │      │ Private Subnet  │    │    │
│  │  │   (AZ-1)        │      │   (AZ-2)        │    │    │
│  │  │ 10.0.1.0/24     │      │ 10.0.2.0/24     │    │    │
│  │  │                 │      │                 │    │    │
│  │  │  ┌──────────┐   │      │  ┌──────────┐  │    │    │
│  │  │  │  Lambda  │   │      │  │  Lambda  │  │    │    │
│  │  │  │ Function │   │      │  │ Function │  │    │    │
│  │  │  └────┬─────┘   │      │  └────┬─────┘  │    │    │
│  │  └───────┼─────────┘      └───────┼────────┘    │    │
│  │          │                        │              │    │
│  │          └────────────┬───────────┘              │    │
│  │                       │                          │    │
│  │                       ▼                          │    │
│  │            ┌──────────────────────┐             │    │
│  │            │  S3 Gateway VPC      │             │    │
│  │            │     Endpoint         │             │    │
│  │            │    (FREE - $0)       │             │    │
│  │            └──────────┬───────────┘             │    │
│  └────────────────────────┼─────────────────────────┘    │
│                           │                              │
│                           ▼                              │
│                  ┌─────────────────┐                     │
│                  │   S3 Bucket     │                     │
│                  │                 │                     │
│                  │  incoming/      │                     │
│                  │  processed/     │                     │
│                  └─────────────────┘                     │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Key Design Decision:** Using S3 Gateway VPC Endpoint instead of NAT Gateway saves **$647,773/month** (96% infrastructure cost reduction).

---

## 💰 Cost Summary

### Processing 1,000,000 Files/Hour

**Base Monthly Cost: $27,363.40**

| Service | Monthly Cost | % of Total |
|---------|--------------|------------|
| AWS Lambda (compute) | $18,000.00 | 66% |
| AWS Lambda (requests) | $144.00 | <1% |
| Amazon S3 (storage) | $5,331.20 | 19% |
| Amazon S3 (requests) | $3,888.00 | 14% |
| Amazon ECR | $0.20 | <1% |

**Optimized Monthly Cost: $13,970.40** (49% reduction)

**Cost per file:** $0.0000380 (3.8 cents per 1,000 files)

### Key Savings

- **S3 Gateway VPC Endpoint vs NAT Gateway:** $647,773/month saved ✅
- **S3 Lifecycle to Glacier:** $4,371/month saved
- **Lambda memory optimization:** $4,500/month potential savings
- **Log sampling:** $356/month saved

📊 [Full Cost Analysis](Task%204/README.md)

---

## 📈 Scalability Assessment

### Can It Handle 1,000,000 Files/Hour?

**Answer: YES** (with identified mitigations)

| Aspect | Rating | Status |
|--------|--------|--------|
| **Scalability** | 8/10 | ✅ Handles 277 files/sec (831 concurrent executions) |
| **Cost Efficiency** | 9/10 | ✅ $0.0000380 per file (highly competitive) |
| **Reliability** | 7/10 | ⚠️ Needs DLQ and alarms for production |
| **Performance** | 8/10 | ✅ <5s average latency, <15s p99 |

### Critical Bottlenecks Identified

1. **Lambda concurrency limits** (HIGH) - Need 2,000 concurrent limit
2. **S3 prefix rate limits** (HIGH) - Need partitioning for burst traffic
3. **VPC cold starts** (MEDIUM) - Monitor and optimize
4. **Memory configuration** (HIGH) - Benchmark required (66% of cost)
5. **No error handling/DLQ** (CRITICAL) - Must implement before production
6. **CloudWatch logs volume** (MEDIUM) - $360/month optimization opportunity

📊 [Full Scalability Analysis](Task%205/README.md)

