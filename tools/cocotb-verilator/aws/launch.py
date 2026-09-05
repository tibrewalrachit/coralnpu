#!/usr/bin/env python3
"""Launch an EC2 instance that runs the Coral cocotb suite under tuned Verilator
and prints how to follow it. Costs money: ask before running.

  python3 launch.py --region us-east-1 --type c7i.8xlarge --branch <branch> \
      [--repo https://github.com/tibrewalrachit/coralnpu.git] [--parallel 8] [--threads 2] [--key NAME]
  python3 launch.py --region us-east-1 --status i-xxxx       # tail the run log via SSM (needs SSM role)
  python3 launch.py --region us-east-1 --terminate i-xxxx
"""
import argparse, base64, json, sys, time
from pathlib import Path
import boto3

ap = argparse.ArgumentParser()
ap.add_argument("--region", required=True)
ap.add_argument("--type", default="c7i.8xlarge")
ap.add_argument("--repo", default="https://github.com/tibrewalrachit/coralnpu.git")
ap.add_argument("--branch", default="claude/cva6-coral-firesim-f2-ob5gdg")
ap.add_argument("--parallel", type=int, default=8)
ap.add_argument("--threads", type=int, default=2)
ap.add_argument("--key", default=None, help="EC2 key pair name (optional)")
ap.add_argument("--disk", type=int, default=100)
ap.add_argument("--status", metavar="INSTANCE_ID")
ap.add_argument("--terminate", metavar="INSTANCE_ID")
a = ap.parse_args()
ec2 = boto3.client("ec2", region_name=a.region)
ssm = boto3.client("ssm", region_name=a.region)
iam = boto3.client("iam")

if a.terminate:
    ec2.terminate_instances(InstanceIds=[a.terminate]); print("terminating", a.terminate); sys.exit(0)

if a.status:
    r = ssm.send_command(InstanceIds=[a.status], DocumentName="AWS-RunShellScript",
                         Parameters={"commands": ["tail -n 60 /home/ubuntu/coral-cocotb-run.log; ls /home/ubuntu/coral-cocotb/results 2>/dev/null | head -40"]})
    cid = r["Command"]["CommandId"]; time.sleep(3)
    for _ in range(20):
        o = ssm.get_command_invocation(CommandId=cid, InstanceId=a.status)
        if o["Status"] in ("Success", "Failed", "Cancelled", "TimedOut"): print(o["StandardOutputContent"], o["StandardErrorContent"]); break
        time.sleep(2)
    sys.exit(0)

# Ubuntu 24.04 AMI from the public SSM parameter
ami = ssm.get_parameter(Name="/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id")["Parameter"]["Value"]
# instance profile with SSM (so results can be read over HTTPS without ssh)
role = "coral-cocotb-ssm"
try:
    iam.get_role(RoleName=role)
except iam.exceptions.NoSuchEntityException:
    iam.create_role(RoleName=role, AssumeRolePolicyDocument=json.dumps({"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": "ec2.amazonaws.com"}, "Action": "sts:AssumeRole"}]}))
    iam.attach_role_policy(RoleName=role, PolicyArn="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore")
    iam.create_instance_profile(InstanceProfileName=role); iam.add_role_to_instance_profile(InstanceProfileName=role, RoleName=role); time.sleep(10)
# security group: 22 + 443 inbound
vpc = ec2.describe_vpcs(Filters=[{"Name": "is-default", "Values": ["true"]}])["Vpcs"][0]["VpcId"]
sgs = ec2.describe_security_groups(Filters=[{"Name": "group-name", "Values": ["coral-cocotb"]}])["SecurityGroups"]
if sgs: sg = sgs[0]["GroupId"]
else:
    sg = ec2.create_security_group(GroupName="coral-cocotb", Description="coral cocotb verilator", VpcId=vpc)["GroupId"]
    ec2.authorize_security_group_ingress(GroupId=sg, IpPermissions=[{"IpProtocol": "tcp", "FromPort": p, "ToPort": p, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]} for p in (22, 443)])
ud = (Path(__file__).parent / "user-data.sh").read_text()
for k, v in {"__REPO__": a.repo, "__BRANCH__": a.branch, "__PARALLEL__": str(a.parallel), "__THREADS__": str(a.threads), "__S3__": ""}.items(): ud = ud.replace(k, v)
kw = dict(ImageId=ami, InstanceType=a.type, MinCount=1, MaxCount=1, UserData=ud, SecurityGroupIds=[sg],
          IamInstanceProfile={"Name": role},
          BlockDeviceMappings=[{"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": a.disk, "VolumeType": "gp3"}}],
          TagSpecifications=[{"ResourceType": "instance", "Tags": [{"Key": "Name", "Value": "coral-cocotb-verilator"}]}])
if a.key: kw["KeyName"] = a.key
inst = ec2.run_instances(**kw)["Instances"][0]
iid = inst["InstanceId"]; print("launched", iid, a.type, ami)
ec2.get_waiter("instance_running").wait(InstanceIds=[iid])
ip = ec2.describe_instances(InstanceIds=[iid])["Reservations"][0]["Instances"][0].get("PublicIpAddress")
print(f"running: {iid} public ip {ip}\n  follow: python3 launch.py --region {a.region} --status {iid}\n  ssh -p 443 ubuntu@{ip}   (with --key)\n  terminate: python3 launch.py --region {a.region} --terminate {iid}")
