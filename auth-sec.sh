#!/bin/bash

aws ec2 authorize-security-group-ingress \
  --group-id $TARGET_SECURITY_GROUP_ID \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$DESTINATION_IP/32,Description='temporary access evanh'}]" \
  --profile $AWS_PROFILE

mkdir -p ~/.ssh/temp

KEY_NAME="temp_key_$(date +%Y%m%d%H%M%S)"
ssh-keygen -t rsa -N "" -f ~/.ssh/temp/"$KEY_NAME"

PUBLIC_KEY_PATH=~/.ssh/temp/"$KEY_NAME".pub
PRIVATE_KEY_PATH=~/.ssh/temp/"$KEY_NAME"

cat "$PUBLIC_KEY_PATH" | ssh -o StrictHostKeyChecking=no $TARGET_SSH "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

DESTINATION_PRIVATE_KEY_PATH="~/.ssh/$KEY_NAME"

scp "$PRIVATE_KEY_PATH" "$DESTINATION_SSH":"$DESTINATION_PRIVATE_KEY_PATH"
ssh "$DESTINATION_SSH" "chmod 600 $DESTINATION_PRIVATE_KEY_PATH"
ssh -o StrictHostKeyChecking=no "$DESTINATION_SSH" "scp -o 'StrictHostKeyChecking=no' -i $DESTINATION_PRIVATE_KEY_PATH forge@$TARGET_IP:~/test.txt /home/forge/test_from_target.txt"

KEY_STRING=$(awk '{print $2}' "$PUBLIC_KEY_PATH")

ssh "$DESTINATION_SSH" "rm -f $DESTINATION_PRIVATE_KEY_PATH"
rm -f "$PRIVATE_KEY_PATH" "$PUBLIC_KEY_PATH"

ssh -o StrictHostKeyChecking=no "$TARGET_SSH" "sed -i '/$KEY_STRING/d' ~/.ssh/authorized_keys"

aws ec2 revoke-security-group-ingress \
  --group-id "$TARGET_SECURITY_GROUP_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$DESTINATION_IP/32,Description='temporary access evanh'}]" \
  --profile "$AWS_PROFILE"
