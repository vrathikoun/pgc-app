from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.database import Base, engine
from app.routers import auth, members, courses, bookings, subscriptions

# Crée toutes les tables au démarrage
Base.metadata.create_all(bind=engine)

# Dossier uploads
Path("uploads/avatars").mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title=settings.APP_NAME,
    description="API de gestion de club de sport de combat",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8000",
        "http://localhost:5173",
        "http://localhost:58518",
        "https://app.polograpplingclub.com",
        "https://polograpplingclub.com",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Servir les avatars uploadés en statique → http://localhost:8000/uploads/avatars/xxx.jpg
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth.router)
app.include_router(members.router)
app.include_router(courses.router)
app.include_router(bookings.router)
app.include_router(subscriptions.router)


@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "app": settings.APP_NAME}