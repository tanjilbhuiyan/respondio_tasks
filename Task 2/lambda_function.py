import os
import zipfile
from io import BytesIO

import boto3

s3_client = boto3.client("s3")

BUCKET_NAME = os.environ["BUCKET_NAME"]
SOURCE_PREFIX = os.environ["SOURCE_PREFIX"]
PROCESSED_PREFIX = os.environ["PROCESSED_PREFIX"]


def lambda_handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        if not key.startswith(SOURCE_PREFIX) or key.endswith(".zip"):
            continue

        file_name = os.path.basename(key)
        zip_file_name = f"{os.path.splitext(file_name)[0]}.zip"
        processed_key = f"{PROCESSED_PREFIX}{zip_file_name}"

        file_obj = BytesIO()
        s3_client.download_fileobj(bucket, key, file_obj)
        file_obj.seek(0)

        zip_buffer = BytesIO()
        with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
            zip_file.writestr(file_name, file_obj.read())

        zip_buffer.seek(0)
        s3_client.upload_fileobj(zip_buffer, bucket, processed_key)

        s3_client.delete_object(Bucket=bucket, Key=key)

        print(f"Compressed {key} to {processed_key} and deleted original")

    return {"statusCode": 200, "body": "Success"}
