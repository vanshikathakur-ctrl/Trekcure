from fastapi import FastAPI
import httpx

app = FastAPI()


@app.get("/weather")
async def get_weather(latitude: float, longitude: float):

    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={latitude}"
        f"&longitude={longitude}"
        "&current=temperature_2m,relative_humidity_2m,"
        "apparent_temperature,weather_code,wind_speed_10m"
        "&hourly=temperature_2m,weather_code"
        "&forecast_days=2"
        "&timezone=auto"
    )

    async with httpx.AsyncClient() as client:
        response = await client.get(url)

    response.raise_for_status()

    data = response.json()

    current = data["current"]
    hourly = data["hourly"]

    temperature = current["temperature_2m"]
    humidity = current["relative_humidity_2m"]
    feels_like = current["apparent_temperature"]
    weather_code = current["weather_code"]
    wind_speed = current["wind_speed_10m"]

    # ------------------------------------------------------------
    # SAFETY / RISK CALCULATION
    # ------------------------------------------------------------

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

    # ------------------------------------------------------------
    # HOURLY FORECAST
    # ------------------------------------------------------------

    forecast = []

    times = hourly["time"]
    temperatures = hourly["temperature_2m"]
    weather_codes = hourly["weather_code"]

    # Current local time at the tourist's location
    current_time = current["time"]

    # Find the current hour in the hourly forecast
    current_index = 0

    for i, time in enumerate(times):
        if time >= current_time:
            current_index = i
            break

    # Return current hour + next 4 hours
    for i in range(
        current_index,
        min(current_index + 5, len(times))
    ):
        forecast.append({
            "time": times[i],
            "temperature": temperatures[i],
            "weather_code": weather_codes[i],
        })

    # ------------------------------------------------------------
    # RESPONSE
    # ------------------------------------------------------------

    return {
        "temperature": temperature,
        "humidity": humidity,
        "feels_like": feels_like,
        "weather_code": weather_code,
        "wind_speed": wind_speed,
        "risk_level": risk_level,
        "hazard": hazard,
        "message": message,
        "forecast": forecast,
    }