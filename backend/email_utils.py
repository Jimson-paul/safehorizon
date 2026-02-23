from fastapi_mail import FastMail, MessageSchema
from email_config import conf


async def send_verification_email(email: str, code: str):

    message = MessageSchema(
        subject="Safe Horizon Email Verification",
        recipients=[email],
        body=f"""
Your Safe Horizon verification code is:

{code}

This code expires in 5 minutes.
""",
        subtype="plain"
    )

    try:
        fm = FastMail(conf)
        await fm.send_message(message)
        print("✅ EMAIL SENT SUCCESSFULLY")

    except Exception as e:
        print("❌ EMAIL FAILED")
        print(e)