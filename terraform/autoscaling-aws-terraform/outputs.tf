output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "alb_dns_name" {
  value = aws_lb.main_alb.dns_name
}

