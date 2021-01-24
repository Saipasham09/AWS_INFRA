
############### Docker Image Repository #####################
resource "aws_ecr_repository" "hello_app" {
  name = "hello_app"
}

############### ECS Cluster In FARGATE #####################

resource "aws_ecs_cluster" "helloworld" {
  name = "helloworld"
}

#################ECS Service Role#############################
resource "aws_iam_role" "iam_ecs_service_role" {
  name                 = "iam_ecs_service_role"
  path                 = "/"
  permissions_boundary = ""
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name = "ecs_service_role_policy"
  role = aws_iam_role.iam_ecs_service_role.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:Describe*",
            "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
            "elasticloadbalancing:DeregisterTargets",
            "elasticloadbalancing:Describe*",
            "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
            "elasticloadbalancing:RegisterTargets"
        ],
        "Resource": "*"
    }
  ]
}
POLICY

}

resource "aws_iam_role" "iam_ecs_task_role" {
  name                 = "iam_ecs_task_role"
  path                 = "/"
  permissions_boundary = ""
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "ecs_task_role_policy"
  role = aws_iam_role.iam_ecs_task_role.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
POLICY

}

# service definition
resource "aws_ecs_service" "hello-app" {
  name            = "hello-app"
  cluster         = aws_ecs_cluster.helloworld.id
  task_definition = aws_ecs_task_definition.hello-app.arn
  launch_type     = "FARGATE"
  desired_count   = var.app_desired_count

  network_configuration {
    subnets          = aws_subnet.fargate.*.id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.arn
    container_name   = "hello-app"
    container_port   = var.web_port
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [
    aws_alb_listener.front_end,
    aws_iam_role_policy.ecs_service_role_policy,
  ]
}

resource "aws_ecs_task_definition" "hello-app" {
  family = "hello-app"

  # Note using nginx:alpine as bootstrap image, real service image will come from CodePipeline build and deploy :)
  execution_role_arn       = aws_iam_role.iam_ecs_task_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  container_definitions    = <<DEFINITION
[
  {
    "cpu": 256,
    "image": "nginx:alpine",
    "memory": 512,
    "name": "hello-app",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.web_port},
        "hostPort": ${var.web_port}
      }
    ]
  }
]
DEFINITION

}

