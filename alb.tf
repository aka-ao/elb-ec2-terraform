resource "aws_alb" "ec2_alb" {
  name            = "ec2alb"
  subnets         = aws_subnet.subnets.*.id
  security_groups = [aws_security_group.elb_ec2.id]

}

resource "aws_lb_target_group" "lb_target_group" {
  name     = "ec2alb"
  protocol = "HTTP"
  port     = "80"
  vpc_id   = aws_vpc.elb_ec2_vpc.id
  health_check {
    protocol = "HTTP"
    path     = "/"
  }
}

output "lb_result" {
  value = aws_alb.ec2_alb.dns_name
}

resource "aws_lb_target_group_attachment" "alb_ec2" {
  count            = 2
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id        = aws_instance.ec2[count.index].id
  port             = 80
}

resource "aws_lb_listener" "alb_ec2" {
  load_balancer_arn = aws_alb.ec2_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}
