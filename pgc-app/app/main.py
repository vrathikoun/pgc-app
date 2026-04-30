from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.database import Base, engine
from app.routers import auth, members, courses, bookings

# Crée les tables si elles n'existent pas
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.APP_NAME,
    description="API de gestion de club de sport de combat",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS — autorise l'app mobile Flutter à appeler l'API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # restreindre en production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router)
app.include_router(members.router)
app.include_router(courses.router)
app.include_router(bookings.router)


@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "app": settings.APP_NAME}
