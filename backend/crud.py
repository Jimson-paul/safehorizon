from sqlalchemy.orm import Session
from models import User
from passlib.context import CryptContext
import random
from datetime import datetime, timedelta

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# =====================================================
# PASSWORD HELPERS
# =====================================================

def hash_password(password: str):
    return pwd_context.hash(password)


def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)


# =====================================================
# USER QUERIES
# =====================================================

def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()


# =====================================================
# CREATE USER / RESEND OTP
# =====================================================

def create_user(
    db: Session,
    name: str,
    email: str,
    phone: str | None = None
):

    user = get_user_by_email(db, email)

    verification_code = str(random.randint(100000, 999999))
    expiry_time = datetime.utcnow() + timedelta(minutes=5)

    # If user exists → regenerate OTP
    if user:
        user.name = name
        user.phone = phone
        user.verification_code = verification_code
        user.code_expiry = expiry_time
        user.is_verified = False

        db.commit()
        db.refresh(user)
        return user

    # Otherwise create new user
    user = User(
        name=name,
        phone=phone,
        email=email,
        password=None,
        is_verified=False,
        verification_code=verification_code,
        code_expiry=expiry_time
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


# =====================================================
# VERIFY EMAIL OTP
# =====================================================

def verify_email_code(db: Session, email: str, code: str):

    user = get_user_by_email(db, email)

    if not user:
        return False

    if user.verification_code != code:
        return False

    if not user.code_expiry or user.code_expiry < datetime.utcnow():
        return False

    user.is_verified = True
    user.verification_code = None
    user.code_expiry = None

    db.commit()

    return True


# =====================================================
# SET PASSWORD AFTER VERIFICATION
# =====================================================

def set_user_password(db: Session, email: str, password: str):

    user = get_user_by_email(db, email)

    if not user:
        return False

    if not user.is_verified:
        return False

    user.password = hash_password(password)
    db.commit()

    return True


# =====================================================
# LOGIN AUTHENTICATION
# =====================================================

def authenticate_user(db: Session, email: str, password: str):

    user = get_user_by_email(db, email)

    if not user:
        return None

    if not user.is_verified or not user.password:
        return None

    if not verify_password(password, user.password):
        return None

    return user


# =====================================================
# FORGOT PASSWORD - GENERATE RESET CODE
# =====================================================

def generate_reset_code(db: Session, email: str):

    user = get_user_by_email(db, email)

    if not user:
        return None

    verification_code = str(random.randint(100000, 999999))
    expiry_time = datetime.utcnow() + timedelta(minutes=5)

    user.verification_code = verification_code
    user.code_expiry = expiry_time

    db.commit()
    db.refresh(user)

    return user


# =====================================================
# VERIFY RESET CODE
# =====================================================

def verify_reset_code(db: Session, email: str, code: str):

    user = get_user_by_email(db, email)

    if not user:
        return False

    if user.verification_code != code:
        return False

    if not user.code_expiry or user.code_expiry < datetime.utcnow():
        return False

    return True


# =====================================================
# RESET PASSWORD
# =====================================================

def reset_password(db: Session, email: str, password: str):

    user = get_user_by_email(db, email)

    if not user:
        return False

    user.password = hash_password(password)
    user.verification_code = None
    user.code_expiry = None

    db.commit()

    return True