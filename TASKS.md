---

## Task 1

Create an AWS Lambda using AWS SAM to trigger every time a new Object is added to your bucket. This function can be written in either NodeJS or Python. Its primary task is to compress the newly added object into a ZIP format and then upload this ZIP file back into the same S3 bucket. Additionally, ensure that your Lambda function is configured to delete the original object from the bucket once it has been successfully compressed and uploaded.

---

## Task 2

Create an S3 bucket and connect it to the Lambda using Cloudformation within the same stack as Lambda. This part should be written in a file called `template.yaml` and stored in the root of your project. The company requires that all compute resources run inside their custom VPC and private subnets. Configure the Lambda to run in private subnets of a VPC you define in the same template. They also want to Dockerize their Lambda. Each deployment must create a new version of the Lambda so the company can reliably roll back to prior releases.

Use AWS Free Tier on your personal account to examine the deployment.

---

## Task 3

Commit your changes using best practices from the beginning to the end. Our goal is to understand your flow just by reading the commit history of your project. Push all your changes to a public Github repository and add documentation to the project by adding a README file.

---

## Task 4

Provide a cost analysis section about your solution inside the README file. The company is processing 1000,000 files per hour with an average size of 10 MB per file. Can you provide calculations about the monthly cost after the addition of this feature? Estimate a final monthly figure in USD and add any suggestions that you have which could help us with saving more costs?

---

## Task 5

Is your overall solution scalable and cost efficient at the given scale? Add a section in README and express your concerns regarding any potential bottlenecks that could impact our system.

---
