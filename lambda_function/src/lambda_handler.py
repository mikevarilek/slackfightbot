import boto3
from botocore.exceptions import ClientError
import logging
import json
import time
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

logger = logging.getLogger()
logger.setLevel("INFO")

# AWS Secrets Manager Constants
SECRET_STRING = 'SecretString'
TOKEN = 'Token'
SECRET_NAME = 'SlackFightBotOAuthKey'
SECRETS_MANAGER = 'secretsmanager'

# Slack API Constants
CHANNELS = 'channels'
IS_MEMBER = 'is_member'
ID = 'id'
MESSAGES = 'messages'
TIMESTAMP = 'ts'
BOT_PROFILE = 'bot_profile'
NAME = 'name'
USER = 'user'

# App Constants
BOT_NAME = 'SlackFightBot'

def lambda_handler(event, context):
    secret_name = SECRET_NAME
    session = boto3.session.Session()
    secrets_manager = session.client(
        service_name = SECRETS_MANAGER
    )

    try:
        get_secret_value_response = secrets_manager.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        logging.error(e)
        raise e

    slack_oauth_key = json.loads(get_secret_value_response[SECRET_STRING])[TOKEN]
    slack_client = WebClient(token=slack_oauth_key)
    conversation_ids = []

    try:
        for result in slack_client.conversations_list():
            for channel in result[CHANNELS]:
                if channel[IS_MEMBER]:
                    conversation_ids.append(channel[ID])
                    break
    except SlackApiError as e:
        logging.error(e)
        raise e

    for conversation_id in conversation_ids:
        if (check_for_fight(conversation_id, slack_client)):
            try:
                slack_client.chat_postMessage(
                    channel = conversation_id,
                    text = "FIGHT!"
                )
            except SlackApiError as e:
                logger.error(e)
                raise e
    pass


def check_for_fight(conversation_id, slack_client):
    try:
        result = slack_client.conversations_history(
            channel=conversation_id,
            limit=20
        )
    except SlackApiError as e:
        logging.error(e)
        raise e
    pass

    recentUsers = set()
    recentMessages = 0
    for message in result[MESSAGES]:
        timestamp = float(message[TIMESTAMP])
        if (time.time() - timestamp) < 60 * 10:
            if BOT_PROFILE in message and message[BOT_PROFILE][NAME] == BOT_NAME:
                logging.info('Bot has already posted within the past 10 minutes')
                return False
            recentUsers.add(message[USER])
            recentMessages += 1
    
    logging.info(f"{len(recentUsers)} recent users found with {recentMessages} recent messages.")
    return len(recentUsers) >= 3 and recentMessages >= 10