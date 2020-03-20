#key pair
resource "aws_key_pair" "web_admin" {
    key_name = "$KEY_NAME"
    public_key = "${file("$PUBLIC_KEY_PATH")}" #EX)"${file("~/.ssh/id_rsa.pub")}"
}

#instance
resource "aws_instance" "nginx_web" {
    ami = "$AMI_KEY"
    instance_type = "t2.micro"
    key_name = "${aws_key_pair.web_admin.key_name}"
    vpc_security_group_ids = [
        "${aws_security_group.default.id}"
    ]
    subnet_id = "${aws_subnet.public_subnet_a.id}"
    associate_public_ip_address = true
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("$PRIVATE_KEY_PATH")}" #EX)"${file("~/.ssh/id_rsa")}"
        host = "${self.public_ip}"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo apt-get -y update",
            "sudo apt-get -y install nginx",
            "sudo service nginx start",
        ]
    }
}

#VPC
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = { Name = "main" }
}

#subnet
resource "aws_subnet" "public_subnet_a" {
    vpc_id = "${aws_vpc.main.id}"
    availability_zone = "us-east-2a"
    cidr_block ="10.0.1.0/24"

    map_public_ip_on_launch = true
    tags = { Name = "Public Subnet 2A" }
}

#security group default
resource "aws_security_group" "default" {
    name        = "terraform_example"
    description = "Used in the terraform"
    vpc_id      = "${aws_vpc.main.id}"

    #차후 내 아이피로 입력
    # SSH access from anywhere
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTP access from the VPC
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # outbound internet access
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#internet gateway
resource "aws_internet_gateway" "default" {
    vpc_id = "${aws_vpc.main.id}"
}

#router table
resource "aws_default_route_table" "main" {
    default_route_table_id = "${aws_vpc.main.default_route_table_id}"

    tags = { Name = "public route table"}
}

# route table association
resource "aws_route_table_association" "public_2a" {
    subnet_id      = "${aws_subnet.public_subnet_a.id}"
    route_table_id = "${aws_vpc.main.default_route_table_id}"
}

resource "aws_route" "route_public" {
    route_table_id = "${aws_vpc.main.default_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
}
