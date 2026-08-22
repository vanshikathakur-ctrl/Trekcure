from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

import uuid
import hashlib
import json
from datetime import date, timedelta
import os
import time

import httpx

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

app = FastAPI(
    title="TrekCure API"
)


# ============================================================
# WEATHER CACHE
# ============================================================

weather_cache = {}

CACHE_DURATION = 300


# ============================================================
# WEATHER CODE HELPER
# ============================================================

def get_weather_condition(weather_code: int | None):

    weather_conditions = {

        0: "Clear sky",

        1: "Mainly clear",
        2: "Partly cloudy",
        3: "Overcast",

        45: "Foggy",
        48: "Foggy",

        51: "Light drizzle",
        53: "Moderate drizzle",
        55: "Heavy drizzle",

        56: "Freezing drizzle",
        57: "Heavy freezing drizzle",

        61: "Light rain",
        63: "Moderate rain",
        65: "Heavy rain",

        66: "Freezing rain",
        67: "Heavy freezing rain",

        71: "Light snowfall",
        73: "Moderate snowfall",
        75: "Heavy snowfall",

        77: "Snow grains",

        80: "Rain showers",
        81: "Moderate rain showers",
        82: "Heavy rain showers",

        85: "Snow showers",
        86: "Heavy snow showers",

        95: "Thunderstorm",

        96: "Thunderstorm with hail",
        99: "Severe thunderstorm with hail",
    }

    return weather_conditions.get(
        weather_code,
        "Unknown"
    )


# ============================================================
# WEATHER API
# ============================================================

@app.get("/weather")
async def get_weather(

    latitude: float = 19.0760,

    longitude: float = 72.8777,

):

    # --------------------------------------------------------
    # CREATE CACHE KEY
    # --------------------------------------------------------

    cache_key = (
        round(latitude, 3),
        round(longitude, 3),
    )


    current_time = time.time()


    # --------------------------------------------------------
    # CHECK CACHE
    # --------------------------------------------------------

    if cache_key in weather_cache:

        cached_data = weather_cache[
            cache_key
        ]

        cache_time = cached_data[
            "timestamp"
        ]

        if (
            current_time - cache_time
            < CACHE_DURATION
        ):

            print(
                "RETURNING CACHED WEATHER DATA"
            )

            return cached_data[
                "data"
            ]


    # --------------------------------------------------------
    # OPEN-METEO API
    # --------------------------------------------------------

    weather_url = (
        "https://api.open-meteo.com/v1/forecast"
    )


    params = {

        "latitude":
            latitude,

        "longitude":
            longitude,

        "current":
            (
                "temperature_2m,"
                "relative_humidity_2m,"
                "apparent_temperature,"
                "precipitation,"
                "rain,"
                "weather_code,"
                "wind_speed_10m"
            ),

        "timezone":
            "auto",
    }


    try:

        timeout = httpx.Timeout(
            15.0,
            connect=10.0,
        )


        async with httpx.AsyncClient(
            timeout=timeout
        ) as client:

            response = await client.get(

                weather_url,

                params=params,

                headers={

                    "User-Agent":
                        "TrekCure/1.0",

                },

            )


        # ----------------------------------------------------
        # RATE LIMIT
        # ----------------------------------------------------

        if response.status_code == 429:

            print(
                "OPEN-METEO RATE LIMIT REACHED"
            )

            # If old cached data exists,
            # return it instead of failing.

            if cache_key in weather_cache:

                print(
                    "RETURNING OLD CACHED WEATHER DATA"
                )

                return weather_cache[
                    cache_key
                ]["data"]


            raise HTTPException(

                status_code=429,

                detail=(
                    "Weather service is temporarily "
                    "busy. Please try again shortly."
                ),

            )


        response.raise_for_status()


        data = response.json()


        current = data.get(
            "current"
        )


        if current is None:

            raise HTTPException(

                status_code=500,

                detail=(
                    "Weather data was not returned "
                    "by the weather provider."
                ),

            )


        # ----------------------------------------------------
        # GET VALUES
        # ----------------------------------------------------

        weather_code = current.get(
            "weather_code"
        )


        condition = get_weather_condition(
            weather_code
        )


        weather_data = {

            "temperature":
                current.get(
                    "temperature_2m"
                ),

            "humidity":
                current.get(
                    "relative_humidity_2m"
                ),

            "feels_like":
                current.get(
                    "apparent_temperature"
                ),

            "precipitation":
                current.get(
                    "precipitation"
                ),

            "rain":
                current.get(
                    "rain"
                ),

            "weather_code":
                weather_code,

            "condition":
                condition,

            "wind_speed":
                current.get(
                    "wind_speed_10m"
                ),

        }


        # ----------------------------------------------------
        # SAVE TO CACHE
        # ----------------------------------------------------

        weather_cache[
            cache_key
        ] = {

            "timestamp":
                current_time,

            "data":
                weather_data,

        }


        print(
            "WEATHER DATA FETCHED SUCCESSFULLY"
        )


        return weather_data


    except HTTPException:

        raise


    except httpx.HTTPStatusError as e:

        print(
            "WEATHER HTTP ERROR:"
        )

        print(
            str(e)
        )


        raise HTTPException(

            status_code=502,

            detail=(
                "Weather provider returned an error."
            ),

        )


    except httpx.RequestError as e:

        print(
            "WEATHER CONNECTION ERROR:"
        )

        print(
            str(e)
        )


        # Return old cached data if available

        if cache_key in weather_cache:

            return weather_cache[
                cache_key
            ]["data"]


        raise HTTPException(

            status_code=503,

            detail=(
                "Unable to connect to the weather service."
            ),

        )


    except Exception as e:

        print(
            "WEATHER SERVER ERROR:"
        )

        print(
            str(e)
        )


        raise HTTPException(

            status_code=500,

            detail=(
                "Failed to process weather data."
            ),

        )


# ============================================================
# DIGITAL ID - CREATE
# ============================================================

class Tourist(BaseModel):

    user_id: str

    name: str

    age: int


@app.post("/create-digital-id")
def create_digital_id(
    tourist: Tourist
):

    # --------------------------------------------------------
    # GENERATE UNIQUE TOURIST ID
    # --------------------------------------------------------

    tourist_id = (
        "TC-" +
        str(uuid.uuid4())[:8]
    )


    # --------------------------------------------------------
    # CREATE DIGITAL ID CREDENTIAL
    # --------------------------------------------------------

    credential = {

        "tourist_id":
            tourist_id,

        "name":
            tourist.name,

        "age":
            tourist.age,

        "credential_type":
            "TrekCure Tourist ID",

        "issued_by":
            "TrekCure",

        "issued_date":
            str(
                date.today()
            ),

        "valid_until":
            str(
                date.today()
                +
                timedelta(
                    days=30
                )
            ),

    }


    # --------------------------------------------------------
    # GENERATE SHA-256 HASH
    # --------------------------------------------------------

    credential_data = json.dumps(

        credential,

        sort_keys=True,

    )


    credential_hash = hashlib.sha256(

        credential_data.encode()

    ).hexdigest()


    # --------------------------------------------------------
    # STORE HASH IN SUPABASE
    # --------------------------------------------------------

    try:

        result = (

            supabase

            .table(
                "profiles"
            )

            .update({

                "digital_id_hash":
                    credential_hash,

            })

            .eq(

                "id",

                tourist.user_id,

            )

            .execute()

        )


    except Exception as e:

        raise HTTPException(

            status_code=500,

            detail=(

                "Could not save Digital ID "
                f"to Supabase: {str(e)}"

            ),

        )


    # --------------------------------------------------------
    # CHECK PROFILE
    # --------------------------------------------------------

    if not result.data:

        raise HTTPException(

            status_code=404,

            detail=(

                "Profile not found or update "
                "was blocked."

            ),

        )


    # --------------------------------------------------------
    # RETURN DIGITAL ID
    # --------------------------------------------------------

    return {

        "tourist_id":
            tourist_id,

        "credential":
            credential,

        "hash":
            credential_hash,

    }


# ============================================================
# DIGITAL ID - VERIFY
# ============================================================

class VerificationRequest(BaseModel):

    user_id: str

    credential: dict


@app.post("/verify-digital-id")
def verify_digital_id(
    data: VerificationRequest
):

    # --------------------------------------------------------
    # GENERATE HASH FROM PROVIDED CREDENTIAL
    # --------------------------------------------------------

    credential_data = json.dumps(

        data.credential,

        sort_keys=True,

    )


    current_hash = hashlib.sha256(

        credential_data.encode()

    ).hexdigest()


    # --------------------------------------------------------
    # GET STORED HASH
    # --------------------------------------------------------

    try:

        result = (

            supabase

            .table(
                "profiles"
            )

            .select(
                "digital_id_hash"
            )

            .eq(

                "id",

                data.user_id

            )

            .single()

            .execute()

        )


    except Exception as e:

        raise HTTPException(

            status_code=500,

            detail=(

                "Could not retrieve "
                f"Digital ID: {str(e)}"

            ),

        )


    # --------------------------------------------------------
    # CHECK DIGITAL ID
    # --------------------------------------------------------

    if (

        not result.data

        or

        not result.data.get(
            "digital_id_hash"
        )

    ):

        return {

            "verified":
                False,

            "message":
                "No Digital ID found for this user.",

        }


    stored_hash = result.data[
        "digital_id_hash"
    ]


    # --------------------------------------------------------
    # COMPARE HASHES
    # --------------------------------------------------------

    if current_hash == stored_hash:

        return {

            "verified":
                True,

            "message":
                "Tourist identity verified",

        }


    return {

        "verified":
            False,

        "message":
            "Invalid identity",

    }