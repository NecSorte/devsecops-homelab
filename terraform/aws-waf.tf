resource "aws_wafv2_web_acl" "main" {
  name  = "devsecops-interview-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }
  ## Replaced custom rules for SQLi with AWS Managed Rules
  # # Custom rule for SQL injection
  # rule {
  #   name     = "CustomSQLInjectionRule"
  #   priority = 3

  #   action {
  #     block {}
  #   }

  #   statement {
  #     byte_match_statement {
  #       search_string         = "' or '1'='1"
  #       field_to_match {
  #         query_string {}
  #       }
  #       text_transformation {
  #         priority = 0
  #         type     = "LOWERCASE"
  #       }
  #       positional_constraint = "CONTAINS"
  #     }
  #   }

  #   visibility_config {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "CustomSQLInjectionMetric"
  #     sampled_requests_enabled   = true
  #   }
  # }

  # Replaces custom rules for SQLi
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Custom rule for XSS
  rule {
    name     = "CustomXSSRule"
    priority = 4

    action {
      block {}
    }

    statement {
      byte_match_statement {
        search_string         = "<script>"
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
        positional_constraint = "CONTAINS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CustomXSSMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "DevSecOpsInterviewWAFMetric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "DevSecOps Interview"
    Environment = "interview"
  }
}

# Create Application Load Balancer
resource "aws_lb" "main" {
  name               = "devsecops-interview-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "DevSecOps Interview"
  }
}

# Security group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "devsecops-interview-alb-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DevSecOps Interview ALB Security Group"
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-devsecops-interview" # Fixed: Must start with aws-waf-logs-
  retention_in_days = 7

  tags = {
    Name = "DevSecOps Interview WAF Logs"
  }
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}

# Added listener for ALB to test WAF functionality
resource "aws_lb_listener" "waf_test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Request allowed by WAF"
      status_code  = "200"
    }
  }
}