import socket
import requests
import logging
import os 
import random
import string
import json
import boto3

dir_path = os.path.dirname(os.path.realpath(__file__))
log_file = os.path.join(dir_path, 'chat.log')
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s — %(message)s',
                    datefmt='%Y-%m-%d_%H:%M:%S')
chat_logger = logging.getLogger('chat_logger')
chat_handler = logging.FileHandler(log_file, encoding='utf-8')
chat_handler.setFormatter(logging.Formatter(fmt='%(asctime)s — %(message)s', datefmt='%Y-%m-%d_%H:%M:%S'))
chat_logger.addHandler(chat_handler)

MAX_LOGIN_ATTEMPTS = 10
LAMBDA_FUNCTION_NAME = 'twitch_refresh_credentials'

def login():
    credentials = get_credentials()
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
            regenerate_creds()

def login_check(initial_resp):
    if 'GLHF' in initial_resp:
        return True
    else:
        logging.info(initial_resp)
        return False

def regenerate_creds():
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

def run_server(sock):
    while True:
        resp = sock.recv(2048).decode('utf-8')

        if resp.startswith('PING'):
            sock.send("PONG\n".encode('utf-8'))
            logging.info('sent pong')

        elif len(resp) > 0:
            chat_logger.info((resp.replace('\n', ' ').replace('\r', ' ')))
    return True

def main():
    sock = login()
    if sock:
        logging.info('running_server')
        run_server(sock)
    else:
        raise Exception(f'login failed after {MAX_LOGIN_ATTEMPTS} attempts')

if __name__ == '__main__':
    main()
