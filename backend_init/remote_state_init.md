## initializing project

###### creating user to deploy remote backends

1. create IAM user and IAM user group **for remote state creation** (add the user to the group).
3. create this policy (limit access is good practice):
```json

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "s3:CreateBucket",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:PutBucketTagging",
        "s3:PutEncryptionConfiguration",
        "s3:PutBucketVersioning",
        "dynamodb:TagResource"  
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/*",
        "arn:aws:s3:::*/*",
        "arn:aws:s3:::*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "il-central-1"
        }
      }
    }
  ]
}

```
4. attach the policy to the group
5. activate `remote_state_init.sh` this will create **S3 object** for remote backend
and **DynamoDB table** for locking the state during write operations to prevent race conditions.
and a ``backend.tf`` file pointing to those.
###### creating IAM user to deploy the application
```
