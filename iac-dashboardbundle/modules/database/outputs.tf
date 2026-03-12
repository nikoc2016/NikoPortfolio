output "zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "db_ip" {
  value = aws_instance.database_instance.private_ip
}