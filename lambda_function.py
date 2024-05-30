import boto3
import datetime

ecs = boto3.client('ecs')

def stop_ecs_tasks(cluster_name):
    tasks = ecs.list_tasks(cluster=cluster_name)
    for task_arn in tasks['taskArns']:
        ecs.stop_task(cluster=cluster_name, task=task_arn, reason='Scheduled stop')

def start_ecs_tasks(cluster_name, task_definitions):
    for task_definition in task_definitions:
        ecs.run_task(cluster=cluster_name, taskDefinition=task_definition, count=1)

def lambda_handler(event, context):
    cluster_name = 'smx-cluster-svc-dev'
    task_definitions = ['your-task-definitions']  # Add your task definitions here

    if event['action'] == 'stop':
        stop_ecs_tasks(cluster_name)
    elif event['action'] == 'start':
        start_ecs_tasks(cluster_name, task_definitions)
