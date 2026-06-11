// Tirana – Gjimnazi Andon Zako Çajupi
const LAT = 41.3372;
const LON = 19.8328;

export async function GET() {
  try {
    const [weatherRes, aqRes] = await Promise.all([
      fetch(
        `https://api.open-meteo.com/v1/forecast` +
          `?latitude=${LAT}&longitude=${LON}` +
          `&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code` +
          `&hourly=precipitation_probability,precipitation,rain,wind_speed_10m` +
          `&daily=precipitation_sum,precipitation_probability_max,wind_speed_10m_max,weather_code` +
          `&timezone=Europe%2FTirane` +
          `&forecast_days=3`
      ),
      fetch(
        `https://air-quality-api.open-meteo.com/v1/air-quality` +
          `?latitude=${LAT}&longitude=${LON}` +
          `&current=pm2_5,pm10,european_aqi` +
          `&timezone=Europe%2FTirane`
      ),
    ]);

    if (!weatherRes.ok || !aqRes.ok) {
      throw new Error("Upstream fetch failed");
    }

    const weather = await weatherRes.json();
    const aq = await aqRes.json();

    const cur = weather.current;
    const daily = weather.daily;

    // Next 24 h peak rain probability
    const next24hProbs: number[] = weather.hourly.precipitation_probability.slice(0, 24);
    const maxRainProb = Math.max(...next24hProbs);
    const totalRainNext24h: number = (weather.hourly.precipitation as number[])
      .slice(0, 24)
      .reduce((a: number, b: number) => a + b, 0);

    // Find the first hour index where rain is expected
    const rainHourIndex: number = (weather.hourly.precipitation as number[]).findIndex(
      (v: number) => v > 0.1
    );

    // Derive disaster risk
    const floodRisk = deriveFloodRisk(
      cur.precipitation,
      totalRainNext24h,
      maxRainProb
    );
    const fireRisk = deriveFireRisk(
      cur.temperature_2m,
      cur.relative_humidity_2m,
      cur.wind_speed_10m
    );

    const aqi = aq.current.european_aqi ?? 0;

    const response = {
      location: "Gjimnazi Andon Zako Çajupi, Tiranë",
      updated: cur.time,
      current: {
        temperature: cur.temperature_2m,
        feelsLike: cur.apparent_temperature,
        humidity: cur.relative_humidity_2m,
        rain: cur.rain,
        precipitation: cur.precipitation,
        windSpeed: cur.wind_speed_10m,
        windGusts: cur.wind_gusts_10m,
        windDirection: cur.wind_direction_10m,
        weatherCode: cur.weather_code,
      },
      rain: {
        probabilityNext24h: maxRainProb,
        totalMmNext24h: parseFloat(totalRainNext24h.toFixed(1)),
        nextRainInHours: rainHourIndex === -1 ? null : rainHourIndex,
        dailyForecast: (daily.time as string[]).map((date: string, i: number) => ({
          date,
          precipitationMm: daily.precipitation_sum[i],
          probabilityPct: daily.precipitation_probability_max[i],
          maxWindKph: daily.wind_speed_10m_max[i],
        })),
      },
      airQuality: {
        europeanAqi: aqi,
        pm2_5: aq.current.pm2_5,
        pm10: aq.current.pm10,
        label: aqiLabel(aqi),
      },
      disasters: {
        flood: floodRisk,
        fire: fireRisk,
      },
    };

    return Response.json(response, {
      headers: {
        "Cache-Control": "s-maxage=600, stale-while-revalidate=300",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (err) {
    console.error(err);
    return Response.json({ error: "Dështoi marrja e të dhënave" }, { status: 500 });
  }
}

function aqiLabel(aqi: number): string {
  if (aqi <= 20) return "Shkëlqyeshëm";
  if (aqi <= 40) return "Pranueshëm";
  if (aqi <= 60) return "Mesatare";
  if (aqi <= 80) return "Dobët";
  if (aqi <= 100) return "Shumë dobët";
  return "Jashtëzakonisht dobët";
}

function deriveFloodRisk(
  currentPrecip: number,
  totalNext24h: number,
  maxProb: number
): { level: string; description: string } {
  const score =
    (currentPrecip > 2 ? 2 : currentPrecip) +
    (totalNext24h > 20 ? 3 : totalNext24h > 10 ? 2 : totalNext24h > 3 ? 1 : 0) +
    (maxProb > 70 ? 2 : maxProb > 40 ? 1 : 0);

  if (score >= 5)
    return { level: "I lartë", description: "Priten reshje të dendura shiu. Mundësi për përmbytje lokale." };
  if (score >= 3)
    return { level: "Mesatar", description: "Reshje të shtuara shiu. Monitoroni zonat e kullimit." };
  if (score >= 1)
    return { level: "I ulët", description: "Priten pak reshje shiu. Rrezik i ulët përmbytjeje." };
  return { level: "Minimal", description: "Kushte të thata. Nuk ka rrezik përmbytjeje." };
}

function deriveFireRisk(
  temp: number,
  humidity: number,
  windSpeed: number
): { level: string; description: string } {
  const score =
    (temp > 35 ? 3 : temp > 28 ? 2 : temp > 20 ? 1 : 0) +
    (humidity < 20 ? 3 : humidity < 35 ? 2 : humidity < 50 ? 1 : 0) +
    (windSpeed > 40 ? 2 : windSpeed > 20 ? 1 : 0);

  if (score >= 6)
    return { level: "Ekstrem", description: "Rrezik ekstrem zjarri. Shmangni flakët e hapura." };
  if (score >= 4)
    return { level: "I lartë", description: "Rrezik i lartë zjarri. Kushte të thata dhe me erë." };
  if (score >= 2)
    return { level: "Mesatar", description: "Rrezik mesatar zjarri. Të tregohet kujdes jashtë." };
  return { level: "I ulët", description: "Rrezik i ulët zjarri. Kushtet nuk favorizojnë zjarret." };
}
