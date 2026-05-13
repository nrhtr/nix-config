import os
from twilio.rest import Client

# Find your Account SID and Auth Token at twilio.com/console
# and set the environment variables. See http://twil.io/secure
account_sid = os.environ['TWILIO_ACCOUNT_SID']
auth_token = os.environ['TWILIO_AUTH_TOKEN']

phone = os.environ['TWILIO_PHONE_NUMBER']

print("Authenticating...")
client = Client(account_sid, auth_token)

print("Calling...")
call = client.calls.create(
                        url='http://demo.twilio.com/docs/voice.xml',
                        to=phone,
                        from_=phone
                    )

print(call.sid)
