from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
import os
import shutil

import models, schemas, crud
from database import engine, SessionLocal
from email_utils import send_verification_email


# =====================================================
# CREATE FASTAPI APP
# =====================================================
app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# create tables
models.Base.metadata.create_all(bind=engine)


# =====================================================
# UPLOADS CONFIG
# =====================================================
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# =====================================================
# DATABASE SESSION
# =====================================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# =====================================================
# GET USER PROFILE
# =====================================================
@app.get("/user/{email}")
def get_user(email: str, db: Session = Depends(get_db)):

    user = db.query(models.User)\
        .filter(models.User.email == email)\
        .first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "profile_image": user.profile_image
    }


# =====================================================
# UPLOAD PROFILE IMAGE
# =====================================================
@app.post("/upload-profile-image")
async def upload_profile_image(
    email: str = Form(...),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):

    user = db.query(models.User)\
        .filter(models.User.email == email)\
        .first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    filename = f"{email}_{image.filename}"
    file_location = os.path.join(UPLOAD_DIR, filename)

    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    image_path = file_location.replace("\\", "/")

    user.profile_image = image_path
    db.commit()

    return {
        "message": "Profile image saved successfully",
        "image_url": image_path
    }


# =====================================================
# REGISTER
# =====================================================
@app.post("/register")
async def register(user: schemas.UserCreate, db: Session = Depends(get_db)):

    existing = crud.get_user_by_email(db, user.email)

    if existing and existing.is_verified:
        raise HTTPException(status_code=409, detail="EMAIL_ALREADY_EXISTS")

    new_user = crud.create_user(
        db,
        user.name,
        user.email,
        user.phone
    )

    print("\n==============================")
    print("OTP FOR:", new_user.email)
    print("OTP CODE:", new_user.verification_code)
    print("==============================\n")

    await send_verification_email(
        new_user.email,
        new_user.verification_code
    )

    return {"message": "Verification code generated"}


# =====================================================
# VERIFY EMAIL
# =====================================================
@app.post("/verify-email")
def verify_email(data: schemas.VerifyEmail, db: Session = Depends(get_db)):

    success = crud.verify_email_code(db, data.email, data.code)

    if not success:
        raise HTTPException(
            status_code=400,
            detail="Invalid or expired verification code"
        )

    return {"message": "Email verified successfully"}


# =====================================================
# SET PASSWORD
# =====================================================
@app.post("/set-password")
def set_password(data: schemas.SetPassword, db: Session = Depends(get_db)):

    success = crud.set_user_password(db, data.email, data.password)

    if not success:
        raise HTTPException(
            status_code=400,
            detail="User not found or email not verified"
        )

    return {"message": "Password created successfully"}


# =====================================================
# LOGIN
# =====================================================
@app.post("/login")
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):

    db_user = crud.authenticate_user(db, user.email, user.password)

    if not db_user:
        raise HTTPException(status_code=400, detail="Invalid email or password")

    if not db_user.is_verified:
        raise HTTPException(status_code=403, detail="Email not verified")

    return {
        "message": "Login successful",
        "name": db_user.name,
        "email": db_user.email,
        "phone": db_user.phone if db_user.phone else ""
    }


# =====================================================
# FORGOT PASSWORD FLOW
# =====================================================
@app.post("/forgot-password")
async def forgot_password(data: schemas.ForgotPassword,
                          db: Session = Depends(get_db)):

    user = crud.generate_reset_code(db, data.email)

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    await send_verification_email(user.email, user.verification_code)

    return {"message": "Reset code sent to email"}


@app.post("/verify-reset-code")
def verify_reset_code(data: schemas.VerifyResetCode,
                      db: Session = Depends(get_db)):

    success = crud.verify_reset_code(db, data.email, data.code)

    if not success:
        raise HTTPException(status_code=400,
                            detail="Invalid or expired code")

    return {"message": "Code verified"}


@app.post("/reset-password")
def reset_password(data: schemas.ResetPassword,
                   db: Session = Depends(get_db)):

    success = crud.reset_password(db, data.email, data.password)

    if not success:
        raise HTTPException(status_code=400, detail="Reset failed")

    return {"message": "Password reset successful"}


# =====================================================
# DELETE ACCOUNT
# =====================================================
@app.delete("/delete-account/{email}")
def delete_account(email: str, db: Session = Depends(get_db)):

    user = db.query(models.User)\
        .filter(models.User.email == email)\
        .first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db.query(models.Accident)\
        .filter(models.Accident.user_email == email)\
        .delete()

    db.delete(user)
    db.commit()

    return {"message": "Account deleted successfully"}


# =====================================================
# ACCIDENT REPORT (FIXED)
# =====================================================
@app.post("/report-accident")
async def report_accident(
    user_email: str = Form(...),
    latitude: str = Form(...),
    longitude: str = Form(...),
    severity: str = Form(...),
    description: str = Form(""),
    accident_datetime: str = Form(...),
    image: UploadFile = File(None),
    db: Session = Depends(get_db)
):

    print("🚨 REPORT API HIT")

    try:
        image_path = None

        if image:
            filename = f"{user_email}_{image.filename}"
            file_location = os.path.join(UPLOAD_DIR, filename)

            with open(file_location, "wb") as buffer:
                shutil.copyfileobj(image.file, buffer)

            image_path = file_location.replace("\\", "/")

        accident = models.Accident(
            user_email=user_email,
            latitude=latitude,
            longitude=longitude,
            severity=severity,
            description=description,
            image_path=image_path,
            accident_datetime=accident_datetime,
            status="pending"
        )

        db.add(accident)
        db.commit()
        db.refresh(accident)

        print("✅ REPORT SAVED:", accident.id)

        return {
            "message": "Accident report submitted successfully",
            "report_id": accident.id,
            "status": accident.status
        }

    except Exception as e:
        print("❌ REPORT FAILED:", str(e))
        raise HTTPException(status_code=500, detail=str(e))


# =====================================================
# USER REPORT STATUS
# =====================================================
@app.get("/user/reports/{email}")
def get_user_reports(email: str, db: Session = Depends(get_db)):

    reports = db.query(models.Accident)\
        .filter(models.Accident.user_email == email)\
        .order_by(models.Accident.id.desc())\
        .all()

    return reports


# =====================================================
# ADMIN APIs
# =====================================================
@app.get("/admin/pending-reports")
def get_pending_reports(request: Request,
                        db: Session = Depends(get_db)):

    reports = db.query(models.Accident)\
        .filter(models.Accident.status == "pending")\
        .all()

    base_url = str(request.base_url).rstrip("/")

    result = []

    for r in reports:
        image_url = None
        if r.image_path:
            image_url = f"{base_url}/{r.image_path}"

        result.append({
            "id": r.id,
            "user_email": r.user_email,
            "latitude": r.latitude,
            "longitude": r.longitude,
            "severity": r.severity,
            "description": r.description,
            "accident_datetime": r.accident_datetime,
            "status": r.status,
            "image_url": image_url
        })

    return result


@app.put("/admin/approve/{report_id}")
def approve_report(report_id: int, db: Session = Depends(get_db)):

    report = db.query(models.Accident)\
        .filter(models.Accident.id == report_id)\
        .first()

    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    report.status = "approved"
    db.commit()

    return {"message": "Report approved"}


@app.put("/admin/reject/{report_id}")
def reject_report(report_id: int, db: Session = Depends(get_db)):

    report = db.query(models.Accident)\
        .filter(models.Accident.id == report_id)\
        .first()

    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    report.status = "rejected"
    db.commit()

    return {"message": "Report rejected"}