import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "jsr:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

// ================================================================
// SUPABASE
// ================================================================

const supabaseUrl = Deno.env.get("SUPABASE_URL");

const supabaseServiceRoleKey = Deno.env.get(
  "SUPABASE_SERVICE_ROLE_KEY",
);

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error(
    "Missing Supabase environment variables",
  );
}

const supabase = createClient(
  supabaseUrl,
  supabaseServiceRoleKey,
);

// ================================================================
// GET FIREBASE ACCESS TOKEN
// ================================================================

async function getFirebaseAccessToken() {
  const projectId = Deno.env.get(
    "FIREBASE_PROJECT_ID",
  );

  const clientEmail = Deno.env.get(
    "FIREBASE_CLIENT_EMAIL",
  );

  const privateKey = Deno.env
    .get("FIREBASE_PRIVATE_KEY")
    ?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      "Missing Firebase secrets. Check FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY.",
    );
  }

  const now = Math.floor(
    Date.now() / 1000,
  );

  const key = await importPKCS8(
    privateKey,
    "RS256",
  );

  const jwt = await new SignJWT({
    scope:
      "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({
      alg: "RS256",
      typ: "JWT",
    })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience(
      "https://oauth2.googleapis.com/token",
    )
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "Content-Type":
            "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type:
            "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    },
  );

  const data = await response.json();

  if (!response.ok) {
    console.error(
      "Google OAuth error:",
      data,
    );

    throw new Error(
      `Failed to get Firebase access token: ${JSON.stringify(data)}`,
    );
  }

  return {
    accessToken: data.access_token as string,
    projectId,
  };
}

// ================================================================
// SEND OTP THROUGH FCM
// ================================================================

async function sendFcmOtp(
  fcmToken: string,
  accessToken: string,
  projectId: string,
  otp: string,
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",

      headers: {
        Authorization:
            `Bearer ${accessToken}`,
        "Content-Type":
            "application/json",
      },

      body: JSON.stringify({
        message: {
          token: fcmToken,

          notification: {
            title:
                "TrekCure Password Reset",
            body:
                `Your password reset OTP is ${otp}`,
          },

          data: {
            type:
                "password_reset",
            otp:
                otp,
          },

          android: {
            priority:
                "high",
          },
        },
      }),
    },
  );

  const data = await response.json();

  if (!response.ok) {
    console.error(
      "FCM OTP send error:",
      data,
    );

    throw new Error(
      `Failed to send FCM notification: ${JSON.stringify(data)}`,
    );
  }

  return data;
}

// ================================================================
// EDGE FUNCTION
// ================================================================

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return Response.json(
        {
          success: false,
          error:
              "Method not allowed",
        },
        {
          status: 405,
        },
      );
    }

    const body =
        await req.json();

    // Supports the PostgreSQL trigger payload:
    //
    // {
    //   "record": {
    //     "email": "...",
    //     "otp_code": "123456"
    //   }
    // }

    const record =
        body.record ?? body;

    const email =
        record.email;

    const otp =
        record.otp_code;

    if (!email || !otp) {
      return Response.json(
        {
          success: false,
          error:
              "Email and OTP are required.",
        },
        {
          status: 400,
        },
      );
    }

    console.log(
      `Processing password reset OTP for: ${email}`,
    );

    // ==========================================================
    // FIND USER BY EMAIL
    // ==========================================================

    const {
      data: usersData,
      error: usersError,
    } =
        await supabase.auth.admin.listUsers();

    if (usersError) {
      throw new Error(
        `User lookup failed: ${usersError.message}`,
      );
    }

    const user =
        usersData.users.find(
      (currentUser) =>
          currentUser.email
              ?.toLowerCase() ===
          email.toLowerCase(),
    );

    if (!user) {
      return Response.json(
        {
          success: false,
          error:
              "User not found.",
        },
        {
          status: 404,
        },
      );
    }

    console.log(
      `User found: ${user.id}`,
    );

    // ==========================================================
    // GET USER'S FCM TOKEN
    // ==========================================================

    const {
      data: profile,
      error: profileError,
    } =
        await supabase
            .from("profiles")
            .select(
              "id, fcm_token",
            )
            .eq(
              "id",
              user.id,
            )
            .single();

    if (profileError) {
      throw new Error(
        `Profile lookup failed: ${profileError.message}`,
      );
    }

    if (
        !profile ||
        !profile.fcm_token ||
        profile.fcm_token.length === 0
    ) {
      return Response.json(
        {
          success: false,
          error:
              "No FCM token found for this user.",
        },
        {
          status: 400,
        },
      );
    }

    console.log(
      "FCM token found. Sending OTP...",
    );

    // ==========================================================
    // GET FIREBASE ACCESS TOKEN
    // ==========================================================

    const {
      accessToken,
      projectId,
    } =
        await getFirebaseAccessToken();

    // ==========================================================
    // SEND OTP
    // ==========================================================

    const result =
        await sendFcmOtp(
      profile.fcm_token,
      accessToken,
      projectId,
      otp,
    );

    console.log(
      `OTP successfully sent to ${email}`,
    );

    return Response.json(
      {
        success: true,
        message:
            "OTP sent successfully.",
        result,
      },
      {
        status: 200,
      },
    );
  } catch (error) {
    console.error(
      "SEND FCM OTP ERROR:",
      error,
    );

    return Response.json(
      {
        success: false,
        error:
            String(error),
      },
      {
        status: 500,
      },
    );
  }
});