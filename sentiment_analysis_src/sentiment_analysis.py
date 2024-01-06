import boto3
import re
import json
import urllib.parse
from datetime import datetime
from packages.vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

sia = SentimentIntensityAnalyzer()
s3_client = boto3.client("s3")

def parse_log_line(line):
    pattern = re.compile(r"^(\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}) — :(\w+)![^ ]+ PRIVMSG #(\w+) :(.+)$")
    match = pattern.match(line)
    if match:
        timestamp, user, channel, message = match.groups()
        return {"time": timestamp, "channel": channel, "user": user, "message": message, "rating": sia.polarity_scores(message), "word_count": len(message.split(" "))}
    return

def read_log_file(file_path):
    with open(file_path, "r", encoding="utf-8") as file:
        log_entries = [parse_log_line(line) for line in file.readlines() if parse_log_line(line)]
    return log_entries

def get_from_s3(bucket, key, filename):
    try:
        response = s3_client.download_file(bucket, key, filename)
        return response
    except Exception as e:
        print(e)
        print("Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.".format(key, bucket))
        raise e

def read_and_write(bucket, key, filename):
    get_from_s3(bucket, key, filename)
    log_entries = read_log_file(filename)
    return write_to_s3(log_entries, bucket, key)

def write_to_s3(log_entries, bucket, original_key):
    body = bytes(json.dumps(log_entries).encode("UTF-8"))
    key = "processed_logs/proc_" + original_key.split("/")[-1]
    s3_client.put_object(Bucket=bucket, Key=key, Body=body)
    return "processed logs uploaded"

def lambda_handler(event, context):
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(event["Records"][0]["s3"]["object"]["key"], encoding="utf-8")
    filename = "/tmp/chat.log"
    return read_and_write(bucket, key, filename)    

if __name__ == "__main__":
    bucket = "twitch-scraper-logs"
    key = "raw_logs/1704033684_chat.log"
    filename = "chat.log"
    print(read_and_write(bucket, key, filename))
