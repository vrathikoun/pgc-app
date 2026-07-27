from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.database import Base, engine, run_lightweight_migrations
from app.models import academy_video  # noqa: F401 — force table creation
from app.models import device_token  # noqa: F401 — force table creation
from app.routers import (
    auth,
    members,
    courses,
    bookings,
    subscriptions,
    academy,
    notifications,
    tasks,
)

# Crée toutes les tables au démarrage, puis applique les petites migrations.
Base.metadata.create_all(bind=engine)
run_lightweight_migrations()

# Dossier uploads
Path("uploads/avatars").mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title=settings.APP_NAME,
    description="API de gestion de club de sport de combat",
    version="1.1.0",
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


# Politique de confidentialité — URL publique exigée par le Play Store / App Store.
@app.get("/privacy", include_in_schema=False)
def privacy_policy():
    return FileResponse(Path(__file__).parent / "static" / "privacy.html")


# Page d'assistance — URL requise par la fiche App Store Connect.
@app.get("/support", include_in_schema=False)
def support_page():
    return FileResponse(Path(__file__).parent / "static" / "support.html")

app.include_router(auth.router)
app.include_router(members.router)
app.include_router(courses.router)
app.include_router(bookings.router)
app.include_router(subscriptions.router)
app.include_router(academy.router)
app.include_router(notifications.router)
app.include_router(tasks.router)


@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "app": settings.APP_NAME}