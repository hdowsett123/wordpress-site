output "vpc" {
  value = module.vpc
}

output "sg" {
  value = {
    admin = aws_security_group.DEVOPS_ADMIN.id
    lb = aws_security_group.edge-frontends-alb.id
    asg = aws_security_group.edge-frontends-instances.id
    cache = aws_security_group.elasticache.id
    aurora = aws_security_group.aurora_db.id
 }
}
