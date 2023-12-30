import socket
import requests
import logging
import os 
import random
import string
import json
import boto3
#from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

dir_path = os.path.dirname(os.path.realpath(__file__))
log_file = os.path.join(dir_path, 'chat.log')
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s — %(message)s',
                    datefmt='%Y-%m-%d_%H:%M:%S',
                    handlers=[logging.FileHandler(log_file, encoding='utf-8')])
#sia = SentimentIntensityAnalyzer()

MAX_LOGIN_ATTEMPS = 10
LAMBDA_FUNCTION_NAME = 'twitch_refresh_credentials'

def login():
    credentials = get_credentials()
    sock = socket.socket()
    sock.connect((SERVER,PORT))
    login_attempt_counter = 0
    while True:
        sock.send(f"PASS {credentials['token']}\n".encode('utf-8'))
        sock.send(f"NICK {credentials['nickname'}\n".encode('utf-8'))
        sock.send(f"JOIN {credentials['channel'}\n".encode('utf-8'))initial_resp = sock.recv(2048).decode('utf-8')
        login_attempt_counter += 1
        if login_check(initial_resp):
            break
        elif login_attempt_counter >= MAX_LOGIN_ATTEMPTS:
            return False
        else:
            regenerate_creds()
   return True

def regenerate_creds():
    client = boto3.client('lambda')
    print('calling lambda')
    response = client.invoke(FunctionName=LAMBDA_FUNCTION_NAME)
    return response

def get_credentials():
    client = boto3.client('ssm')
    response = client.get_parameter(
        Name='twitch_credentials'
    )
    return json.loads(response['Parameter']['Value'])

def run_server:
    while True:
        resp = sock.recv(2048).decode('utf-8')

        if resp.startswith('PING'):
            sock.send("PONG\n".encode('utf-8'))
            print('sent pong')

        elif len(resp) > 0:
            logging.info((resp.replace('\n', ' ').replace('\r', ' ')))

def main():
    if login():
        run_server():
    else:
        raise Exception(f'login failed after {MAX_LOGIN_ATTEMPTS} attempts')
