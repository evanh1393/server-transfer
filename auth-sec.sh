#!/bin/bash
# Using AWS cli 2 with federated priveleges may need to change this if not...
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

ssh "$DESTINATION_SSH" "mkdir -p $DESTINATION_FOLDER_PATH"

CURRENT_MONTH=$(date +"%Y/%m")
LAST_MONTH=$(date -d "1 month ago" +"%Y/%m")
TWO_MONTHS_AGO=$(date -d "2 months ago" +"%Y/%m")

ssh -o StrictHostKeyChecking=no "$DESTINATION_SSH" \
  "rsync -avz -e --progress 'ssh -o StrictHostKeyChecking=no -i $DESTINATION_PRIVATE_KEY_PATH' \
  $TARGET_USER@$TARGET_IP:$TARGET_FOLDER_PATH/$CURRENT_MONTH \
  $TARGET_USER@$TARGET_IP:$TARGET_FOLDER_PATH/$LAST_MONTH \
  $TARGET_USER@$TARGET_IP:$TARGET_FOLDER_PATH/$TWO_MONTHS_AGO \
  $DESTINATION_FOLDER_PATH"

rm -f "$PRIVATE_KEY_PATH" "$PUBLIC_KEY_PATH"
ssh "$DESTINATION_SSH" "rm -f $DESTINATION_PRIVATE_KEY_PATH"

KEY_STRING=$(awk '{print $2}' "$PUBLIC_KEY_PATH")
ssh -o StrictHostKeyChecking=no "$TARGET_SSH" "sed -i '/$KEY_STRING/d' ~/.ssh/authorized_keys"

aws ec2 revoke-security-group-ingress \
  --group-id "$TARGET_SECURITY_GROUP_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$DESTINATION_IP/32,Description='temporary access evanh'}]" \
  --profile "$AWS_PROFILE"
