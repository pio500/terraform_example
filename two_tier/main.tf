#keypair
resource "aws_key_pair" "web_admin" {
    key_name = "zik_admin"
    public_key = "${file("$PUBLIC_KEY_PATH")}" #EX)"${file("~/.ssh/id_rsa.pub")}"
}

#vpc
resource "aws_vpc" "main_vpc" {
    cidr_block = "10.1.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = { Name = "main_vpc"}
}

#Front End Subnet
resource "aws_subnet" "front_end_1a" {
    vpc_id = "${aws_vpc.main_vpc.id}"
    cidr_block = "10.1.1.0/24"
    availability_zone = "ap-northeast-1a"

    tags = { Name = "Frontend Subnet 1A"}
}


resource "aws_subnet" "front_end_1c" {
    vpc_id = "${aws_vpc.main_vpc.id}"
    cidr_block = "10.1.2.0/24"
    availability_zone = "ap-northeast-1c"

    tags = { Name = "Frontend Subnet 1C"}
}

#Back End Subnet
resource "aws_subnet" "back_end_1a" {
    vpc_id = "${aws_vpc.main_vpc.id}"
    cidr_block = "10.1.3.0/24"
    availability_zone = "ap-northeast-1a"

    tags = { Name = "Backend Subnet 1A"}
}

resource "aws_subnet" "back_end_1c" {
    vpc_id = "${aws_vpc.main_vpc.id}"
    cidr_block = "10.1.4.0/24"
    availability_zone = "ap-northeast-1c"

    tags = { Name = "Backend Subnet 1C"}
}


#Internet Gate Way
resource "aws_internet_gateway" "default" {
    vpc_id = "${aws_vpc.main_vpc.id}"
}



#secruity group elb
resource "aws_security_group" "elb" {
    name        = "terraform_example_elb"
    description = "Used in the terraform"
    vpc_id      = "${aws_vpc.main_vpc.id}"

    # HTTP access from anywhere
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

resource "aws_security_group" "default" {
    name        = "terraform_example"
    description = "Used in the terraform"
    vpc_id      = "${aws_vpc.main_vpc.id}"

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
        cidr_blocks = ["10.0.0.0/8"]
    }

    # outbound internet access
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_elb" "web" {
    name = "terraform-example-elb"

    subnets         = [
        "${aws_subnet.front_end_1a.id}",
        "${aws_subnet.front_end_1c.id}"
    ]
    security_groups = [
        "${aws_security_group.elb.id}"
    ]
    instances       = [
        "${aws_instance.front_end_1a.id}",
        "${aws_instance.front_end_1a.id}"
    ]

    listener {
        instance_port     = 80
        instance_protocol = "http"
        lb_port           = 80
        lb_protocol       = "http"
    }
}

#Instance
resource "aws_instance" "front_end_1a" {
    ami = "ami-0fc20dd1da406780b"
    instance_type = "t2.micro"
    key_name = "${aws_key_pair.web_admin.key_name}"
    vpc_security_group_ids = ["${aws_security_group.default.id}"]
    subnet_id = "${aws_subnet.front_end_1a.id}"
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

resource "aws_instance" "front_end_1c" {
    ami = "ami-0af1df87db7b650f4"
    instance_type = "t2.micro"
    key_name = "${aws_key_pair.web_admin.key_name}"
    vpc_security_group_ids = ["${aws_security_group.default.id}"]
    subnet_id = "${aws_subnet.front_end_1c.id}"
    connection {
        type = "ssh"
        user = "ubuntu"
        pprivate_key = "${file("$PRIVATE_KEY_PATH")}" #EX)"${file("~/.ssh/id_rsa")}"
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

#Router Table
resource "aws_route_table" "application_private" {
    vpc_id = "${aws_vpc.main_vpc.id}"

    tags = { Name = "Router Table"}
}

#route table association
resource "aws_route_table_association" "front_end_1a" {
    subnet_id = "${aws_subnet.front_end_1a.id}"
    route_table_id = "${aws_route_table.application_private.id}"
}

resource "aws_route_table_association" "front_end_1c" {
    subnet_id = "${aws_subnet.front_end_1c.id}"
    route_table_id = "${aws_route_table.application_private.id}"
}

resource "aws_route_table_association" "back_end_1a" {
    subnet_id = "${aws_subnet.back_end_1a.id}"
    route_table_id = "${aws_route_table.application_private.id}"
}

resource "aws_route_table_association" "back_end_1c" {
    subnet_id = "${aws_subnet.back_end_1c.id}"
    route_table_id = "${aws_route_table.application_private.id}"
}



resource "aws_route" "internet_access" {
    route_table_id = "${aws_route_table.application_private.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
}
