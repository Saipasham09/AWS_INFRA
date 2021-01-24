
##################### ECS service ALB ####################

resource "aws_alb" "main" {
  name            = "demo-load-balancer"
  subnets         = aws_subnet.alb.*.id
  security_groups = [aws_security_group.alb.id]
}

resource "aws_alb_target_group" "app" {
  name        = "alb-target-group"
  port        = var.alb_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main.id
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}

################## Hello_App Endpoint ######################

output "Helloworld-ALB-URL" {
  value = aws_alb.main.dns_name
}

