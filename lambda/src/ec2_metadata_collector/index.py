import json
import os
import logging
from datetime import datetime, timezone
import boto3

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Initialize S3 client globally
s3_client = boto3.client("s3")

def lambda_handler(event, context):
    """
    Lambda handler for collecting EC2 instance metadata.
    
    Triggered by EventBridge when EC2 state changes occur.
    Collects metadata and stores it in S3.
    """
    try:
        # Extract instance ID and region from event
        instance_id = event["detail"]["instance-id"]
        region = event["region"]
        
        logger.info(f"Processing metadata collection for instance: {instance_id} in region: {region}")
        
        # Initialize EC2 client with region from event
        ec2_client = boto3.client("ec2", region_name=region)
        
        # Fetch instance metadata from EC2
        response = ec2_client.describe_instances(InstanceIds=[instance_id])
        
        # Check if instance was found
        if not response["Reservations"]:
            logger.error(f"No reservation found for instance: {instance_id}")
            return {
                "statusCode": 404,
                "body": json.dumps({"error": f"Instance {instance_id} not found"})
            }
        
        # Extract instance data
        instance = response["Reservations"][0]["Instances"][0]
        
        # Build metadata dictionary with all 18 fields
        metadata = {
            "instance_id": instance.get("InstanceId"),
            "instance_type": instance.get("InstanceType"),
            "state": instance.get("State", {}).get("Name"),
            "launch_time": instance.get("LaunchTime").isoformat() if instance.get("LaunchTime") else None,
            "region": region,
            "availability_zone": instance.get("Placement", {}).get("AvailabilityZone"),
            "public_ip_address": instance.get("PublicIpAddress"),
            "private_ip_address": instance.get("PrivateIpAddress"),
            "public_dns_name": instance.get("PublicDnsName"),
            "private_dns_name": instance.get("PrivateDnsName"),
            "ami_id": instance.get("ImageId"),
            "key_name": instance.get("KeyName"),
            "subnet_id": instance.get("SubnetId"),
            "vpc_id": instance.get("VpcId"),
            "architecture": instance.get("Architecture"),
            "platform": instance.get("Platform", "linux"),
            "security_groups": [
                {
                    "id": sg.get("GroupId"),
                    "name": sg.get("GroupName")
                }
                for sg in instance.get("SecurityGroups", [])
            ],
            "tags": {
                tag.get("Key"): tag.get("Value")
                for tag in instance.get("Tags", [])
            },
            "collected_at": datetime.now(timezone.utc).isoformat()
        }
        
        # Generate S3 key with timestamp
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        s3_key = f"ec2-metadata/{instance_id}/{timestamp}.json"
        
        # Get S3 bucket name from environment variable
        bucket_name = os.environ["S3_BUCKET_NAME"]
        
        # Upload metadata to S3
        s3_client.put_object(
            Bucket=bucket_name,
            Key=s3_key,
            Body=json.dumps(metadata, indent=2, default=str),
            ContentType="application/json"
        )
        
        logger.info(f"Successfully uploaded metadata to s3://{bucket_name}/{s3_key}")
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Metadata collected successfully",
                "instance_id": instance_id,
                "s3_key": s3_key
            })
        }
        
    except KeyError as e:
        logger.error(f"Missing required field in event: {e}")
        return {
            "statusCode": 400,
            "body": json.dumps({"error": f"Missing required field: {str(e)}"})
        }
    
    except Exception as e:
        logger.error(f"Error collecting metadata: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
