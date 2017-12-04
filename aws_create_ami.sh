#!/bin/bash
# Create an AMI of the EC2 instances for backup based on tag “Backup” (if set to “true” - instance should be backup).
while read aws_instId; do
	name=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[KeyName]' --output text)
	tags_backup=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$aws_instId" "Name=key,Values=Backup" --query 'Tags[*].[Value]' --output text) > /dev/null
	if [ "$tags_backup" == "true" ]; then
		name_ami="$name"_`date +%Y%m%d`
#Check existing AMI(if "false" - create AMI)
		test_name_ami=$(aws ec2 describe-images --owners self --query 'Images[*].[Name]' --output text | grep -w $name_ami)
		if [ -z $test_name_ami ]; then
			aws ec2 create-image --instance-id "$aws_instId" --name "$name_ami" > /dev/null
		fi
		test_name_ami=
	fi
done < <(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]' --output text)
# The full list of AMIs and remove AMIs older than 7 days.
echo  -e "  Name \t ImageId \t CreationDate \t State"
while read aws_imageId; do
	cr_date=$(aws ec2 describe-images --image-ids "$aws_imageId" --query 'Images[*].[CreationDate]' --output text)
	let date_diff=($(date -d "$cr_date" +%s)-`date +%s`)/86400
	if [ "$date_diff" -le "7" ]; then
		if [ `date +%Y%m%d` -eq $(date -d $cr_date +%Y%m%d) ]; then
			echo -e '\E[32;40m' $(aws ec2 describe-images --image-ids "$aws_imageId" --query 'Images[*].[Name,ImageId,CreationDate,State]' --output text)
		else
			echo -e '\E[33;40m' $(aws ec2 describe-images --image-ids "$aws_imageId" --query 'Images[*].[Name,ImageId,CreationDate,State]' --output text)
		fi
		tput sgr0
	else
		aws ec2 deregister-image --image-id "$aws_imageId"
	fi
done < <(aws ec2 describe-images --owners self --query 'Images[*].[ImageId]' --output text)

exit 0
