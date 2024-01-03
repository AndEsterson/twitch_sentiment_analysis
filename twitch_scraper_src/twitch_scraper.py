import socket
import logging
import logging.handlers
import time
import json
import boto3

LOG_FILE = '/tmp/chat.log'
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s — %(message)s',
                    datefmt='%Y-%m-%d_%H:%M:%S')
logging.getLogger().setLevel(logging.INFO)
chat_logger = logging.getLogger('chat_logger')
logging.getLogger('chat_logger').setLevel(logging.INFO)
chat_handler = logging.handlers.WatchedFileHandler(LOG_FILE, encoding='utf-8')
chat_handler.setFormatter(logging.Formatter(fmt='%(asctime)s — %(message)s', datefmt='%Y-%m-%d_%H:%M:%S'))
chat_logger.addHandler(chat_handler)

MAX_LOGIN_ATTEMPTS = 3
LAMBDA_TIME_CUTOFF = 20000
S3_BUCKET = "twitch-scraper-logs"
LAMBDA_FUNCTION_NAME = 'twitch_refresh_credentials'
S3_BUCKET_NAME = 'twitch_scraper'

def login(event):
    logging.info('attempting to get twitch credentials')
    credentials = get_credentials()
    credentials.update(event)
    login_attempt_counter = 0
    while True:
        sock = socket.socket()
        sock.connect((credentials['server'],credentials['port']))
        sock.send(f"PASS oauth:{credentials['access_token']}\n".encode('utf-8'))
        sock.send(f"NICK {credentials['nickname']}\n".encode('utf-8'))
        sock.send(f"JOIN {credentials['channel']}\n".encode('utf-8'))
        initial_resp = sock.recv(2048).decode('utf-8')
        login_attempt_counter += 1
        if login_check(initial_resp):
            return sock
        elif login_attempt_counter >= MAX_LOGIN_ATTEMPTS:
            return False
        else:
            logging.info('attempting to regenerate creds')
            regenerate_credentials()
            credentials = get_credentials()

def login_check(initial_resp):
    if 'GLHF' in initial_resp:
        return True
    else:
        logging.info(initial_resp)
        return False

def regenerate_credentials():
    client = boto3.client('lambda')
    logging.info('calling lambda')
    response = client.invoke(FunctionName=LAMBDA_FUNCTION_NAME)
    return response

def get_credentials():
    client = boto3.client('ssm')
    response = client.get_parameter(
        Name='twitch_credentials'
    )
    return json.loads(response['Parameter']['Value'])

def upload_logs(local_file_path, s3_bucket):
    s3_key = "raw_logs/" + str(int(time.time())) + "_" + 'chat.log'
    s3 = boto3.client("s3")
    s3.upload_file(local_file_path, s3_bucket, s3_key)
    logging.info(f"uploaded logs to {s3_key}")
    return True

def run_server(sock, context):
    while True:
        if context.get_remaining_time_in_millis() < LAMBDA_TIME_CUTOFF:
            return upload_logs(LOG_FILE, S3_BUCKET)
        resp = sock.recv(2048).decode('utf-8')
        if resp.startswith('PING'):
            sock.send("PONG\n".encode('utf-8'))
            logging.info('sent pong')
        elif len(resp) > 0:
            chat_logger.info((resp.replace('\n', ' ').replace('\r', ' ')))
    return False

def lambda_handler(event, context):
    sock = login(event)
    if sock:
        logging.info('running_server')
        if run_server(sock, context):
            return f'Upload complete with event {event}, exiting'
        else:
            return f'Did not upload with event {event}, exiting'
    else:
        raise Exception(f'login failed after {MAX_LOGIN_ATTEMPTS} attempts')

