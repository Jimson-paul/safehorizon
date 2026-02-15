from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
import models, schemas, crud
from database import engine, SessionLocal

# create tables automatically
models.Base.metadata.create_all(bind=engine)

app = FastAPI()


# ---------------- DATABASE SESSION ----------------

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ---------------- REGISTER ----------------

@app.post("/register")
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):

    existing = crud.get_user_by_email(db, user.email)

    if existing:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    crud.create_user(db, user.email, user.password)

    return {"message": "User registered successfully"}


# ---------------- LOGIN ----------------

@app.post("/login")
def login(user: schemas.UserCreate, db: Session = Depends(get_db)):

    db_user = crud.authenticate_user(db, user.email, user.password)

    if not db_user:
        raise HTTPException(
            status_code=400,
            detail="Invalid email or password"
        )

    return {"message": "Login successful"}
