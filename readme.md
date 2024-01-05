Deploys three lambda functions which can be used to listen to a twitch chat irc (for a channel passed in the lambda event), chat logs are posted to an s3, which triggers another lambda functioning, uploading results with channel, time, text and sentiment scores for each message. 

# Obtaining twitch credentials
Reading twitch chats requires credentials, this requires a twitch.tv dev app and regular account, see [twitch dev documentation](https://dev.twitch.tv/docs/) authorization needs to be done by the [authorization code grant flow](https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#client-credentials-grant-flow) once the creds have been generated manually for the first time, write an aws parameter store parameter of the form `{"server": "irc.chat.twitch.tv", "port": 6667, "nickname": "<aws_username>", "client_id": "<client_id>", "client_secret": "<client_secret>", "refresh_token": "<refresh_token>", "access_token": "<access_token>"}` the credentials only need to be manually written once, and will automatically update afterwards (when the access token needs refreshing during lambda runtime).

# Usage
The sentiment_analysis.py function requires the VADER sentiment analysis package, and its dependencies these must be installed by `pip3 install --target="./sentiment_analysis_src/packages/" vaderSentiment` you might also need to `pip3 install --target="./sentiment_analysis_src/packages/ urllib3==1.25.11"`

You can now run `terraform apply` to create the infrastructure. the twitch_log_scraper lambda function is the only one that needs to be called externally, this can be done for example by another server, or cloudwatch events, or aws cli (e.g `aws lambda invoke --function-name twitch_log_scraper --payload '{ "channel": "#northernlion" }' out.txt`), depending on use case. This will read 15 minutes of live chat messages, then trigger the upload of both the raw logs and results.

# Notes
Lambda is in certain ways not the natural way to handle the problem of reading and analysing chat logs, but it's useful for running large and varying amounts of analyses in parallel, which is what this was designed for.

Unless you use a secure string to encrypt the parameter store value (which you should do if your app is used for anything else, or you gave any perms other than reading chat), everything here is in the free tier, including a very generous amount of lambda compute, you should be able to get 1000s of hours of logging analysed for free.
