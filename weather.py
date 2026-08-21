from fastapi import FastAPI
import httpx
app = FastAPI()


@app.get("/weather")
async def get_weather(latitude: float, longitude: float):

    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={latitude}&longitude={longitude}"
        "&current=temperature_2m,weather_code,wind_speed_10m"
    )

    async with httpx.AsyncClient() as client:
        response = await client.get(url)

    data = response.json()

    current = data["current"]

    temperature = current["temperature_2m"]
    weather_code = current["weather_code"]
    wind_speed = current["wind_speed_10m"]

    # Safety / risk calculation
    if temperature >= 40 or temperature <= 0 or wind_speed >= 50:
        risk_level = "HIGH"
        hazard = True
        message = "Weather conditions may be dangerous."

    elif temperature >= 35 or temperature <= 5 or wind_speed >= 30:
        risk_level = "MODERATE"
        hazard = True
        message = "Weather conditions require caution."

    else:
        risk_level = "SAFE"
        hazard = False
        message = "Weather conditions are safe."

    return {
        "temperature": temperature,
        "weather_code": weather_code,
        "wind_speed": wind_speed,
        "risk_level": risk_level,
        "hazard": hazard,
        "message": message
    }