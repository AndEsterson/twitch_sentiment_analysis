import sys
import time
import json
import socket
import logging
import logging.handlers
import boto3


MAX_LOGIN_ATTEMPTS = 3
LAMBDA_TIME_CUTOFF = 20000
S3_BUCKET = "twitch-scraper-logs"
LAMBDA_FUNCTION_NAME = "twitch_refresh_credentials"
S3_BUCKET_NAME = "twitch_scraper"

def init_loggers(log_dir):
    global log_file
    log_file = log_dir + "chat.log"
    logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s — %(message)s",
                    datefmt="%Y-%m-%d_%H:%M:%S")
    logging.getLogger().setLevel(logging.INFO)
    chat_logger = logging.getLogger("chat_logger")
    logging.getLogger("chat_logger").setLevel(logging.INFO)
    chat_handler = logging.handlers.WatchedFileHandler(log_file, encoding="utf-8")
    chat_handler.setFormatter(logging.Formatter(fmt="%(asctime)s — %(message)s", datefmt="%Y-%m-%d_%H:%M:%S"))
    chat_logger.addHandler(chat_handler)
    return chat_logger

def login(event):
    logging.info("attempting to get twitch credentials")
    credentials = get_credentials()
    credentials.update(event)
    login_attempt_counter = 0
    while True:
        sock = socket.socket()
        sock.connect((credentials["server"],credentials["port"]))
        sock.send(f"PASS oauth:{credentials['access_token']}\n".encode("utf-8"))
        sock.send(f"NICK {credentials['nickname']}\n".encode("utf-8"))
        sock.send(f"JOIN {credentials['channel']}\n".encode("utf-8"))
        initial_resp = sock.recv(2048).decode("utf-8")
        login_attempt_counter += 1
        if login_check(initial_resp):
            return sock
        elif login_attempt_counter >= MAX_LOGIN_ATTEMPTS:
            return False
        else:
            logging.info("attempting to regenerate creds")
            regenerate_credentials()
            credentials = get_credentials()

def login_check(initial_resp):
    if "GLHF" in initial_resp:
        return True
    else:
        logging.info(initial_resp)
        return False

def regenerate_credentials():
    client = boto3.client("lambda")
    logging.info("calling lambda")
    response = client.invoke(FunctionName=LAMBDA_FUNCTION_NAME)
    return response

def get_credentials():
    client = boto3.client("ssm")
    response = client.get_parameter(
        Name="twitch_credentials"
    )
    return json.loads(response["Parameter"]["Value"])

def upload_logs(local_file_path, s3_bucket):
    s3_key = "raw_logs/" + str(int(time.time())) + "_" + "chat.log"
    s3 = boto3.client("s3")
    s3.upload_file(local_file_path, s3_bucket, s3_key)
    logging.info(f"uploaded logs to {s3_key}")
    return True

def run_server(sock, context):
    while True:
        if context.get_remaining_time_in_millis() < LAMBDA_TIME_CUTOFF:
            return upload_logs(log_file, S3_BUCKET)
        resp = sock.recv(2048).decode("utf-8")
        if resp.startswith("PING"):
            sock.send("PONG\n".encode("utf-8"))
            logging.info("sent pong")
        elif len(resp) > 0:
            chat_logger.info((resp.replace("\n", " ").replace("\r", " ")))
    return False

def lambda_handler(event, context):
    chat_logger = init_loggers("/tmp/")
    return main(event, context)

def main(event, context):
    sock = login(event)
    if sock:
        logging.info("running_server")
        if run_server(sock, context):
            sock.close()
            return f"Upload complete with event {event}, exiting"
        else:
            return f"Did not upload with event {event}, exiting"
    else:
        raise Exception(f"login failed after {MAX_LOGIN_ATTEMPTS} attempts")

class mock_context():
    """class used to mock lambda context run time locally"""
    def __init__(self, run_time):
        self.start_time = int(time.time()*10**3)
        self.finish_time = int(time.time()*10**3) + run_time

    def get_remaining_time_in_millis(self):
        return self.finish_time - int(time.time()*10**3)

if __name__ == "__main__":
    """local testing, run_time is in ms, channel must start with #"""
    try:
        run_time = int(sys.argv[1])
    except:
        raise Exception("run_time argument required")
    try:
        log_file_dir = sys.argv[2]
        chat_logger = init_loggers(log_file_dir)
    except:
        raise Exception("must specify logging directory")
    try:
        channel = sys.argv[3]
        event = {"channel": channel}
    except:
        event = {}
        print("running without channel specified")

    context = mock_context(run_time)
    print(main(event, context))
