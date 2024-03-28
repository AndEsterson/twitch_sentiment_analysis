import urllib3
import boto3
import json
from urllib.parse import urlencode


def get_initial_creds(client):
    response = client.get_parameter(Name="twitch_credentials")
    return json.loads(response["Parameter"]["Value"])


def get_new_creds(credentials):
    refresh_token_data = {
        "grant_type": "refresh_token",
        "refresh_token": credentials["refresh_token"],
        "client_id": credentials["client_id"],
        "client_secret": credentials["client_secret"],
    }
    encoded_data = urlencode(refresh_token_data)
    url = "https://id.twitch.tv/oauth2/token?" + encoded_data
    http = urllib3.PoolManager()
    r = http.request("POST", url)
    response = json.loads(r.data)
    credentials.update(
        {
            "access_token": response["access_token"],
            "refresh_token": response["refresh_token"],
        }
    )
    return credentials


def put_new_creds(client, credentials):
    response = client.put_parameter(
        Name="twitch_credentials",
        Description="twitch credentials",
        Value=json.dumps(credentials),
        Type="String",
        Overwrite=True,
        Tier="Standard",
    )
    return "tokens stored"


def lambda_handler(event, context):
    client = boto3.client("ssm")
    credentials = get_initial_creds(client)
    credentials = get_new_creds(credentials)
    response = put_new_creds(client, credentials)
    return response


if __name__ == "__main__":
    lambda_handler("", "")
