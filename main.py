from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uuid
import hashlib
import json
from datetime import date, timedelta
import os

from supabase import create_client, Client


# ============================================================
# SUPABASE CONNECTION
# ============================================================

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_KEY environment variables are required."
    )

supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_KEY
)


# ============================================================
# FASTAPI
# ============================================================

app = FastAPI(title="TrekCure Blockchain API")


# ============================================================
# DIGITAL ID - CREATE
# ============================================================

class Tourist(BaseModel):
    user_id: str
    name: str
    age: int


@app.post("/create-digital-id")
def create_digital_id(tourist: Tourist):

    # --------------------------------------------------------
    # 1. Generate unique Tourist ID
    # --------------------------------------------------------

    tourist_id = "TC-" + str(uuid.uuid4())[:8]


    # --------------------------------------------------------
    # 2. Create Digital ID credential
    # --------------------------------------------------------

    credential = {
        "tourist_id": tourist_id,
        "name": tourist.name,
        "age": tourist.age,
        "credential_type": "TrekCure Tourist ID",
        "issued_by": "TrekCure",
        "issued_date": str(date.today()),
        "valid_until": str(date.today() + timedelta(days=30))
    }


    # --------------------------------------------------------
    # 3. Generate SHA-256 hash
    # --------------------------------------------------------

    credential_data = json.dumps(
        credential,
        sort_keys=True
    )

    credential_hash = hashlib.sha256(
        credential_data.encode()
    ).hexdigest()


    # --------------------------------------------------------
    # 4. Store hash in Supabase
    # --------------------------------------------------------

    try:

        result = (
            supabase
            .table("profiles")
            .update({
                "digital_id_hash": credential_hash
            })
            .eq("id", tourist.user_id)
            .execute()
        )

    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Could not save Digital ID to Supabase: {str(e)}"
        )


    # --------------------------------------------------------
    # 5. Check whether the profile was actually found
    # --------------------------------------------------------

    if not result.data:

        raise HTTPException(
            status_code=404,
            detail="User profile not found in Supabase."
        )


    # --------------------------------------------------------
    # 6. Return Digital ID to Flutter
    # --------------------------------------------------------

    return {
        "tourist_id": tourist_id,
        "credential": credential,
        "hash": credential_hash
    }


# ============================================================
# DIGITAL ID - VERIFY
# ============================================================

class VerificationRequest(BaseModel):
    user_id: str
    credential: dict


@app.post("/verify-digital-id")
def verify_digital_id(data: VerificationRequest):

    # --------------------------------------------------------
    # 1. Generate hash from the credential being verified
    # --------------------------------------------------------

    credential_data = json.dumps(
        data.credential,
        sort_keys=True
    )

    current_hash = hashlib.sha256(
        credential_data.encode()
    ).hexdigest()


    # --------------------------------------------------------
    # 2. Get stored hash from Supabase
    # --------------------------------------------------------

    try:

        result = (
            supabase
            .table("profiles")
            .select("digital_id_hash")
            .eq("id", data.user_id)
            .single()
            .execute()
        )

    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=f"Could not retrieve Digital ID: {str(e)}"
        )


    # --------------------------------------------------------
    # 3. Make sure the user has a Digital ID
    # --------------------------------------------------------

    if not result.data or not result.data.get("digital_id_hash"):

        return {
            "verified": False,
            "message": "No Digital ID found for this user."
        }


    stored_hash = result.data["digital_id_hash"]


    # --------------------------------------------------------
    # 4. Compare hashes
    # --------------------------------------------------------

    if current_hash == stored_hash:

        return {
            "verified": True,
            "message": "Tourist identity verified"
        }


    return {
        "verified": False,
        "message": "Invalid identity"
    }