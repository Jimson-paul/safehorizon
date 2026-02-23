from fastapi_mail import ConnectionConfig

conf = ConnectionConfig(
    MAIL_USERNAME="safehorizon99@gmail.com",
    MAIL_PASSWORD="dtpyyahtppgkldtv",   # app password (NO spaces)
    MAIL_FROM="safehorizon99@gmail.com",

    MAIL_SERVER="smtp.gmail.com",
    MAIL_PORT=587,

    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,

    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)