# Alerting and visibility on top of Container Insights:
#   - SNS topic (optional e-mail subscription) for alarms
#   - alarms for available pods, container restarts, pod CPU/memory and node CPU
#   - one CloudWatch dashboard for the service, the load balancer and the cluster
#   - saved Logs Insights queries for errors and slow requests

data "aws_region" "current" {}

locals {
  ci   = "ContainerInsights"
  pod  = { ClusterName = var.cluster_name, Namespace = var.namespace, PodName = var.app_name }
  svc  = { ClusterName = var.cluster_name, Namespace = var.namespace, Service = var.service_name }
  node = { ClusterName = var.cluster_name }

  app_log_group = "/aws/containerinsights/${var.cluster_name}/application"
}

# Not encrypted with the AWS-managed SNS key on purpose: CloudWatch alarms cannot
# publish to a topic that uses it. A customer-managed KMS key would be the next step.
resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ---------------------------------------------------------------------------
# Alarms
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "running_pods_low" {
  alarm_name          = "${var.name}-${var.app_name}-running-pods-low"
  alarm_description   = "Fewer than ${var.min_running_pods} ${var.app_name} pods are running behind the service."
  namespace           = local.ci
  metric_name         = "service_number_of_running_pods"
  dimensions          = local.svc
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.min_running_pods
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "container_restarts" {
  alarm_name          = "${var.name}-${var.app_name}-container-restarts"
  alarm_description   = "${var.app_name} containers are restarting (crash loop or failing liveness probe)."
  namespace           = local.ci
  metric_name         = "pod_number_of_container_restarts"
  dimensions          = local.pod
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "pod_cpu_high" {
  alarm_name          = "${var.name}-${var.app_name}-cpu-high"
  alarm_description   = "${var.app_name} pod CPU is above 80% of its limit for 10 minutes. Check that the HPA is scaling out."
  namespace           = local.ci
  metric_name         = "pod_cpu_utilization_over_pod_limit"
  dimensions          = local.pod
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "pod_memory_high" {
  alarm_name          = "${var.name}-${var.app_name}-memory-high"
  alarm_description   = "${var.app_name} pod memory is above 80% of its limit. Risk of OOM kills."
  namespace           = local.ci
  metric_name         = "pod_memory_utilization_over_pod_limit"
  dimensions          = local.pod
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.name}-node-cpu-high"
  alarm_description   = "Average worker node CPU above 80%. Add nodes or right-size."
  namespace           = local.ci
  metric_name         = "node_cpu_utilization"
  dimensions          = local.node
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "failed_nodes" {
  alarm_name          = "${var.name}-failed-nodes"
  alarm_description   = "One or more worker nodes report a failed condition."
  namespace           = local.ci
  metric_name         = "cluster_failed_node_count"
  dimensions          = local.node
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name}-${var.app_name}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "## ${var.app_name} on ${var.cluster_name}\nTraffic comes through the ALB created by the AWS Load Balancer Controller. Pod and node metrics come from Container Insights. App logs: `${local.app_log_group}`."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          title  = "ALB requests and 5xx"
          region = data.aws_region.current.region
          stat   = "Sum"
          period = 60
          metrics = [
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"RequestCount\" ${var.alb_name}', 'Sum', 60)", id = "req", label = "Requests" }],
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"HTTPCode_Target_5XX_Count\" ${var.alb_name}', 'Sum', 60)", id = "err", label = "Target 5xx" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          title  = "ALB target response time (p95, seconds)"
          region = data.aws_region.current.region
          period = 60
          metrics = [
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer} MetricName=\"TargetResponseTime\" ${var.alb_name}', 'p95', 60)", id = "lat", label = "p95" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          title  = "Running pods and restarts"
          region = data.aws_region.current.region
          period = 60
          metrics = [
            [local.ci, "service_number_of_running_pods", "ClusterName", var.cluster_name, "Namespace", var.namespace, "Service", var.service_name, { stat = "Minimum", label = "Running pods" }],
            [local.ci, "pod_number_of_container_restarts", "ClusterName", var.cluster_name, "Namespace", var.namespace, "PodName", var.app_name, { stat = "Maximum", label = "Container restarts" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Pod CPU and memory (% of limit)"
          region = data.aws_region.current.region
          stat   = "Average"
          period = 60
          metrics = [
            [local.ci, "pod_cpu_utilization_over_pod_limit", "ClusterName", var.cluster_name, "Namespace", var.namespace, "PodName", var.app_name, { label = "CPU % of limit" }],
            [local.ci, "pod_memory_utilization_over_pod_limit", "ClusterName", var.cluster_name, "Namespace", var.namespace, "PodName", var.app_name, { label = "Memory % of limit" }],
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Nodes: CPU, memory and count"
          region = data.aws_region.current.region
          stat   = "Average"
          period = 60
          metrics = [
            [local.ci, "node_cpu_utilization", "ClusterName", var.cluster_name, { label = "Node CPU %" }],
            [local.ci, "node_memory_utilization", "ClusterName", var.cluster_name, { label = "Node memory %" }],
            [local.ci, "cluster_node_count", "ClusterName", var.cluster_name, { label = "Nodes", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 14
        width  = 24
        height = 6
        properties = {
          title  = "Recent application errors"
          region = data.aws_region.current.region
          query  = "SOURCE '${local.app_log_group}' | fields @timestamp, kubernetes.pod_name, log | filter kubernetes.namespace_name = '${var.namespace}' and log like /\"level\":\"error\"/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 20
        width  = 24
        height = 3
        properties = {
          title = "Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.running_pods_low.arn,
            aws_cloudwatch_metric_alarm.container_restarts.arn,
            aws_cloudwatch_metric_alarm.pod_cpu_high.arn,
            aws_cloudwatch_metric_alarm.pod_memory_high.arn,
            aws_cloudwatch_metric_alarm.node_cpu_high.arn,
            aws_cloudwatch_metric_alarm.failed_nodes.arn,
          ]
        }
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Saved Logs Insights queries (CloudWatch > Logs Insights > Saved queries)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_query_definition" "errors" {
  name            = "${var.name}/${var.app_name}/errors"
  log_group_names = [local.app_log_group]
  query_string    = <<-EOT
    fields @timestamp, kubernetes.pod_name, log
    | filter kubernetes.namespace_name = '${var.namespace}' and log like /"level":"error"/
    | sort @timestamp desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "requests" {
  name            = "${var.name}/${var.app_name}/requests-by-status"
  log_group_names = [local.app_log_group]
  query_string    = <<-EOT
    fields @timestamp, log
    | filter kubernetes.namespace_name = '${var.namespace}' and log like /"message":"request"/
    | parse log /"status":(?<status>\d+),"durationMs":(?<durationMs>[\d.]+)/
    | stats count(*) as requests, avg(durationMs) as avg_ms, pct(durationMs, 95) as p95_ms by status
  EOT
}
