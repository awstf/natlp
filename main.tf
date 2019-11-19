resource "aws_security_group" "nat" {
  name_prefix = var.name
  vpc_id      = var.vpc_id
  description = "Security group for NAT instance ${var.name}"

  tags = {
    Name = "nat-instance-${var.name}"
  }
}

resource "aws_security_group_rule" "egress-80" {
  security_group_id = aws_security_group.nat.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

resource "aws_security_group_rule" "egress-443" {
  security_group_id = aws_security_group.nat.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}

resource "aws_security_group_rule" "ingress-22" {
  security_group_id = aws_security_group.nat.id
  type              = "ingress"
  cidr_blocks       = var.sshsg
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
}

resource "aws_security_group_rule" "ingress-80" {
  security_group_id = aws_security_group.nat.id
  type              = "ingress"
  cidr_blocks       = var.private_subnets_cidr_blocks
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

resource "aws_security_group_rule" "ingress-443" {
  security_group_id = aws_security_group.nat.id
  type              = "ingress"
  cidr_blocks       = var.private_subnets_cidr_blocks
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}

resource "aws_iam_instance_profile" "profile" {
  name_prefix = "nat-${var.name}"
  role        = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name_prefix        = "c-nat-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.sts.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.role.name
}

resource "aws_iam_role_policy" "eni" {
  name_prefix = "eni-${var.name}"
  role        = aws_iam_role.role.name
  policy      = data.aws_iam_policy_document.nat.json
}

resource "aws_network_interface" "if" {
  count             = length(var.azs)
  security_groups   = [aws_security_group.nat.id]
  subnet_id         = var.public_subnets[count.index]
  source_dest_check = false
  description       = "ENI for NAT instance ${var.name}-${var.azs[count.index]}"

  tags = {
    Name = "nat-instance-${var.name}-${var.azs[count.index]}"
  }
}

resource "aws_eip" "ip" {
  count             = length(var.azs)
  network_interface = aws_network_interface.if[count.index].id

  tags = {
    Name = "nat-instance-${var.name}-${var.azs[count.index]}"
  }
}

resource "aws_route" "route" {
  count                  = length(var.azs)
  route_table_id         = var.private_route_tables[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.if[count.index].id
}

resource "spotinst_elastigroup_aws" "asg" {
  count            = length(var.azs)
  name             = "nat-${var.name}-${var.azs[count.index]}"
  product          = "Linux/UNIX"
  max_size         = 1
  min_size         = 0
  desired_capacity = 1

  region     = data.aws_region.current.name
  subnet_ids = [var.public_subnets[count.index]]

  image_id             = data.aws_ami.ami.id
  iam_instance_profile = aws_iam_instance_profile.profile.arn
  security_groups      = [aws_security_group.nat.id]
  enable_monitoring    = false
  ebs_optimized        = false

  user_data = templatefile("${path.module}/data/init.sh", {
    eni_id = aws_network_interface.if[count.index].id
  })

  instance_types_ondemand       = var.instance_types_ondemand
  instance_types_spot           = var.instance_types_spot
  instance_types_preferred_spot = var.instance_types_preferred_spot

  orientation          = "balanced"
  fallback_to_ondemand = false
  cpu_credits          = "unlimited"
  spot_percentage      = 100

  scaling_strategy {
    terminate_at_end_of_billing_hour = false
    termination_policy               = "default"
  }

  tags {
    key   = "Environment"
    value = terraform.workspace
  }

  tags {
    key   = "Name"
    value = "nat-${var.name}-${var.azs[count.index]}"
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}
