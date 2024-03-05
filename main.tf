# primary requrements for project:
#1. create VPC 
#2. create internet gateway and attach to vpc
#3. create all subnets
#4. create elastic ip
#5. create nat gateway
#6. create route table
#7. create routes
#8. association with subnets

resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames 
  tags = merge(
    var.common_tags, 
    var.vpc_tags,
    {
        Name = local.Name
    }
   )
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.igw_tags,
    {
        Name = local.Name
    }
  )
}

resource "aws_subnet" "public" {
  count = length(var.public_subnets_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnets_cidr[count.index]
  availability_zone = local.az_names[count.index]
  tags = merge (
    var.common_tags,
    var.public_subnets_tags,
    {
        Name = "${local.Name}-public-${local.az_names[count.index]}"
    }
  )
}
resource "aws_subnet" "private" {
  count = length(var.private_subnets_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnets_cidr[count.index]
  availability_zone = local.az_names[count.index]
  tags = merge (
    var.common_tags,
    var.private_subnets_tags,
    {
        Name = "${local.Name}-private-${local.az_names[count.index]}"
    }
  )
}
resource "aws_subnet" "database" {
  count = length(var.database_subnets_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnets_cidr[count.index]
  availability_zone = local.az_names[count.index]
  tags = merge (
    var.common_tags,
    var.database_subnets_tags,
    {
        Name = "${local.Name}-database-${local.az_names[count.index]}"
    }
  )
}
resource "aws_eip" "eip" {
  domain   = "vpc"
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge (
    var.common_tags,
    var.aws_nat_gateway_tags,
    {
        Name = "${local.Name}"
    }
  )
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.public_route_table_tags,
    {
        Name = "${local.Name}-public"
    }
  )
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.private_route_table_tags,
    {
        Name = "${local.Name}-private"
    }
  )
}
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.database_route_table_tags,
    {
        Name = "${local.Name}-database"
    }
  )
}

#A DB subnet group is a logical resource in itself that tells AWS where it may schedule a database instance in a VPC. It is not referring to the subnets directly which is what you're trying to do there. to verify this goto AWS->RDS->subnet groups
resource "aws_db_subnet_group" "default" {
  name       = "${local.Name}"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${local.Name}"
  }
}

resource "aws_route" "public_route" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id #here public so...add internet gateway
}

resource "aws_route" "private_route" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id # here private routes so... add nat gateway
}

resource "aws_route" "database_route" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id # here private routes so... add nat gateway
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets_cidr) # here we will get list of two public subnets ...so we have to loop it
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets_cidr) # here we will get list of two private subnets ...so we have to loop it
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "database" {
  count = length(var.database_subnets_cidr) # here we will get list of two database subnets ...so we have to loop it
  subnet_id      = element(aws_subnet.database[*].id, count.index)
  route_table_id = aws_route_table.database.id
}
